"""Authentication and the current-identity endpoint."""

from __future__ import annotations

from fastapi import APIRouter, HTTPException, status
from sqlalchemy import func, select

from app.api.deps import DbSession, User
from app.core.errors import ValidationError
from app.core.security import (
    create_access_token,
    hash_password,
    permissions_for_role,
    revoke_sessions,
    verify_password,
)
from app.models.auth import AuthUser, Notification
from app.models.employee import Employee
from app.schemas.auth import (
    LoginRequest,
    MeResponse,
    PasswordChangeRequest,
    TokenResponse,
)
from app.schemas.common import MessageResponse

router = APIRouter(prefix="/auth", tags=["Authentication"])


@router.post(
    "/login",
    response_model=TokenResponse,
    summary="Authenticate credentials, return a JWT token and role",
)
def login(payload: LoginRequest, db: DbSession) -> TokenResponse:
    user = db.execute(
        select(AuthUser).where(func.lower(AuthUser.email) == payload.email.lower())
    ).scalars().first()

    # Constant-ish response: never reveal whether the email exists.
    if not user or not verify_password(payload.password, user.hashed_password):
        raise HTTPException(
            status_code=status.HTTP_401_UNAUTHORIZED,
            detail="Incorrect email or password.",
        )
    if not user.is_active:
        raise HTTPException(
            status_code=status.HTTP_403_FORBIDDEN,
            detail="This account has been deactivated.",
        )

    employee = db.execute(
        select(Employee).where(Employee.user_id == user.id)
    ).scalars().first()

    token, expires_in = create_access_token(
        user_id=user.id,
        email=user.email,
        role=user.role.value,
        employee_id=employee.id if employee else None,
        token_version=user.token_version,
    )

    return TokenResponse(
        access_token=token,
        expires_in=expires_in,
        role=user.role,
        user_id=str(user.id),
        employee_id=str(employee.id) if employee else None,
        employee_name=employee.name if employee else None,
        permissions=permissions_for_role(user.role.value),
    )


@router.get(
    "/me",
    response_model=MeResponse,
    summary="Current profile, linked employee ID and permissions",
)
def read_me(db: DbSession, user: User) -> MeResponse:
    db_user = db.get(AuthUser, user.user_id)
    if not db_user:
        raise HTTPException(
            status_code=status.HTTP_401_UNAUTHORIZED, detail="User no longer exists."
        )

    employee = db.execute(
        select(Employee).where(Employee.user_id == db_user.id)
    ).scalars().first()

    unread = db.execute(
        select(func.count(Notification.id)).where(
            Notification.recipient_user_id == db_user.id,
            Notification.is_read.is_(False),
        )
    ).scalar_one()

    return MeResponse(
        user_id=str(db_user.id),
        email=db_user.email,
        role=db_user.role,
        is_active=db_user.is_active,
        permissions=permissions_for_role(db_user.role.value),
        employee_id=str(employee.id) if employee else None,
        employee_name=employee.name if employee else None,
        badge_id=employee.badge_id if employee else None,
        department=(
            employee.department.name if employee and employee.department else None
        ),
        job_position=(
            employee.job_position.name if employee and employee.job_position else None
        ),
        manager_name=employee.manager.name if employee and employee.manager else None,
        unread_notifications=unread,
    )


@router.post(
    "/change-password",
    response_model=MessageResponse,
    summary="Change your own password",
)
def change_password(
    payload: PasswordChangeRequest, db: DbSession, user: User
) -> MessageResponse:
    db_user = db.get(AuthUser, user.user_id)
    if not db_user or not verify_password(
        payload.current_password, db_user.hashed_password
    ):
        raise HTTPException(
            status_code=status.HTTP_400_BAD_REQUEST,
            detail="Current password is incorrect.",
        )
    if payload.current_password == payload.new_password:
        raise ValidationError("The new password must differ from the current one.")

    db_user.hashed_password = hash_password(payload.new_password)
    db.flush()
    # Changing a password logs out every other session, including this one.
    revoke_sessions(db, db_user.id)
    db.commit()
    return MessageResponse(
        detail="Password updated. All sessions were signed out; please sign in again."
    )
