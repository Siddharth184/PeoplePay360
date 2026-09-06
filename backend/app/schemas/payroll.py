"""Salary structure, rule, payrun and payslip schemas."""

from __future__ import annotations

import uuid
from datetime import date, datetime
from decimal import Decimal
from typing import Any, Dict, List, Optional

from pydantic import BaseModel, Field, model_validator

from app.models.enums import (
    ComputationType,
    PayrunStatus,
    PayslipStatus,
    RuleCategory,
)
from app.schemas.common import ORMModel


# ===========================================================================
# SALARY STRUCTURES & RULES
# ===========================================================================
class SalaryRuleCreate(BaseModel):
    name: str = Field(min_length=1, max_length=100)
    code: str = Field(min_length=1, max_length=30, pattern="^[A-Z0-9_]+$")
    sequence: int = Field(default=10, ge=0, le=10_000)
    category: RuleCategory
    computation_type: ComputationType
    fixed_amount: Optional[Decimal] = Field(default=None, max_digits=12, decimal_places=2)
    percentage_base: Optional[str] = Field(default=None, pattern="^(WAGE|BASIC|GROSS)$")
    percentage_rate: Optional[Decimal] = Field(
        default=None, ge=0, le=Decimal("999.99"), max_digits=5, decimal_places=2
    )
    python_code: Optional[str] = Field(default=None, max_length=4000)
    quantity: Decimal = Field(
        default=Decimal("1.00"),
        ge=0,
        max_digits=8,
        decimal_places=2,
        description="Multiplier on the computed amount (Odoo's rule Quantity).",
    )
    is_active: bool = True

    @model_validator(mode="after")
    def _inputs_match_type(self) -> "SalaryRuleCreate":
        if self.computation_type == ComputationType.FIXED:
            if self.fixed_amount is None:
                raise ValueError("fixed_amount is required for FIXED rules")
        elif self.computation_type == ComputationType.PERCENTAGE:
            if self.percentage_base is None or self.percentage_rate is None:
                raise ValueError(
                    "percentage_base and percentage_rate are required for PERCENTAGE rules"
                )
        elif self.computation_type == ComputationType.PYTHON_CODE:
            if not (self.python_code or "").strip():
                raise ValueError("python_code is required for PYTHON_CODE rules")
        return self


class SalaryRuleUpdate(BaseModel):
    name: Optional[str] = Field(default=None, min_length=1, max_length=100)
    code: Optional[str] = Field(default=None, min_length=1, max_length=30, pattern="^[A-Z0-9_]+$")
    sequence: Optional[int] = Field(default=None, ge=0, le=10_000)
    category: Optional[RuleCategory] = None
    computation_type: Optional[ComputationType] = None
    fixed_amount: Optional[Decimal] = None
    percentage_base: Optional[str] = Field(default=None, pattern="^(WAGE|BASIC|GROSS)$")
    percentage_rate: Optional[Decimal] = None
    python_code: Optional[str] = Field(default=None, max_length=4000)
    quantity: Optional[Decimal] = Field(default=None, ge=0, max_digits=8, decimal_places=2)
    is_active: Optional[bool] = None



class SalaryRuleOut(ORMModel):
    id: uuid.UUID
    salary_structure_id: uuid.UUID
    name: str
    code: str
    sequence: int
    category: RuleCategory
    computation_type: ComputationType
    fixed_amount: Optional[Decimal] = None
    percentage_base: Optional[str] = None
    percentage_rate: Optional[Decimal] = None
    python_code: Optional[str] = None
    quantity: Decimal = Decimal("1.00")
    is_active: bool
    created_at: datetime


class SalaryStructureCreate(BaseModel):
    name: str = Field(min_length=1, max_length=100)
    code: str = Field(min_length=1, max_length=50, pattern="^[A-Z0-9_]+$")
    notes: Optional[str] = None
    rules: List[SalaryRuleCreate] = Field(default_factory=list)


class SalaryStructureUpdate(BaseModel):
    name: Optional[str] = Field(default=None, min_length=1, max_length=100)
    code: Optional[str] = Field(
        default=None, min_length=1, max_length=50, pattern="^[A-Z0-9_]+$"
    )
    notes: Optional[str] = None
    is_active: Optional[bool] = None


class SalaryStructureOut(ORMModel):
    id: uuid.UUID
    name: str
    code: str
    is_active: bool
    notes: Optional[str] = None
    created_at: datetime
    rules: List[SalaryRuleOut] = Field(default_factory=list)

    # Populated by the list endpoint for the mockup's
    # "Regular Salary | 12 rules | 42 employees | Active" row.
    rule_count: int = 0
    active_rule_count: int = 0
    employee_count: int = 0


