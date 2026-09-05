"""Authentication, RBAC and the in-app notification feed."""

from __future__ import annotations

import uuid
from datetime import datetime

from sqlalchemy import Boolean, DateTime, Integer, String, Text, func, text
from sqlalchemy.orm import Mapped, mapped_column, relationship

from app.core.database import Base
from app.models.common import created_at_col, fk_uuid, pg_enum, updated_at_col, uuid_pk
from app.models.enums import UserRole


class AuthUser(Base):
    __tablename__ = "auth_users"

    id: Mapped[uuid.UUID] = uuid_pk()
    email: Mapped[str] = mapped_column(String(255), unique=True, nullable=False)
    hashed_password: Mapped[str] = mapped_column(String(255), nullable=False)
    role: Mapped[UserRole] = mapped_column(
        pg_enum(UserRole, "user_role_enum"), nullable=False, default=UserRole.EMPLOYEE
    )
    is_active: Mapped[bool] = mapped_column(Boolean, nullable=False, default=True)
    # Every token embeds the version current at login. Bumping this invalidates all
    # previously issued tokens: see security.revoke_sessions.
    token_version: Mapped[int] = mapped_column(
        Integer, nullable=False, default=1, server_default=text("1")
    )
    credentials_changed_at: Mapped[datetime] = mapped_column(
        DateTime(timezone=True), nullable=False, server_default=func.now()
    )
    created_at: Mapped[datetime] = created_at_col()
    updated_at: Mapped[datetime] = updated_at_col()

    employee = relationship(
        "Employee", back_populates="user", uselist=False, foreign_keys="Employee.user_id"
    )

    def __repr__(self) -> str:  # pragma: no cover - debugging aid
        return f"<AuthUser {self.email} role={self.role}>"


class Notification(Base):
    __tablename__ = "notifications"

    id: Mapped[uuid.UUID] = uuid_pk()
    recipient_user_id: Mapped[uuid.UUID] = fk_uuid(
        "auth_users.id", nullable=False, ondelete="CASCADE"
    )
    kind: Mapped[str] = mapped_column(String(40), nullable=False)
    title: Mapped[str] = mapped_column(String(160), nullable=False)
    body: Mapped[str | None] = mapped_column(Text)
    deep_link: Mapped[str | None] = mapped_column(String(200))
    escalation_id: Mapped[uuid.UUID | None] = fk_uuid(
        "rag_escalations.id", ondelete="CASCADE"
    )
    is_read: Mapped[bool] = mapped_column(Boolean, nullable=False, default=False)
    created_at: Mapped[datetime] = created_at_col()
