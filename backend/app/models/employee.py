"""Employee master record."""

from __future__ import annotations

import uuid
from datetime import date, datetime

from sqlalchemy import CheckConstraint, Date, String, func
from sqlalchemy.orm import Mapped, mapped_column, relationship

from app.core.database import Base
from app.models.common import created_at_col, fk_uuid, updated_at_col, uuid_pk

# Columns that only Payroll / Admin roles may ever see. The serialisation layer
# reads this list so a new private field cannot be forgotten in one endpoint.
PRIVATE_FIELDS = (
    "bank_account_number",
    "bank_name",
    "bank_ifsc_or_routing",
    "pan_or_ssn",
)


class Employee(Base):
    __tablename__ = "employees"

    id: Mapped[uuid.UUID] = uuid_pk()
    user_id: Mapped[uuid.UUID | None] = fk_uuid(
        "auth_users.id", ondelete="SET NULL", unique=True
    )
    badge_id: Mapped[str] = mapped_column(String(20), nullable=False, unique=True)
    name: Mapped[str] = mapped_column(String(150), nullable=False)
    work_email: Mapped[str] = mapped_column(String(255), nullable=False, unique=True)
    phone: Mapped[str | None] = mapped_column(String(25))

    department_id: Mapped[uuid.UUID | None] = fk_uuid("departments.id")
    job_position_id: Mapped[uuid.UUID | None] = fk_uuid("job_positions.id")
    manager_id: Mapped[uuid.UUID | None] = fk_uuid("employees.id", ondelete="SET NULL")
    working_schedule_id: Mapped[uuid.UUID | None] = fk_uuid("working_schedules.id")

    work_location: Mapped[str | None] = mapped_column(String(100), default="Mumbai")
    status: Mapped[str] = mapped_column(String(20), nullable=False, default="ACTIVE")
    employee_type: Mapped[str] = mapped_column(
        String(20), nullable=False, default="PERMANENT"
    )
    company_name: Mapped[str] = mapped_column(
        String(100), nullable=False, default="OXP Pvt Ltd"
    )

    # --- Private Information (Restricted to Payroll / Admin) ----------------
    bank_account_number: Mapped[str | None] = mapped_column(String(50))
    bank_name: Mapped[str | None] = mapped_column(String(100))
    bank_ifsc_or_routing: Mapped[str | None] = mapped_column(String(30))
    pan_or_ssn: Mapped[str | None] = mapped_column(String(30))

    date_of_joining: Mapped[date] = mapped_column(
        Date, nullable=False, server_default=func.current_date()
    )

    created_at: Mapped[datetime] = created_at_col()
    updated_at: Mapped[datetime] = updated_at_col()

    user = relationship("AuthUser", back_populates="employee", foreign_keys=[user_id])
    department = relationship("Department", foreign_keys=[department_id])
    job_position = relationship("JobPosition", foreign_keys=[job_position_id])
    working_schedule = relationship("WorkingSchedule", foreign_keys=[working_schedule_id])
    manager = relationship("Employee", remote_side=[id], foreign_keys=[manager_id])

    contracts = relationship(
        "HrContract",
        back_populates="employee",
        cascade="all, delete-orphan",
        order_by="HrContract.start_date.desc()",
    )

    __table_args__ = (
        CheckConstraint(
            "status IN ('ACTIVE', 'INACTIVE', 'TERMINATED')", name="chk_employee_status"
        ),
        CheckConstraint(
            "manager_id IS NULL OR manager_id <> id", name="chk_not_self_manager"
        ),
    )

    @property
    def has_bank_details(self) -> bool:
        return bool(self.bank_account_number and self.bank_ifsc_or_routing)

    def __repr__(self) -> str:  # pragma: no cover
        return f"<Employee {self.badge_id} {self.name}>"