class RuleSimulationRequest(BaseModel):
    """Dry-run a whole structure against a hypothetical wage before using it live."""

    salary_structure_id: uuid.UUID
    wage_monthly: Decimal = Field(gt=0, max_digits=12, decimal_places=2)
    worked_days: Decimal = Field(default=Decimal("22"), ge=0)
    expected_days: Decimal = Field(default=Decimal("22"), ge=0)


class RuleSimulationLine(BaseModel):
    rule_name: str
    rule_code: str
    category: RuleCategory
    sequence: int
    amount: Decimal
    computation_type: ComputationType
    explanation: str


class RuleSimulationResponse(BaseModel):
    salary_structure_id: uuid.UUID
    salary_structure_name: str
    wage_monthly: Decimal
    basic: Decimal
    allowances: Decimal
    gross: Decimal
    deductions: Decimal
    net: Decimal
    lines: List[RuleSimulationLine]


class PythonRuleValidationRequest(BaseModel):
    python_code: str = Field(min_length=1, max_length=4000)


class PythonRuleValidationResponse(BaseModel):
    valid: bool
    message: str
    probe_result: Optional[Decimal] = None


# ===========================================================================
# PAYRUN: STEP 1 (validate scope)
# ===========================================================================
class PayrunScopeRequest(BaseModel):
    salary_structure_id: uuid.UUID
    date_start: date
    date_end: date
    department_ids: Optional[List[uuid.UUID]] = None
    employee_ids: Optional[List[uuid.UUID]] = None

    @model_validator(mode="after")
    def _check(self) -> "PayrunScopeRequest":
        if self.date_end < self.date_start:
            raise ValueError("date_end cannot precede date_start")
        return self


class PayrunCandidateOut(BaseModel):
    employee_id: uuid.UUID
    badge_id: str
    name: str
    department: Optional[str] = None
    job_position: Optional[str] = None
    contract_reference: Optional[str] = None
    wage_monthly: Decimal
    worked_days: Decimal
    expected_days: Decimal
    eligible: bool
    blocking_issues: List[str] = Field(default_factory=list)
    warnings: List[str] = Field(default_factory=list)


class PayrunScopeResponse(BaseModel):
    salary_structure_id: uuid.UUID
    salary_structure_name: str
    date_start: date
    date_end: date
    candidate_count: int
    eligible_count: int
    blocked_count: int
    warning_count: int
    projected_wage_total: Decimal
    candidates: List[PayrunCandidateOut]


# ===========================================================================
# PAYRUN: STEP 2 (create batch)
# ===========================================================================
class PayrunCreate(BaseModel):
    name: str = Field(min_length=1, max_length=100)
    salary_structure_id: uuid.UUID
    date_start: date
    date_end: date
    employee_ids: List[uuid.UUID] = Field(min_length=1)
    skip_blocked: bool = Field(
        default=False,
        description=(
            "When false (default) a blocking anomaly aborts the whole batch. "
            "When true the eligible subset is generated and the rest reported."
        ),
    )

    @model_validator(mode="after")
    def _check(self) -> "PayrunCreate":
        if self.date_end < self.date_start:
            raise ValueError("date_end cannot precede date_start")
        return self


class PayrunOut(ORMModel):
    id: uuid.UUID
    reference_code: str
    name: str
    salary_structure_id: uuid.UUID
    salary_structure_name: Optional[str] = None
    date_start: date
    date_end: date
    status: PayrunStatus
    total_basic: Optional[Decimal] = None
    total_gross: Optional[Decimal] = None
    total_net: Optional[Decimal] = None
    employee_count: Optional[int] = None
    warnings_count: Optional[int] = None
    created_at: datetime


class PayslipLineOut(ORMModel):
    id: uuid.UUID
    salary_rule_id: uuid.UUID
    rule_name: str
    rule_code: str
    category: RuleCategory
    sequence: int
    amount: Decimal


class PayslipOut(ORMModel):
    id: uuid.UUID
    reference_code: str
    payrun_id: uuid.UUID
    employee_id: uuid.UUID
    employee_name: Optional[str] = None
    badge_id: Optional[str] = None
    contract_id: uuid.UUID
    salary_structure_id: uuid.UUID
    date_start: date
    date_end: date
    worked_days: Decimal
    worked_hours: Decimal = Decimal("0.00")
    overtime_hours: Decimal = Decimal("0.00")
    scheduled_hours: Decimal = Decimal("0.00")
    overtime_pay: Decimal = Decimal("0.00")
    basic_amount: Decimal

    gross_amount: Decimal
    net_amount: Decimal
    status: PayslipStatus
    warning_notes: Optional[str] = None
    emailed_at: Optional[datetime] = None
    created_at: datetime


