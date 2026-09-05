"""Employment contracts with the period-overlap integrity guard."""

from __future__ import annotations

import uuid
from datetime import date, datetime
from decimal import Decimal

from sqlalchemy import CheckConstraint, Date, Index, Numeric, String, Text
from sqlalchemy.orm import Mapped, mapped_column, relationship

from app.core.database import Base
from app.models.common import created_at_col, fk_uuid, updated_at_col, uuid_pk


class HrContract(Base):
    __tablename__ = "hr_contracts"

    id: Mapped[uuid.UUID] = uuid_pk()
    reference_code: Mapped[str] = mapped_column(String(30), nullable=False, unique=True)
    employee_id: Mapped[uuid.UUID] = fk_uuid(
        "employees.id", nullable=False, ondelete="CASCADE"
    )
    department_id: Mapped[uuid.UUID | None] = fk_uuid("departments.id")
    job_position_id: Mapped[uuid.UUID | None] = fk_uuid("job_positions.id")
    working_schedule_id: Mapped[uuid.UUID | None] = fk_uuid("working_schedules.id")
    salary_structure_id: Mapped[uuid.UUID | None] = fk_uuid(
        "salary_structures.id", ondelete="SET NULL"
    )

    start_date: Mapped[date] = mapped_column(Date, nullable=False)
    end_date: Mapped[date | None] = mapped_column(Date)  # NULL == ongoing
    wage_monthly: Mapped[Decimal] = mapped_column(Numeric(12, 2), nullable=False)

    status: Mapped[str] = mapped_column(String(20), nullable=False, default="DRAFT")
    notes: Mapped[str | None] = mapped_column(Text)

    created_at: Mapped[datetime] = created_at_col()
    updated_at: Mapped[datetime] = updated_at_col()

    employee = relationship("Employee", back_populates="contracts")
    department = relationship("Department", foreign_keys=[department_id])
    job_position = relationship("JobPosition", foreign_keys=[job_position_id])
    working_schedule = relationship("WorkingSchedule", foreign_keys=[working_schedule_id])

    __table_args__ = (
        CheckConstraint("wage_monthly >= 0", name="chk_wage_positive"),
        CheckConstraint(
            "status IN ('DRAFT', 'RUNNING', 'EXPIRED', 'CANCELLED')",
            name="chk_contract_status",
        ),
        CheckConstraint("end_date IS NULL OR end_date >= start_date", name="chk_dates"),
        Index("idx_contracts_employee_running", "employee_id", "status"),
    )

    # Alias so salary rule expressions can use the familiar Odoo `contract.wage`
    @property
    def wage(self) -> Decimal:
        return self.wage_monthly

    def covers(self, period_start: date, period_end: date) -> bool:
        return self.start_date <= period_end and (
            self.end_date is None or self.end_date >= period_start
        )

    def __repr__(self) -> str:  # pragma: no cover
        return f"<HrContract {self.reference_code} {self.status}>"
