"""Salary structures and salary rules (fixed / percentage / sandboxed Python)."""

from __future__ import annotations

import uuid
from datetime import datetime
from decimal import Decimal

from sqlalchemy import (
    Boolean,
    CheckConstraint,
    Index,
    Integer,
    Numeric,
    String,
    Text,
    UniqueConstraint,
)
from sqlalchemy.orm import Mapped, mapped_column, relationship

from app.core.database import Base
from app.models.common import created_at_col, fk_uuid, uuid_pk


class SalaryStructure(Base):
    __tablename__ = "salary_structures"

    id: Mapped[uuid.UUID] = uuid_pk()
    name: Mapped[str] = mapped_column(String(100), nullable=False, unique=True)
    code: Mapped[str] = mapped_column(String(50), nullable=False, unique=True)
    is_active: Mapped[bool] = mapped_column(Boolean, nullable=False, default=True)
    notes: Mapped[str | None] = mapped_column(Text)
    created_at: Mapped[datetime] = created_at_col()

    rules = relationship(
        "SalaryRule",
        back_populates="structure",
        cascade="all, delete-orphan",
        order_by="SalaryRule.sequence",
    )


class SalaryRule(Base):
    __tablename__ = "salary_rules"

    id: Mapped[uuid.UUID] = uuid_pk()
    salary_structure_id: Mapped[uuid.UUID] = fk_uuid(
        "salary_structures.id", nullable=False, ondelete="CASCADE"
    )
    name: Mapped[str] = mapped_column(String(100), nullable=False)
    code: Mapped[str] = mapped_column(String(30), nullable=False)
    sequence: Mapped[int] = mapped_column(Integer, nullable=False, default=10)
    category: Mapped[str] = mapped_column(String(30), nullable=False)

    computation_type: Mapped[str] = mapped_column(String(20), nullable=False)
    fixed_amount: Mapped[Decimal | None] = mapped_column(
        Numeric(12, 2), default=Decimal("0.00")
    )
    percentage_base: Mapped[str | None] = mapped_column(String(30))
    percentage_rate: Mapped[Decimal | None] = mapped_column(Numeric(5, 2))
    python_code: Mapped[str | None] = mapped_column(Text)
    # Multiplier on the computed amount (Odoo's rule "Quantity").
    quantity: Mapped[Decimal] = mapped_column(
        Numeric(8, 2), nullable=False, default=Decimal("1.00")
    )

    is_active: Mapped[bool] = mapped_column(Boolean, nullable=False, default=True)
    created_at: Mapped[datetime] = created_at_col()

    structure = relationship("SalaryStructure", back_populates="rules")

    __table_args__ = (
        UniqueConstraint("salary_structure_id", "code"),
        CheckConstraint(
            "category IN ('BASIC', 'ALLOWANCE', 'GROSS', 'DEDUCTION', 'NET')",
            name="chk_rule_category",
        ),
        CheckConstraint(
            "computation_type IN ('FIXED', 'PERCENTAGE', 'PYTHON_CODE')",
            name="chk_computation_type",
        ),
        Index("idx_salary_rules_order", "salary_structure_id", "sequence"),
    )

    def __repr__(self) -> str:  # pragma: no cover
        return f"<SalaryRule {self.code} seq={self.sequence} {self.computation_type}>"
