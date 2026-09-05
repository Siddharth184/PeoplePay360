"""Time off: types, allocations (the ledger) and requests."""

from __future__ import annotations

import uuid
from datetime import date, datetime
from decimal import Decimal

from sqlalchemy import (
    Boolean,
    CheckConstraint,
    Computed,
    Date,
    Index,
    Integer,
    Numeric,
    String,
    Text,
    text,
)
from sqlalchemy.orm import Mapped, mapped_column, relationship

from app.core.database import Base
from app.models.common import created_at_col, fk_uuid, uuid_pk


class TimeOffType(Base):
    __tablename__ = "timeoff_types"

    id: Mapped[uuid.UUID] = uuid_pk()
    name: Mapped[str] = mapped_column(String(50), nullable=False, unique=True)
    unit: Mapped[str] = mapped_column(String(10), nullable=False, default="DAYS")
    requires_allocation: Mapped[bool] = mapped_column(
        Boolean, nullable=False, default=True
    )
    approval_level: Mapped[str] = mapped_column(
        String(20), nullable=False, default="MANAGER"
    )
    display_color: Mapped[str] = mapped_column(
        String(20), nullable=False, default="#017E84"
    )
    is_active: Mapped[bool] = mapped_column(Boolean, nullable=False, default=True)
    created_at: Mapped[datetime] = created_at_col()

    # How the leave surfaces on a payslip work entry, and free-text policy notes.
    work_entry_type: Mapped[str | None] = mapped_column(String(50))
    notes: Mapped[str | None] = mapped_column(Text)

    __table_args__ = (
        CheckConstraint("unit IN ('DAYS', 'HOURS')", name="chk_timeoff_unit"),
        CheckConstraint(
            "approval_level IN ('MANAGER', 'HR_OFFICER', 'NONE')",
            name="chk_approval_level",
        ),
    )


class LeaveAllocation(Base):
    __tablename__ = "leave_allocations"

    id: Mapped[uuid.UUID] = uuid_pk()
    employee_id: Mapped[uuid.UUID] = fk_uuid(
        "employees.id", nullable=False, ondelete="CASCADE"
    )
    timeoff_type_id: Mapped[uuid.UUID] = fk_uuid("timeoff_types.id", nullable=False)
    allocated_days: Mapped[Decimal] = mapped_column(Numeric(5, 2), nullable=False)
    taken_days: Mapped[Decimal] = mapped_column(
        Numeric(5, 2), nullable=False, default=Decimal("0.00")
    )
    # GENERATED ALWAYS ... STORED - read only.
    remaining_days: Mapped[Decimal | None] = mapped_column(
        Numeric(5, 2),
        Computed("allocated_days - taken_days", persisted=True),
        nullable=True,
    )
    validity_year: Mapped[int] = mapped_column(
        Integer, nullable=False, server_default=text("EXTRACT(YEAR FROM CURRENT_DATE)")
    )
    validity_label: Mapped[str | None] = mapped_column(String(60))
    status: Mapped[str] = mapped_column(String(20), nullable=False, default="TO_APPROVE")
    approver_employee_id: Mapped[uuid.UUID | None] = fk_uuid(
        "employees.id", ondelete="SET NULL"
    )
    description: Mapped[str | None] = mapped_column(Text)
    created_at: Mapped[datetime] = created_at_col()

    employee = relationship("Employee", foreign_keys=[employee_id])
    timeoff_type = relationship("TimeOffType", foreign_keys=[timeoff_type_id])

    __table_args__ = (
        CheckConstraint("allocated_days >= 0", name="chk_allocated_positive"),
        CheckConstraint("taken_days >= 0", name="chk_taken_positive"),
        CheckConstraint("taken_days <= allocated_days", name="chk_taken_le_alloc"),
        CheckConstraint(
            "status IN ('TO_APPROVE', 'APPROVED', 'REFUSED')", name="chk_alloc_status"
        ),
        Index(
            "idx_allocations_emp_type", "employee_id", "timeoff_type_id", "status"
        ),
    )


class LeaveRequest(Base):
    __tablename__ = "leave_requests"

    id: Mapped[uuid.UUID] = uuid_pk()
    employee_id: Mapped[uuid.UUID] = fk_uuid(
        "employees.id", nullable=False, ondelete="CASCADE"
    )
    timeoff_type_id: Mapped[uuid.UUID] = fk_uuid("timeoff_types.id", nullable=False)
    allocation_id: Mapped[uuid.UUID | None] = fk_uuid(
        "leave_allocations.id", ondelete="SET NULL"
    )
    start_date: Mapped[date] = mapped_column(Date, nullable=False)
    end_date: Mapped[date] = mapped_column(Date, nullable=False)
    duration_days: Mapped[Decimal] = mapped_column(Numeric(4, 2), nullable=False)
    reason: Mapped[str | None] = mapped_column(Text)
    status: Mapped[str] = mapped_column(String(20), nullable=False, default="TO_APPROVE")
    approver_employee_id: Mapped[uuid.UUID | None] = fk_uuid(
        "employees.id", ondelete="SET NULL"
    )
    created_at: Mapped[datetime] = created_at_col()

    employee = relationship("Employee", foreign_keys=[employee_id])
    timeoff_type = relationship("TimeOffType", foreign_keys=[timeoff_type_id])
    allocation = relationship("LeaveAllocation", foreign_keys=[allocation_id])

    __table_args__ = (
        CheckConstraint("duration_days > 0", name="chk_duration_positive"),
        CheckConstraint("end_date >= start_date", name="chk_leave_dates"),
        CheckConstraint(
            "status IN ('TO_APPROVE', 'APPROVED', 'REFUSED')", name="chk_request_status"
        ),
        Index("idx_leave_requests_emp", "employee_id", "status"),
    )
