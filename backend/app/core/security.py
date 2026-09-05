"""Authentication primitives + the 5-tier RBAC permission matrix.

Design notes
------------
* Passwords are hashed with bcrypt directly (no passlib shim). bcrypt silently
  truncates at 72 bytes, so we pre-hash with SHA-256 to keep long passphrases
  fully significant.
* `require_permission` is preferred over `require_roles`: permissions are the
  stable contract, roles are just bundles of them.
"""

from __future__ import annotations

import hashlib
import uuid
from datetime import datetime, timedelta, timezone
from typing import Any, Dict, Iterable, Sequence

import bcrypt
import jwt
from fastapi import Depends, HTTPException, Security, status
from fastapi.security import HTTPAuthorizationCredentials, HTTPBearer
from sqlalchemy import select
from sqlalchemy.orm import Session

from app.core.config import settings
from app.core.database import get_db
from app.models.enums import UserRole

# ---------------------------------------------------------------------------
# PERMISSION MATRIX (BACKEND_PRODUCTION_ARCHITECTURE.md section 5)
# ---------------------------------------------------------------------------
ROLE_PERMISSIONS: Dict[str, list[str]] = {
    UserRole.EMPLOYEE.value: [
        "read:self",
        "create:attendance_self",
        "create:timeoff_self",
        # AI Copilot: may ask and may escalate, but only sees OWN tickets
        "ask:copilot",
        "create:escalation_self",
        "read:escalation_self",
    ],
    UserRole.HR_MANAGER.value: [
        "read:self",
        "read:all_hr",
        "write:employees",
        "write:attendance",
        "write:contracts",
        "write:schedules",
        "approve:timeoff",
        "create:attendance_self",
        "create:timeoff_self",
        # Owns LEAVE_POLICY / ATTENDANCE / CONTRACT escalation categories
        "ask:copilot",
        "create:escalation_self",
        "read:escalation_self",
        "read:escalation_queue",
        "assign:escalation",
        "answer:escalation",
    ],
    UserRole.HR_PAYROLL_USER.value: [
        "read:self",
        "read:all_hr",
        "write:employees",
        "write:attendance",
        "write:contracts",
        "write:schedules",
        "approve:timeoff",
        "crud:payruns",
        "crud:payslips",
        "read:structures",
        "read:private_employee_data",
        "create:attendance_self",
        "create:timeoff_self",
        "ask:copilot",
        "create:escalation_self",
        "read:escalation_self",
        "read:escalation_queue",
    ],
    UserRole.HR_PAYROLL_MANAGER.value: [
        "read:self",
        "read:all_hr",
        "write:employees",
        "write:attendance",
        "write:contracts",
        "write:schedules",
        "approve:timeoff",
        "crud:payruns",
        "crud:payslips",
        "read:structures",
        "read:private_employee_data",
        "crud:structures",
        "crud:rules",
        "create:attendance_self",
        "create:timeoff_self",
        # Owns PAYROLL_SALARY / TAX_STATUTORY categories + may grow the KB
        "ask:copilot",
        "create:escalation_self",
        "read:escalation_self",
        "read:escalation_queue",
        "assign:escalation",
        "answer:escalation",
        "publish:knowledge_base",
    ],
    UserRole.ADMIN.value: [
        "all_access",
        "manage:users",
        "system:admin",
        # Catch-all responder for OTHER / IT_ACCESS + routing configuration
        "ask:copilot",
        "read:escalation_queue",
        "assign:escalation",
        "answer:escalation",
        "publish:knowledge_base",
        "manage:escalation_routing",
    ],
}

# ESCALATION VISIBILITY RULE (enforced in the repository layer, never the client):
#   EMPLOYEE     -> WHERE employee_id = :self_employee_id
#   HR_* / ADMIN -> full queue, plus INTERNAL thread events
ESCALATION_RESPONDER_ROLES = {
    UserRole.HR_MANAGER.value,
    UserRole.HR_PAYROLL_MANAGER.value,
    UserRole.ADMIN.value,
}

# Roles allowed to see employees' private banking / tax identifiers
PRIVATE_DATA_ROLES = {
    UserRole.HR_PAYROLL_USER.value,
    UserRole.HR_PAYROLL_MANAGER.value,
    UserRole.ADMIN.value,
}

# Roles that see the whole organisation rather than only their own record
HR_SCOPE_ROLES = {
    UserRole.HR_MANAGER.value,
    UserRole.HR_PAYROLL_USER.value,
    UserRole.HR_PAYROLL_MANAGER.value,
    UserRole.ADMIN.value,
}

security_scheme = HTTPBearer(auto_error=True)


