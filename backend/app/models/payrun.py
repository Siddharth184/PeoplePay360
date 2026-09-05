"""Payroll batches, payslips and the rule-by-rule payslip lines."""

from __future__ import annotations

import uuid
from datetime import date, datetime
from decimal import Decimal

from sqlalchemy import (
    CheckConstraint,
    Date,
    DateTime,
    Index,
    Integer,
    Numeric,
    String,
    Text,
    UniqueConstraint,
)
from sqlalchemy.orm import Mapped, mapped_column, relationship

from app.core.database import Base
from app.models.common import created_at_col, fk_uuid, updated_at_col, uuid_pk

ZERO = Decimal("0.00")


class Payrun(Base):
    __tablename__ = "payruns"

    id: Mapped[uuid.UUID] = uuid_pk()
    reference_code: Mapped[str] = mapped_column(String(30), nullable=False, unique=True)
    name: Mapped[str] = mapped_column(String(100), nullable=False)
    salary_structure_id: Mapped[uuid.UUID] = fk_uuid(
        "salary_structures.id", nullable=False
    )
    date_start: Mapped[date] = mapped_column(Date, nullable=False)
    date_end: Mapped[date] = mapped_column(Date, nullable=False)
    status: Mapped[str] = mapped_column(String(20), nullable=False, default="DRAFT")

    total_basic: Mapped[Decimal | None] = mapped_column(Numeric(14, 2), default=ZERO)
    total_gross: Mapped[Decimal | None] = mapped_column(Numeric(14, 2), default=ZERO)
    total_net: Mapped[Decimal | None] = mapped_column(Numeric(14, 2), default=ZERO)
    employee_count: Mapped[int | None] = mapped_column(Integer, default=0)
    warnings_count: Mapped[int | None] = mapped_column(Integer, default=0)

    created_by_user_id: Mapped[uuid.UUID | None] = fk_uuid(
        "auth_users.id", ondelete="SET NULL"
    )
    created_at: Mapped[datetime] = created_at_col()
    updated_at: Mapped[datetime] = updated_at_col()

    salary_structure = relationship("SalaryStructure", foreign_keys=[salary_structure_id])
    payslips = relationship(
        "Payslip", back_populates="payrun", cascade="all, delete-orphan"
    )

    __table_args__ = (
        CheckConstraint("date_end >= date_start", name="chk_payrun_dates"),
        CheckConstraint(
            "status IN ('DRAFT', 'COMPUTED', 'VALIDATED', 'PAID')",
            name="chk_payrun_status",
        ),
    )


class Payslip(Base):
    __tablename__ = "payslips"

    id: Mapped[uuid.UUID] = uuid_pk()
    reference_code: Mapped[str] = mapped_column(String(30), nullable=False, unique=True)
    payrun_id: Mapped[uuid.UUID] = fk_uuid(
        "payruns.id", nullable=False, ondelete="CASCADE"
    )
    employee_id: Mapped[uuid.UUID] = fk_uuid("employees.id", nullable=False)
    contract_id: Mapped[uuid.UUID] = fk_uuid("hr_contracts.id", nullable=False)
    salary_structure_id: Mapped[uuid.UUID] = fk_uuid(
        "salary_structures.id", nullable=False
    )

    date_start: Mapped[date] = mapped_column(Date, nullable=False)
    date_end: Mapped[date] = mapped_column(Date, nullable=False)
    worked_days: Mapped[Decimal] = mapped_column(
        Numeric(4, 2), nullable=False, default=ZERO
    )

    basic_amount: Mapped[Decimal] = mapped_column(
        Numeric(12, 2), nullable=False, default=ZERO
    )
    gross_amount: Mapped[Decimal] = mapped_column(
        Numeric(12, 2), nullable=False, default=ZERO
    )
    net_amount: Mapped[Decimal] = mapped_column(
        Numeric(12, 2), nullable=False, default=ZERO
    )

    status: Mapped[str] = mapped_column(String(20), nullable=False, default="DRAFT")
    warning_notes: Mapped[str | None] = mapped_column(Text)
    pdf_url: Mapped[str | None] = mapped_column(String(500))
    emailed_at: Mapped[datetime | None] = mapped_column(DateTime(timezone=True))

    created_at: Mapped[datetime] = created_at_col()

    payrun = relationship("Payrun", back_populates="payslips")
    employee = relationship("Employee", foreign_keys=[employee_id])
    contract = relationship("HrContract", foreign_keys=[contract_id])
    salary_structure = relationship("SalaryStructure", foreign_keys=[salary_structure_id])
    lines = relationship(
        "PayslipLine",
        back_populates="payslip",
        cascade="all, delete-orphan",
        order_by="PayslipLine.sequence",
    )

    __table_args__ = (
        UniqueConstraint("payrun_id", "employee_id", name="uq_payslip_run_employee"),
        CheckConstraint(
            "status IN ('DRAFT', 'DONE', 'PAID')", name="chk_payslip_status"
        ),
        Index("idx_payslips_payrun", "payrun_id"),
        Index("idx_payslips_employee", "employee_id"),
    )


class PayslipLine(Base):
    __tablename__ = "payslip_lines"

    id: Mapped[uuid.UUID] = uuid_pk()
    payslip_id: Mapped[uuid.UUID] = fk_uuid(
        "payslips.id", nullable=False, ondelete="CASCADE"
    )
    salary_rule_id: Mapped[uuid.UUID] = fk_uuid("salary_rules.id", nullable=False)
    rule_name: Mapped[str] = mapped_column(String(100), nullable=False)
    rule_code: Mapped[str] = mapped_column(String(30), nullable=False)
    category: Mapped[str] = mapped_column(String(30), nullable=False)
    sequence: Mapped[int] = mapped_column(Integer, nullable=False)
    amount: Mapped[Decimal] = mapped_column(Numeric(12, 2), nullable=False)
    created_at: Mapped[datetime] = created_at_col()

    payslip = relationship("Payslip", back_populates="lines")
    salary_rule = relationship("SalaryRule", foreign_keys=[salary_rule_id])

    __table_args__ = (
        UniqueConstraint("payslip_id", "salary_rule_id", name="uq_payslip_line_rule"),
    )
