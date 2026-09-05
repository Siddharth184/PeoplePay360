"""Master data: departments, job positions, working schedules, holidays."""

from __future__ import annotations

import uuid
from datetime import date, datetime, time
from decimal import Decimal

from sqlalchemy import (
    Boolean,
    CheckConstraint,
    Computed,
    Date,
    Integer,
    Numeric,
    String,
    Time,
    UniqueConstraint,
)
from sqlalchemy.orm import Mapped, mapped_column, relationship

from app.core.database import Base
from app.models.common import created_at_col, fk_uuid, uuid_pk

DAY_NAMES = [
    "Monday",
    "Tuesday",
    "Wednesday",
    "Thursday",
    "Friday",
    "Saturday",
    "Sunday",
]


class Department(Base):
    __tablename__ = "departments"

    id: Mapped[uuid.UUID] = uuid_pk()
    name: Mapped[str] = mapped_column(String(100), nullable=False, unique=True)
    manager_employee_id: Mapped[uuid.UUID | None] = fk_uuid(
        "employees.id", ondelete="SET NULL"
    )
    is_active: Mapped[bool] = mapped_column(Boolean, nullable=False, default=True)
    created_at: Mapped[datetime] = created_at_col()

    job_positions = relationship("JobPosition", back_populates="department")
    manager = relationship(
        "Employee", foreign_keys=[manager_employee_id], post_update=True
    )


class JobPosition(Base):
    __tablename__ = "job_positions"

    id: Mapped[uuid.UUID] = uuid_pk()
    name: Mapped[str] = mapped_column(String(100), nullable=False)
    department_id: Mapped[uuid.UUID] = fk_uuid("departments.id", nullable=False)
    created_at: Mapped[datetime] = created_at_col()

    department = relationship("Department", back_populates="job_positions")

    __table_args__ = (UniqueConstraint("name", "department_id"),)


class WorkingSchedule(Base):
    __tablename__ = "working_schedules"

    id: Mapped[uuid.UUID] = uuid_pk()
    name: Mapped[str] = mapped_column(String(100), nullable=False, unique=True)
    company_name: Mapped[str] = mapped_column(
        String(100), nullable=False, default="OXP Pvt Ltd"
    )
    days_per_week: Mapped[int] = mapped_column(Integer, nullable=False, default=5)
    hours_per_week: Mapped[Decimal] = mapped_column(
        Numeric(5, 2), nullable=False, default=Decimal("40.00")
    )
    timezone: Mapped[str] = mapped_column(
        String(50), nullable=False, default="Asia/Kolkata"
    )
    is_active: Mapped[bool] = mapped_column(Boolean, nullable=False, default=True)
    created_at: Mapped[datetime] = created_at_col()

    lines = relationship(
        "WorkingScheduleLine",
        back_populates="schedule",
        cascade="all, delete-orphan",
        order_by="WorkingScheduleLine.day_of_week",
    )


class WorkingScheduleLine(Base):
    __tablename__ = "working_schedule_lines"

    id: Mapped[uuid.UUID] = uuid_pk()
    schedule_id: Mapped[uuid.UUID] = fk_uuid(
        "working_schedules.id", nullable=False, ondelete="CASCADE"
    )
    day_of_week: Mapped[int] = mapped_column(Integer, nullable=False)
    day_name: Mapped[str] = mapped_column(String(15), nullable=False)
    start_time: Mapped[time] = mapped_column(Time, nullable=False)
    end_time: Mapped[time] = mapped_column(Time, nullable=False)
    break_hours: Mapped[Decimal] = mapped_column(
        Numeric(4, 2), nullable=False, default=Decimal("1.00")
    )
    # GENERATED ALWAYS ... STORED in PostgreSQL. Computed() marks it read-only so
    # SQLAlchemy never tries to write it.
    work_hours: Mapped[Decimal | None] = mapped_column(
        Numeric(4, 2),
        Computed(
            "EXTRACT(EPOCH FROM (end_time - start_time)) / 3600 - break_hours",
            persisted=True,
        ),
        nullable=True,
    )

    schedule = relationship("WorkingSchedule", back_populates="lines")

    __table_args__ = (
        CheckConstraint("day_of_week BETWEEN 0 AND 6", name="chk_day_of_week"),
        CheckConstraint("end_time > start_time", name="chk_times"),
        UniqueConstraint("schedule_id", "day_of_week", "start_time"),
    )


class PublicHoliday(Base):
    __tablename__ = "public_holidays"

    id: Mapped[uuid.UUID] = uuid_pk()
    name: Mapped[str] = mapped_column(String(100), nullable=False)
    holiday_date: Mapped[date] = mapped_column(Date, nullable=False, unique=True)
    created_at: Mapped[datetime] = created_at_col()