# ---------------------------------------------------------------------------
# PASSWORDS
# ---------------------------------------------------------------------------
def _prehash(password: str) -> bytes:
    """SHA-256 first so bcrypt's 72-byte ceiling never truncates a passphrase."""
    return hashlib.sha256(password.encode("utf-8")).digest()


def hash_password(password: str) -> str:
    return bcrypt.hashpw(_prehash(password), bcrypt.gensalt(rounds=12)).decode("utf-8")


def verify_password(password: str, hashed: str) -> bool:
    try:
        return bcrypt.checkpw(_prehash(password), hashed.encode("utf-8"))
    except (ValueError, TypeError):
        return False


# ---------------------------------------------------------------------------
# TOKENS
# ---------------------------------------------------------------------------
def create_access_token(
    *,
    user_id: uuid.UUID | str,
    email: str,
    role: str,
    employee_id: uuid.UUID | str | None = None,
    token_version: int = 1,
    expires_minutes: int | None = None,
) -> tuple[str, int]:
    """Returns (token, expires_in_seconds).

    `token_version` is the revocation handle: it is compared against the database
    on every request, so bumping the column logs the user out everywhere.
    """
    expires_minutes = expires_minutes or settings.access_token_expire_minutes
    now = datetime.now(timezone.utc)
    expire = now + timedelta(minutes=expires_minutes)
    payload = {
        "sub": str(user_id),
        "email": email,
        "role": role,
        "employee_id": str(employee_id) if employee_id else None,
        "permissions": permissions_for_role(role),
        "tv": int(token_version),
        "iat": int(now.timestamp()),
        "exp": int(expire.timestamp()),
        "iss": settings.app_name,
    }
    token = jwt.encode(payload, settings.jwt_secret, algorithm=settings.jwt_algorithm)
    return token, expires_minutes * 60


def revoke_sessions(db: Session, user_id: uuid.UUID | str) -> None:
    """Invalidate every token already issued to a user.

    Call this whenever authority or credentials change: deactivation, role change,
    password change. Without it a JWT stays valid until `exp`, so a demoted or
    disabled account keeps its old privileges for hours.
    """
    from sqlalchemy import text as _text

    db.execute(
        _text(
            "UPDATE auth_users "
            "SET token_version = token_version + 1, credentials_changed_at = NOW() "
            "WHERE id = CAST(:uid AS uuid)"
        ),
        {"uid": str(user_id)},
    )


def decode_token(token: str) -> Dict[str, Any]:
    try:
        return jwt.decode(
            token,
            settings.jwt_secret,
            algorithms=[settings.jwt_algorithm],
            issuer=settings.app_name,
            options={"require": ["exp", "sub"]},
        )
    except jwt.ExpiredSignatureError:
        raise HTTPException(
            status_code=status.HTTP_401_UNAUTHORIZED, detail="Token has expired."
        )
    except jwt.PyJWTError:
        raise HTTPException(
            status_code=status.HTTP_401_UNAUTHORIZED, detail="Invalid token."
        )


# ---------------------------------------------------------------------------
# PERMISSIONS
# ---------------------------------------------------------------------------
def permissions_for_role(role: str) -> list[str]:
    return list(ROLE_PERMISSIONS.get(role, []))


def role_has_permission(role: str, permission: str) -> bool:
    perms = ROLE_PERMISSIONS.get(role, [])
    return "all_access" in perms or permission in perms


class CurrentUser:
    """Immutable request-scoped identity. Everything downstream reads this."""

    __slots__ = ("user_id", "email", "role", "employee_id", "permissions")

    def __init__(self, payload: Dict[str, Any]) -> None:
        self.user_id: uuid.UUID = uuid.UUID(str(payload["sub"]))
        self.email: str = payload.get("email", "")
        self.role: str = payload.get("role", UserRole.EMPLOYEE.value)
        emp = payload.get("employee_id")
        self.employee_id: uuid.UUID | None = uuid.UUID(str(emp)) if emp else None
        self.permissions: list[str] = payload.get(
            "permissions"
        ) or permissions_for_role(self.role)

    # -- capability helpers --------------------------------------------------
    @property
    def is_admin(self) -> bool:
        return self.role == UserRole.ADMIN.value

    @property
    def has_hr_scope(self) -> bool:
        return self.role in HR_SCOPE_ROLES

    @property
    def can_see_private_data(self) -> bool:
        return self.role in PRIVATE_DATA_ROLES

    @property
    def is_escalation_responder(self) -> bool:
        return self.role in ESCALATION_RESPONDER_ROLES

    def has_permission(self, permission: str) -> bool:
        return "all_access" in self.permissions or permission in self.permissions

    def require(self, permission: str) -> None:
        if not self.has_permission(permission):
            raise HTTPException(
                status_code=status.HTTP_403_FORBIDDEN,
                detail=f"Access denied: missing permission '{permission}'.",
            )

    def assert_can_read_employee(self, employee_id: uuid.UUID | str | None) -> None:
        """Row scoping: an EMPLOYEE may only ever read their own record."""
        if self.has_hr_scope:
            return
        if employee_id is None or str(employee_id) != str(self.employee_id):
            raise HTTPException(
                status_code=status.HTTP_403_FORBIDDEN,
                detail="Access denied: you may only view your own records.",
            )

    def __repr__(self) -> str:  # pragma: no cover
        return f"<CurrentUser {self.email} role={self.role}>"


