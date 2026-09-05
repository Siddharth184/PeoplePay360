"""Master data, employee, contract, attendance and time off schemas."""

from __future__ import annotations

import uuid
from datetime import date, datetime, time
from decimal import Decimal
from typing import List, Optional

from pydantic import BaseModel, EmailStr, Field, field_validator, model_validator

from app.models.enums import (
    ApprovalStatus,
    AttendanceStatus,
    ContractStatus,
    EmployeeStatus,
)
from app.schemas.common import ORMModel

DAY_NAMES = [
    "Monday",
    "Tuesday",
    "Wednesday",
    "Thursday",
    "Friday",
    "Saturday",
    "Sunday",
]


# ===========================================================================
# DEPARTMENTS / POSITIONS
# ===========================================================================
class DepartmentCreate(BaseModel):
    name: str = Field(min_length=1, max_length=100)
    manager_employee_id: Optional[uuid.UUID] = None
    is_active: bool = True


class DepartmentUpdate(BaseModel):
    name: Optional[str] = Field(default=None, min_length=1, max_length=100)
    manager_employee_id: Optional[uuid.UUID] = None
    is_active: Optional[bool] = None


class JobPositionUpdate(BaseModel):
    name: Optional[str] = Field(default=None, min_length=1, max_length=100)
    department_id: Optional[uuid.UUID] = None


class WorkingScheduleUpdate(BaseModel):
    name: Optional[str] = Field(default=None, min_length=1, max_length=100)
    company_name: Optional[str] = Field(default=None, max_length=100)
    days_per_week: Optional[int] = Field(default=None, ge=1, le=7)
    hours_per_week: Optional[Decimal] = Field(
        default=None, ge=0, le=Decimal("168")
    )
    timezone: Optional[str] = Field(default=None, max_length=50)
    is_active: Optional[bool] = None
    lines: Optional[List["ScheduleLineCreate"]] = Field(
        default=None,
        description="When supplied, REPLACES the entire weekly pattern.",
    )


class DepartmentOut(ORMModel):
    id: uuid.UUID
    name: str
    manager_employee_id: Optional[uuid.UUID] = None
    is_active: bool
    created_at: datetime


class DepartmentWithStatsOut(DepartmentOut):
    manager_name: Optional[str] = None
    employee_count: int = 0


class JobPositionCreate(BaseModel):
    name: str = Field(min_length=1, max_length=100)
    department_id: uuid.UUID


class JobPositionOut(ORMModel):
    id: uuid.UUID
    name: str
    department_id: uuid.UUID
    created_at: datetime


# ===========================================================================
# WORKING SCHEDULES
# ===========================================================================
class ScheduleLineCreate(BaseModel):
    day_of_week: int = Field(ge=0, le=6, description="0=Monday .. 6=Sunday")
    start_time: time
    end_time: time
    break_hours: Decimal = Field(default=Decimal("1.00"), ge=0, le=12)
    day_name: Optional[str] = None

    @model_validator(mode="after")
    def _check(self) -> "ScheduleLineCreate":
        if self.end_time <= self.start_time:
            raise ValueError("end_time must be later than start_time")
        if self.day_name is None:
            self.day_name = DAY_NAMES[self.day_of_week]
        return self


class ScheduleLineOut(ORMModel):
    id: uuid.UUID
    day_of_week: int
    day_name: str
    start_time: time
    end_time: time
    break_hours: Decimal
    work_hours: Optional[Decimal] = None


class WorkingScheduleCreate(BaseModel):
    name: str = Field(min_length=1, max_length=100)
    company_name: Optional[str] = None
    days_per_week: int = Field(default=5, ge=1, le=7)
    hours_per_week: Decimal = Field(default=Decimal("40.00"), ge=0, le=Decimal("168"))
    timezone: Optional[str] = None
    lines: List[ScheduleLineCreate] = Field(default_factory=list)

    @field_validator("lines")
    @classmethod
    def _no_duplicate_days(cls, lines: List[ScheduleLineCreate]):
        seen = {(l.day_of_week, l.start_time) for l in lines}
        if len(seen) != len(lines):
            raise ValueError("duplicate day_of_week + start_time in schedule lines")
        return lines


class WorkingScheduleOut(ORMModel):
    id: uuid.UUID
    name: str
    company_name: str
    days_per_week: int
    hours_per_week: Decimal
    timezone: str
    is_active: bool
    created_at: datetime
    lines: List[ScheduleLineOut] = Field(default_factory=list)


class PublicHolidayCreate(BaseModel):
    name: str = Field(min_length=1, max_length=100)
    holiday_date: date


class PublicHolidayOut(ORMModel):
    id: uuid.UUID
    name: str
    holiday_date: date


