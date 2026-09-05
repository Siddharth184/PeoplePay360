"""User account administration (ADMIN only) and the notification feed."""

from __future__ import annotations

import uuid
from typing import List, Optional

from fastapi import APIRouter, Depends, Query
from sqlalchemy import func, select, update

from app.api.deps import DbSession, PageParams, User
from app.core.errors import ConflictError, NotFoundError
from app.core.security import CurrentUser, hash_password, require_admin, revoke_sessions
from app.models.auth import AuthUser, Notification
from app.models.employee import Employee
from app.models.enums import UserRole
from app.schemas.auth import (
    NotificationOut,
    UserCreate,
    UserUpdate,
    UserWithEmployeeOut,
)
from app.schemas.common import MessageResponse

router = APIRouter(tags=["Users & Notifications"])


# ===========================================================================
# USERS (ADMIN)
# ===========================================================================
@router.get(
    "/users",
    response_model=List[UserWithEmployeeOut],
    summary="List all system users with role filters",
)
def list_users(
    db: DbSession,
    page: PageParams,
    role: Optional[UserRole] = Query(default=None),
    is_active: Optional[bool] = Query(default=None),
    search: Optional[str] = Query(default=None, max_length=120),
    _: CurrentUser = Depends(require_admin),
) -> List[UserWithEmployeeOut]:
    stmt = (
        select(AuthUser, Employee)
        .outerjoin(Employee, Employee.user_id == AuthUser.id)
        .order_by(AuthUser.created_at.desc())
    )
    if role is not None:
        stmt = stmt.where(AuthUser.role == role)
    if is_active is not None:
        stmt = stmt.where(AuthUser.is_active.is_(is_active))
    if search:
        stmt = stmt.where(AuthUser.email.ilike(f"%{search}%"))

    rows = db.execute(stmt.limit(page.limit).offset(page.offset)).all()
    return [
        UserWithEmployeeOut(
            id=user.id,
            email=user.email,
            role=user.role,
            is_active=user.is_active,
            created_at=user.created_at,
            employee_id=employee.id if employee else None,
            employee_name=employee.name if employee else None,
            badge_id=employee.badge_id if employee else None,
        )
        for user, employee in rows
    ]


@router.post(
    "/users",
    response_model=UserWithEmployeeOut,
    status_code=201,
    summary="Create a user account and optionally link it to an employee",
)
def create_user(
    payload: UserCreate, db: DbSession, _: CurrentUser = Depends(require_admin)
) -> UserWithEmployeeOut:
    existing = db.execute(
        select(AuthUser).where(func.lower(AuthUser.email) == payload.email.lower())
    ).scalars().first()
    if existing:
        raise ConflictError(f"A user with email {payload.email} already exists.")

    employee: Employee | None = None
    if payload.employee_id:
        employee = db.get(Employee, payload.employee_id)
        if not employee:
            raise NotFoundError(f"Employee {payload.employee_id} not found.")
        if employee.user_id is not None:
            raise ConflictError(
                f"{employee.name} is already linked to another login."
            )

    user = AuthUser(
        email=payload.email,
        hashed_password=hash_password(payload.password),
        role=payload.role,
        is_active=payload.is_active,
    )
    db.add(user)
    db.flush()

    if employee:
        employee.user_id = user.id

    db.commit()
    db.refresh(user)

    return UserWithEmployeeOut(
        id=user.id,
        email=user.email,
        role=user.role,
        is_active=user.is_active,
        created_at=user.created_at,
        employee_id=employee.id if employee else None,
        employee_name=employee.name if employee else None,
        badge_id=employee.badge_id if employee else None,
    )


