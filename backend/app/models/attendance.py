"""Attendance punches."""

from __future__ import annotations

import uuid
from datetime import datetime
from decimal import Decimal

from sqlalchemy import Boolean, CheckConstraint, DateTime, Index, Numeric, String, Text
from sqlalchemy.orm import Mapped, mapped_column, relationship

from app.core.database import Base
from app.models.common import created_at_col, fk_uuid, uuid_pk


class Attendance(Base):
    __tablename__ = "attendances"

    id: Mapped[uuid.UUID] = uuid_pk()
    employee_id: Mapped[uuid.UUID] = fk_uuid(
        "employees.id", nullable=False, ondelete="CASCADE"
    )
    check_in: Mapped[datetime] = mapped_column(DateTime(timezone=True), nullable=False)
    check_out: Mapped[datetime | None] = mapped_column(DateTime(timezone=True))
    worked_hours: Mapped[Decimal | None] = mapped_column(
        Numeric(5, 2), default=Decimal("0.00")
    )
    overtime_hours: Mapped[Decimal | None] = mapped_column(
        Numeric(5, 2), default=Decimal("0.00")
    )
    status: Mapped[str] = mapped_column(String(20), nullable=False, default="PRESENT")
    is_manual_edit: Mapped[bool] = mapped_column(Boolean, nullable=False, default=False)
    audit_notes: Mapped[str | None] = mapped_column(Text)
    created_at: Mapped[datetime] = created_at_col()

    employee = relationship("Employee", foreign_keys=[employee_id])

    __table_args__ = (
        CheckConstraint(
            "status IN ('PRESENT', 'LATE', 'ABSENT', 'HALF_DAY')",
            name="chk_attendance_status",
        ),
        CheckConstraint(
            "check_out IS NULL OR check_out >= check_in", name="chk_check_in_out"
        ),
        Index("idx_attendance_emp_date", "employee_id", "check_in"),
    )

    @property
    def is_open(self) -> bool:
        return self.check_out is None