# ===========================================================================
# EMPLOYEES
# ===========================================================================
class EmployeeBase(BaseModel):
    name: str = Field(min_length=1, max_length=150)
    work_email: EmailStr
    phone: Optional[str] = Field(default=None, max_length=25)
    department_id: Optional[uuid.UUID] = None
    job_position_id: Optional[uuid.UUID] = None
    manager_id: Optional[uuid.UUID] = None
    working_schedule_id: Optional[uuid.UUID] = None
    work_location: Optional[str] = Field(default="Mumbai", max_length=100)
    status: EmployeeStatus = EmployeeStatus.ACTIVE
    employee_type: str = Field(
        default="PERMANENT",
        pattern="^(PERMANENT|PROBATION|CONTRACT|INTERN|CONSULTANT)$",
    )
    company_name: Optional[str] = Field(default=None, max_length=100)
    date_of_joining: Optional[date] = None


class EmployeePrivateFields(BaseModel):
    """Only ever populated for HR_PAYROLL_* / ADMIN callers."""

    bank_account_number: Optional[str] = Field(default=None, max_length=50)
    bank_name: Optional[str] = Field(default=None, max_length=100)
    bank_ifsc_or_routing: Optional[str] = Field(default=None, max_length=30)
    pan_or_ssn: Optional[str] = Field(default=None, max_length=30)


class EmployeeCreate(EmployeeBase, EmployeePrivateFields):
    badge_id: Optional[str] = Field(default=None, max_length=20)
    # Optionally provision a login in the same call
    create_login: bool = False
    login_password: Optional[str] = Field(default=None, min_length=8, max_length=256)
    login_role: Optional[str] = None

    @model_validator(mode="after")
    def _login_needs_password(self) -> "EmployeeCreate":
        if self.create_login and not self.login_password:
            raise ValueError("login_password is required when create_login is true")
        return self


class EmployeeUpdate(BaseModel):
    name: Optional[str] = Field(default=None, min_length=1, max_length=150)
    work_email: Optional[EmailStr] = None
    phone: Optional[str] = Field(default=None, max_length=25)
    department_id: Optional[uuid.UUID] = None
    department_name: Optional[str] = None
    job_position_id: Optional[uuid.UUID] = None
    job_position_name: Optional[str] = None
    manager_id: Optional[uuid.UUID] = None
    working_schedule_id: Optional[uuid.UUID] = None
    work_location: Optional[str] = Field(default=None, max_length=100)
    status: Optional[EmployeeStatus] = None
    employee_type: Optional[str] = Field(
        default=None, pattern="^(PERMANENT|PROBATION|CONTRACT|INTERN|CONSULTANT)$"
    )
    company_name: Optional[str] = Field(default=None, max_length=100)
    date_of_joining: Optional[date] = None
    bank_account_number: Optional[str] = Field(default=None, max_length=50)
    bank_name: Optional[str] = Field(default=None, max_length=100)
    bank_ifsc_or_routing: Optional[str] = Field(default=None, max_length=30)
    pan_or_ssn: Optional[str] = Field(default=None, max_length=30)


class EmployeeOut(ORMModel):
    id: uuid.UUID
    badge_id: str
    name: str
    work_email: EmailStr
    phone: Optional[str] = None
    department_id: Optional[uuid.UUID] = None
    department_name: Optional[str] = None
    job_position_id: Optional[uuid.UUID] = None
    job_position_name: Optional[str] = None
    manager_id: Optional[uuid.UUID] = None
    manager_name: Optional[str] = None
    working_schedule_id: Optional[uuid.UUID] = None
    working_schedule_name: Optional[str] = None
    work_location: Optional[str] = None
    status: EmployeeStatus
    employee_type: str = "PERMANENT"
    company_name: Optional[str] = None
    date_of_joining: date
    user_id: Optional[uuid.UUID] = None
    has_login: bool = False
    created_at: datetime

    # Private block: omitted entirely for non-privileged callers
    bank_account_number: Optional[str] = None
    bank_name: Optional[str] = None
    bank_ifsc_or_routing: Optional[str] = None
    pan_or_ssn: Optional[str] = None


class EmployeeSmartCounts(BaseModel):
    contracts_total: int = 0
    contracts_running: int = 0
    payslips_total: int = 0
    attendance_records: int = 0
    timeoff_requests_pending: int = 0
    open_escalations: int = 0


class EmployeeDetailOut(EmployeeOut):
    """The 'employee 360' payload backing the profile screen."""

    counts: EmployeeSmartCounts
    active_contract: Optional["ContractOut"] = None
    leave_balances: List["LeaveBalanceOut"] = Field(default_factory=list)