@router.patch(
    "/users/{user_id}",
    response_model=UserWithEmployeeOut,
    summary="Update a user's role, activation state or password",
)
def update_user(
    user_id: uuid.UUID,
    payload: UserUpdate,
    db: DbSession,
    admin: CurrentUser = Depends(require_admin),
) -> UserWithEmployeeOut:
    user = db.get(AuthUser, user_id)
    if not user:
        raise NotFoundError(f"User {user_id} not found.")

    # Guard rail: never let the last active administrator lock themselves out.
    demoting_self_from_admin = (
        str(user.id) == str(admin.user_id)
        and payload.role is not None
        and payload.role != UserRole.ADMIN
    )
    deactivating_self = str(user.id) == str(admin.user_id) and payload.is_active is False
    if demoting_self_from_admin or deactivating_self:
        remaining = db.execute(
            select(func.count(AuthUser.id)).where(
                AuthUser.role == UserRole.ADMIN,
                AuthUser.is_active.is_(True),
                AuthUser.id != user.id,
            )
        ).scalar_one()
        if remaining == 0:
            raise ConflictError(
                "You are the only active administrator. Promote another admin first."
            )

    # Any of these three changes the user's authority or credentials, so every
    # token already issued to them must stop working immediately.
    authority_changed = False
    if payload.role is not None and payload.role != user.role:
        user.role = payload.role
        authority_changed = True
    if payload.is_active is not None and payload.is_active != user.is_active:
        user.is_active = payload.is_active
        authority_changed = True
    if payload.password:
        user.hashed_password = hash_password(payload.password)
        authority_changed = True

    db.flush()
    if authority_changed:
        revoke_sessions(db, user.id)

    db.commit()
    db.refresh(user)

    employee = db.execute(
        select(Employee).where(Employee.user_id == user.id)
    ).scalars().first()

    return UserWithEmployeeOut(
        id=user.id,
        email=user.email,
        role=user.role,
        is_active=user.is_active,
        created_at=user.created_at,
        employee_id=employee.id if employee else None,
        employee_name=employee.name if employee else None,
        badge_id=employee.badge_id if employee else None,
    )


@router.post(
    "/users/{user_id}/link-employee/{employee_id}",
    response_model=MessageResponse,
    summary="Link an existing login to an employee record",
)
def link_employee(
    user_id: uuid.UUID,
    employee_id: uuid.UUID,
    db: DbSession,
    _: CurrentUser = Depends(require_admin),
) -> MessageResponse:
    user = db.get(AuthUser, user_id)
    if not user:
        raise NotFoundError(f"User {user_id} not found.")
    employee = db.get(Employee, employee_id)
    if not employee:
        raise NotFoundError(f"Employee {employee_id} not found.")

    already = db.execute(
        select(Employee).where(Employee.user_id == user.id, Employee.id != employee.id)
    ).scalars().first()
    if already:
        raise ConflictError(
            f"That login is already linked to {already.name} ({already.badge_id})."
        )
    if employee.user_id is not None and str(employee.user_id) != str(user.id):
        raise ConflictError(f"{employee.name} is already linked to another login.")

    employee.user_id = user.id
    db.commit()
    return MessageResponse(detail=f"Linked {user.email} to {employee.name}.")


# ===========================================================================
# NOTIFICATIONS (all authenticated, owner-scoped)
# ===========================================================================
@router.get(
    "/notifications",
    response_model=List[NotificationOut],
    summary="In-app feed for the badge counter",
)
def list_notifications(
    db: DbSession,
    user: User,
    page: PageParams,
    unread_only: bool = Query(default=False),
) -> List[NotificationOut]:
    stmt = (
        select(Notification)
        .where(Notification.recipient_user_id == user.user_id)
        .order_by(Notification.created_at.desc())
    )
    if unread_only:
        stmt = stmt.where(Notification.is_read.is_(False))
    rows = db.execute(stmt.limit(page.limit).offset(page.offset)).scalars().all()
    return [NotificationOut.model_validate(n) for n in rows]


@router.get(
    "/notifications/unread-count",
    summary="Unread notification count for the badge",
)
def unread_count(db: DbSession, user: User) -> dict:
    count = db.execute(
        select(func.count(Notification.id)).where(
            Notification.recipient_user_id == user.user_id,
            Notification.is_read.is_(False),
        )
    ).scalar_one()
    return {"unread": count}


@router.post(
    "/notifications/{notification_id}/read",
    response_model=MessageResponse,
    summary="Mark a notification read (owner only)",
)
def mark_read(
    notification_id: uuid.UUID, db: DbSession, user: User
) -> MessageResponse:
    notification = db.get(Notification, notification_id)
    if not notification:
        raise NotFoundError("Notification not found.")
    # Owner-scoped: a user may never mark someone else's notification read.
    if str(notification.recipient_user_id) != str(user.user_id):
        raise NotFoundError("Notification not found.")

    notification.is_read = True
    db.commit()
    return MessageResponse(detail="Notification marked read.")


@router.post(
    "/notifications/read-all",
    response_model=MessageResponse,
    summary="Mark every notification read",
)
def mark_all_read(db: DbSession, user: User) -> MessageResponse:
    result = db.execute(
        update(Notification)
        .where(
            Notification.recipient_user_id == user.user_id,
            Notification.is_read.is_(False),
        )
        .values(is_read=True)
    )
    db.commit()
    return MessageResponse(detail=f"Marked {result.rowcount or 0} notification(s) read.")
