"""Reusable column helpers shared by every model."""

from __future__ import annotations

import uuid
from datetime import datetime
from typing import Any

from sqlalchemy import DateTime, func, text
from sqlalchemy.dialects.postgresql import ENUM as PgEnum
from sqlalchemy.dialects.postgresql import UUID as PgUUID
from sqlalchemy.orm import Mapped, mapped_column


def uuid_pk() -> Mapped[uuid.UUID]:
    return mapped_column(
        PgUUID(as_uuid=True),
        primary_key=True,
        server_default=text("uuid_generate_v4()"),
        default=uuid.uuid4,
    )


def fk_uuid(target: str, *, nullable: bool = True, ondelete: str = "RESTRICT", **kw: Any):
    from sqlalchemy import ForeignKey

    return mapped_column(
        PgUUID(as_uuid=True),
        ForeignKey(target, ondelete=ondelete),
        nullable=nullable,
        **kw,
    )


def created_at_col() -> Mapped[datetime]:
    return mapped_column(
        DateTime(timezone=True), nullable=False, server_default=func.now()
    )


def updated_at_col() -> Mapped[datetime]:
    # A database trigger (fn_touch_updated_at) also maintains this, so raw SQL
    # paths stay correct too.
    return mapped_column(
        DateTime(timezone=True),
        nullable=False,
        server_default=func.now(),
        onupdate=func.now(),
    )


def pg_enum(py_enum: type, name: str) -> PgEnum:
    """Bind to an EXISTING PostgreSQL enum type (created by db/schema.sql)."""
    return PgEnum(py_enum, name=name, create_type=False, native_enum=True)