# ===========================================================================
# CONTRACTS
# ===========================================================================
class ContractCreate(BaseModel):
    employee_id: uuid.UUID
    start_date: date
    end_date: Optional[date] = None
    wage_monthly: Decimal = Field(ge=0, max_digits=12, decimal_places=2)
    department_id: Optional[uuid.UUID] = None
    job_position_id: Optional[uuid.UUID] = None
    working_schedule_id: Optional[uuid.UUID] = None
    salary_structure_id: Optional[uuid.UUID] = None
    status: ContractStatus = ContractStatus.DRAFT
    notes: Optional[str] = None

    @model_validator(mode="after")
    def _check_dates(self) -> "ContractCreate":
        if self.end_date and self.end_date < self.start_date:
            raise ValueError("end_date cannot precede start_date")
        return self


class ContractStatusUpdate(BaseModel):
    status: ContractStatus


class ContractUpdate(BaseModel):
    """In-place correction. For a real pay change use ContractWageRevision."""

    wage_monthly: Optional[Decimal] = Field(
        default=None, ge=0, max_digits=12, decimal_places=2
    )
    start_date: Optional[date] = None
    end_date: Optional[date] = None
    department_id: Optional[uuid.UUID] = None
    job_position_id: Optional[uuid.UUID] = None
    working_schedule_id: Optional[uuid.UUID] = None
    salary_structure_id: Optional[uuid.UUID] = None
    notes: Optional[str] = None


class ContractWageRevision(BaseModel):
    """Supersede a contract from a date rather than overwriting its wage."""

    new_wage: Decimal = Field(ge=0, max_digits=12, decimal_places=2)
    effective_from: date
    reason: Optional[str] = Field(default=None, max_length=500)


class ContractRevisionResult(BaseModel):
    previous_contract: ContractOut
    new_contract: ContractOut
    previous_wage: Decimal
    new_wage: Decimal
    effective_from: date
    note: str


class ContractUpdateResult(BaseModel):
    contract: ContractOut
    notes: List[str] = Field(default_factory=list)


class ContractOut(ORMModel):
    id: uuid.UUID
    reference_code: str
    employee_id: uuid.UUID
    employee_name: Optional[str] = None
    department_id: Optional[uuid.UUID] = None
    job_position_id: Optional[uuid.UUID] = None
    working_schedule_id: Optional[uuid.UUID] = None
    salary_structure_id: Optional[uuid.UUID] = None
    start_date: date
    end_date: Optional[date] = None
    wage_monthly: Decimal
    status: ContractStatus
    notes: Optional[str] = None
    created_at: datetime


# ===========================================================================
# ATTENDANCE
# ===========================================================================
class PunchRequest(BaseModel):
    employee_id: Optional[uuid.UUID] = Field(
        default=None,
        description="HR only. Employees always punch for themselves.",
    )
    at: Optional[datetime] = None
    note: Optional[str] = Field(default=None, max_length=500)


class AttendanceOut(ORMModel):
    id: uuid.UUID
    employee_id: uuid.UUID
    employee_name: Optional[str] = None
    check_in: datetime
    check_out: Optional[datetime] = None
    worked_hours: Optional[Decimal] = None
    overtime_hours: Optional[Decimal] = None
    status: AttendanceStatus
    is_manual_edit: bool
    audit_notes: Optional[str] = None
    created_at: datetime


class PunchResponse(BaseModel):
    action: str  # CHECK_IN | CHECK_OUT
    attendance: AttendanceOut
    elapsed_hours: Optional[Decimal] = None


class AttendanceManualUpsert(BaseModel):
    employee_id: uuid.UUID
    check_in: datetime
    check_out: Optional[datetime] = None
    status: Optional[AttendanceStatus] = None
    audit_notes: Optional[str] = Field(
        default=None, description="Why this record was edited by hand."
    )

    @model_validator(mode="after")
    def _check(self) -> "AttendanceManualUpsert":
        if self.check_out and self.check_out < self.check_in:
            raise ValueError("check_out cannot precede check_in")
        return self


class AttendanceSummaryOut(BaseModel):
    employee_id: str
    employee_name: str
    date_start: date
    date_end: date
    worked_days: Decimal
    expected_days: Decimal
    expected_hours: Decimal
    total_worked_hours: Decimal
    total_overtime_hours: Decimal
    leave_days: Decimal
    absent_days: Decimal
    late_punches: int
    half_day_count: int
    present_punches: int