class LeaveImpactOut(BaseModel):
    """The Time / Leave Impact block on the payslip.

    Every figure is derived from real attendance + approved-leave data for the
    payslip period; the deduction figure is the amount the configured Loss-of-Pay
    salary rule produced, so it always ties out to the payslip lines.
    """

    worked_days: Decimal = Decimal("0.00")
    expected_days: Decimal = Decimal("0.00")
    approved_leave_days: Decimal = Decimal("0.00")
    paid_leave_days: Decimal = Decimal("0.00")
    unpaid_leave_days: Decimal = Decimal("0.00")
    absent_days: Decimal = Decimal("0.00")
    # The loss-of-pay salary-line amount attributable to unpaid leave (>= 0).
    unpaid_leave_deduction: Decimal = Decimal("0.00")


class PayslipDetailOut(PayslipOut):
    """Payslip detail with the rule-by-rule tree the UI renders."""

    payrun_reference: Optional[str] = None
    payrun_name: Optional[str] = None
    contract_reference: Optional[str] = None
    salary_structure_name: Optional[str] = None
    department: Optional[str] = None
    job_position: Optional[str] = None
    total_deductions: Decimal = Decimal("0.00")
    lines: List[PayslipLineOut] = Field(default_factory=list)
    grouped_lines: Dict[str, List[PayslipLineOut]] = Field(default_factory=dict)
    leave_impact: Optional[LeaveImpactOut] = None


class PayrunDetailOut(BaseModel):
    payrun: PayrunOut
    payslips: List[PayslipOut]


class SendPayslipsResponse(BaseModel):
    payrun_reference: str
    mode: str
    smtp_host: Optional[str] = None
    candidates: int
    sent_count: int
    failed_count: int
    sent: List[str]
    failed: List[Dict[str, Any]]
    note: Optional[str] = None


# ===========================================================================
# DASHBOARD
# ===========================================================================
class DepartmentCostOut(BaseModel):
    department: str
    headcount: int
    total_basic: Decimal
    total_gross: Decimal
    total_net: Decimal
    share_of_gross_pct: float


class PayrollTrendPointOut(BaseModel):
    reference_code: str
    period: str
    date_start: date
    date_end: date
    status: str
    payslip_count: int
    total_basic: Decimal
    total_gross: Decimal
    total_net: Decimal


class PayslipStatusSplitOut(BaseModel):
    paid: int
    done: int
    draft: int
    with_warnings: int
    total: int


class PayrollAlertOut(BaseModel):
    severity: str  # CRITICAL | WARNING | INFO
    kind: str
    count: int
    message: str


class AttendanceOverviewOut(BaseModel):
    total_records: int
    present: int
    late: int
    absent: int
    half_day: int
    missing_check_outs: int
    manual_attendance_edits: int
    total_worked_hours: Decimal
    total_overtime_hours: Decimal
    records_with_overtime: int
    employees_with_records: int
    coverage_pct: float


class TimeOffOverviewOut(BaseModel):
    timeoff_type: str
    unit: str
    approved_days: Decimal
    pending_requests: int
    # None for types that require no allocation; the UI shows "N/A".
    remaining_balance: Optional[Decimal] = None
    tracks_balance: bool


class DepartmentOverviewOut(BaseModel):
    department: str
    headcount: int
    total_employees: int
    monthly_wage_bill: Decimal


class DashboardPeriodOut(BaseModel):
    payrun_id: str
    reference_code: str
    name: str
    date_start: date
    date_end: date
    status: str


class DashboardFilterOptionsOut(BaseModel):
    departments: List[Dict[str, str]]
    employee_types: List[str]
    companies: List[str]
    periods: List[DashboardPeriodOut]


class DashboardAppliedFiltersOut(BaseModel):
    date_start: Optional[date] = None
    date_end: Optional[date] = None
    department_id: Optional[uuid.UUID] = None
    employee_type: Optional[str] = None
    company_name: Optional[str] = None
    payrun_id: Optional[uuid.UUID] = None


class DashboardMetricsOut(BaseModel):
    generated_at: date
    filters: DashboardAppliedFiltersOut
    kpi: Dict[str, Any]
    department_costs: List[DepartmentCostOut]
    payroll_trend: List[PayrollTrendPointOut]
    payslip_status: PayslipStatusSplitOut
    alerts: List[PayrollAlertOut]
    attendance_overview: AttendanceOverviewOut
    timeoff_overview: List[TimeOffOverviewOut]
    department_overview: List[DepartmentOverviewOut]


class PayrollAssignmentOut(BaseModel):
    employee_id: uuid.UUID
    badge_id: str
    employee_name: str
    department_id: Optional[uuid.UUID] = None
    department_name: Optional[str] = None
    job_position_id: Optional[uuid.UUID] = None
    job_position_name: Optional[str] = None
    contract_id: Optional[uuid.UUID] = None
    contract_reference: Optional[str] = None
    contract_status: Optional[str] = None
    wage_monthly: Optional[Decimal] = None
    salary_structure_id: Optional[uuid.UUID] = None
    salary_structure_name: Optional[str] = None
    date_start: Optional[date] = None
    date_end: Optional[date] = None

