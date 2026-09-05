"""Shared FastAPI dependencies and row-scoping helpers."""

from __future__ import annotations

import uuid
from typing import Annotated

from fastapi import Depends, Query
from sqlalchemy import func, select
from sqlalchemy.orm import Session

from app.core.database import get_db
from app.core.errors import ForbiddenError, NotFoundError
from app.core.security import CurrentUser, get_current_user
from app.models.employee import Employee

DbSession = Annotated[Session, Depends(get_db)]
User = Annotated[CurrentUser, Depends(get_current_user)]


class Pagination:
    """Reusable ?limit=&offset= pair."""

    def __init__(
        self,
        limit: int = Query(default=50, ge=1, le=200),
        offset: int = Query(default=0, ge=0),
    ) -> None:
        self.limit = limit
        self.offset = offset


PageParams = Annotated[Pagination, Depends(Pagination)]


def require_linked_employee(user: CurrentUser) -> uuid.UUID:
    """Endpoints acting on 'me' need the caller to have an employee record."""
    if user.employee_id is None:
        raise ForbiddenError(
            "Your login is not linked to an employee record. Ask an administrator "
            "to link your account before using this feature."
        )
    return user.employee_id


def resolve_target_employee(
    user: CurrentUser, requested_employee_id: uuid.UUID | None
) -> uuid.UUID:
    """Decide which employee an action applies to.

    HR-scope roles may act on anyone; everyone else is silently pinned to
    themselves. An employee explicitly naming someone else's id is a 403, not a
    quiet redirect, so a broken client is visible instead of confusing.
    """
    if requested_employee_id is None:
        return require_linked_employee(user)
    if user.has_hr_scope:
        return requested_employee_id
    if str(requested_employee_id) != str(user.employee_id):
        raise ForbiddenError("You may only perform this action for yourself.")
    return requested_employee_id


def get_employee_or_404(db: Session, employee_id: uuid.UUID | str) -> Employee:
    employee = db.get(Employee, employee_id)
    if not employee:
        raise NotFoundError(f"Employee {employee_id} not found.")
    return employee


def scope_employee_filter(user: CurrentUser) -> uuid.UUID | None:
    """Returns the employee_id an EMPLOYEE caller must be restricted to.

    None means "no restriction" (HR scope). Callers pass this straight into
    repository queries, so scoping is enforced server-side, never by the client.
    """
    if user.has_hr_scope:
        return None
    return require_linked_employee(user)


def employee_count(db: Session) -> int:
    return db.execute(select(func.count(Employee.id))).scalar_one()