# ---------------------------------------------------------------------------
# FASTAPI DEPENDENCIES
# ---------------------------------------------------------------------------
def get_current_user(
    credentials: HTTPAuthorizationCredentials = Security(security_scheme),
    db: Session = Depends(get_db),
) -> CurrentUser:
    """Decode the token AND revalidate it against the database.

    A JWT is self-contained, which is exactly why it cannot be the only source of
    truth for authorisation. Verified by probe before this check existed: a
    deactivated user kept full API access, and an `HR_PAYROLL_MANAGER` demoted to
    `EMPLOYEE` kept payroll access, both for the remaining token lifetime (8h by
    default).

    Four things are checked on every request. The cost is one primary-key lookup.

    1. the account still exists
    2. it is still active
    3. the role in the token still matches the role in the database
    4. the token was issued after the last credential/authority change
    """
    payload = decode_token(credentials.credentials)
    user = CurrentUser(payload)

    from app.models.auth import AuthUser  # local import keeps `core` import-light

    row = db.execute(
        select(
            AuthUser.id, AuthUser.role, AuthUser.is_active, AuthUser.token_version
        ).where(AuthUser.id == user.user_id)
    ).first()

    if row is None:
        raise HTTPException(
            status_code=status.HTTP_401_UNAUTHORIZED,
            detail="This account no longer exists.",
        )
    if not row.is_active:
        raise HTTPException(
            status_code=status.HTTP_401_UNAUTHORIZED,
            detail="This account has been deactivated.",
        )

    current_role = row.role.value if hasattr(row.role, "value") else str(row.role)
    if current_role != user.role:
        raise HTTPException(
            status_code=status.HTTP_401_UNAUTHORIZED,
            detail="Your access level changed. Please sign in again.",
        )

    if int(payload.get("tv", 0)) != int(row.token_version):
        raise HTTPException(
            status_code=status.HTTP_401_UNAUTHORIZED,
            detail="This session was revoked. Please sign in again.",
        )

    return user


def require_roles(allowed_roles: Sequence[str]):
    """ADMIN is implicitly allowed everywhere."""
    allowed = {r.value if isinstance(r, UserRole) else str(r) for r in allowed_roles}

    def role_checker(user: CurrentUser = Depends(get_current_user)) -> CurrentUser:
        if user.role not in allowed and not user.is_admin:
            raise HTTPException(
                status_code=status.HTTP_403_FORBIDDEN,
                detail=f"Access denied: requires one of {sorted(allowed)}",
            )
        return user

    return role_checker


def require_permission(*permissions: str, mode: str = "any"):
    """Guard an endpoint by capability instead of by role name."""

    def permission_checker(user: CurrentUser = Depends(get_current_user)) -> CurrentUser:
        checks: Iterable[bool] = (user.has_permission(p) for p in permissions)
        ok = any(checks) if mode == "any" else all(
            user.has_permission(p) for p in permissions
        )
        if not ok:
            raise HTTPException(
                status_code=status.HTTP_403_FORBIDDEN,
                detail=f"Access denied: requires permission(s) {list(permissions)}",
            )
        return user

    return permission_checker


# Convenience aliases matching the endpoint matrix in section 6
require_admin = require_roles([UserRole.ADMIN])
require_hr = require_roles(
    [
        UserRole.HR_MANAGER,
        UserRole.HR_PAYROLL_USER,
        UserRole.HR_PAYROLL_MANAGER,
        UserRole.ADMIN,
    ]
)
require_payroll = require_roles(
    [UserRole.HR_PAYROLL_USER, UserRole.HR_PAYROLL_MANAGER, UserRole.ADMIN]
)
require_payroll_manager = require_roles([UserRole.HR_PAYROLL_MANAGER, UserRole.ADMIN])
require_escalation_responder = require_roles(
    [UserRole.HR_MANAGER, UserRole.HR_PAYROLL_MANAGER, UserRole.ADMIN]
)