# ===========================================================================
# TIME OFF
# ===========================================================================
class TimeOffTypeCreate(BaseModel):
    name: str = Field(min_length=1, max_length=50)
    unit: str = Field(default="DAYS", pattern="^(DAYS|HOURS)$")
    requires_allocation: bool = True
    approval_level: str = Field(default="MANAGER", pattern="^(MANAGER|HR_OFFICER|NONE)$")
    display_color: str = Field(default="#017E84", max_length=20)
    work_entry_type: Optional[str] = Field(default=None, max_length=50)
    notes: Optional[str] = None


class TimeOffTypeUpdate(BaseModel):
    name: Optional[str] = Field(default=None, min_length=1, max_length=50)
    unit: Optional[str] = Field(default=None, pattern="^(DAYS|HOURS)$")
    requires_allocation: Optional[bool] = None
    approval_level: Optional[str] = Field(
        default=None, pattern="^(MANAGER|HR_OFFICER|NONE)$"
    )
    display_color: Optional[str] = Field(default=None, max_length=20)
    work_entry_type: Optional[str] = Field(default=None, max_length=50)
    notes: Optional[str] = None
    is_active: Optional[bool] = None


class TimeOffTypeOut(ORMModel):
    id: uuid.UUID
    name: str
    unit: str
    requires_allocation: bool
    approval_level: str
    display_color: str
    work_entry_type: Optional[str] = None
    notes: Optional[str] = None
    is_active: bool


class AllocationCreate(BaseModel):
    employee_id: uuid.UUID
    timeoff_type_id: uuid.UUID
    allocated_days: Decimal = Field(ge=0, max_digits=5, decimal_places=2)
    validity_year: Optional[int] = Field(default=None, ge=2000, le=2100)
    validity_label: Optional[str] = Field(default=None, max_length=60)
    description: Optional[str] = None
    status: ApprovalStatus = ApprovalStatus.TO_APPROVE


class AllocationStatusUpdate(BaseModel):
    status: ApprovalStatus


class AllocationUpdate(BaseModel):
    allocated_days: Optional[Decimal] = Field(
        default=None, ge=0, max_digits=5, decimal_places=2
    )
    validity_year: Optional[int] = Field(default=None, ge=2000, le=2100)
    validity_label: Optional[str] = Field(default=None, max_length=60)
    description: Optional[str] = None


class LeaveRequestUpdate(BaseModel):
    """Only a TO_APPROVE request may be amended."""

    timeoff_type_id: Optional[uuid.UUID] = None
    start_date: Optional[date] = None
    end_date: Optional[date] = None
    duration_days: Optional[Decimal] = Field(default=None, gt=0)
    reason: Optional[str] = None


class AllocationOut(ORMModel):
    id: uuid.UUID
    employee_id: uuid.UUID
    employee_name: Optional[str] = None
    timeoff_type_id: uuid.UUID
    timeoff_type_name: Optional[str] = None
    allocated_days: Decimal
    taken_days: Decimal
    remaining_days: Optional[Decimal] = None
    validity_year: int
    validity_label: Optional[str] = None
    status: ApprovalStatus
    description: Optional[str] = None
    created_at: datetime


class LeaveBalanceOut(BaseModel):
    allocation_id: uuid.UUID
    timeoff_type_id: uuid.UUID
    timeoff_type_name: str
    display_color: str
    unit: str
    allocated_days: Decimal
    taken_days: Decimal
    remaining_days: Decimal
    validity_year: int


class LeaveRequestCreate(BaseModel):
    timeoff_type_id: uuid.UUID
    start_date: date
    end_date: date
    reason: Optional[str] = None
    employee_id: Optional[uuid.UUID] = Field(
        default=None, description="HR only. Employees always request for themselves."
    )
    duration_days: Optional[Decimal] = Field(
        default=None,
        gt=0,
        description="Override the schedule-derived duration (e.g. a half day).",
    )

    @model_validator(mode="after")
    def _check(self) -> "LeaveRequestCreate":
        if self.end_date < self.start_date:
            raise ValueError("end_date cannot precede start_date")
        return self


class LeaveRequestOut(ORMModel):
    id: uuid.UUID
    employee_id: uuid.UUID
    employee_name: Optional[str] = None
    timeoff_type_id: uuid.UUID
    timeoff_type_name: Optional[str] = None
    allocation_id: Optional[uuid.UUID] = None
    start_date: date
    end_date: date
    duration_days: Decimal
    reason: Optional[str] = None
    status: ApprovalStatus
    approver_employee_id: Optional[uuid.UUID] = None
    created_at: datetime


class LeaveDurationPreview(BaseModel):
    start_date: date
    end_date: date
    working_days: Decimal
    calendar_days: int


# These reference models declared later in the file; `from __future__ import
# annotations` defers evaluation, so the forward references are resolved here.
EmployeeDetailOut.model_rebuild()
ContractRevisionResult.model_rebuild()
ContractUpdateResult.model_rebuild()
