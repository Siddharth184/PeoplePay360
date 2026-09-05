"""Payrun 2-Step Workflow & Pre-Flight Anomaly Detection (section 3.5).

Step 1 (`validate_payrun_scope`) is a **read-only dry run**: it resolves who is
eligible for the period, runs every anomaly check and returns the findings. It
writes nothing, so an operator can iterate on scope without leaving junk records.

Step 2 (`create_payrun_batch`) creates the Payrun and generates payslips for the
explicitly selected employees only.

Then the guarded state machine: DRAFT -> COMPUTED -> VALIDATED -> PAID.
"""

from __future__ import annotations

import uuid
from datetime import date
from typing import Any, Dict, List, Sequence

from sqlalchemy import func, select
from sqlalchemy.orm import Session, selectinload

from app.core.errors import ConflictError, NotFoundError, ValidationError
from app.models.contract import HrContract
from app.models.employee import Employee
from app.models.payrun import Payrun, Payslip, PayslipLine
from app.models.salary import SalaryRule, SalaryStructure
from app.services.attendance_service import compute_worked_days_and_hours
from app.services.contract_service import (
    find_overlapping_contracts,
    find_payable_contracts,
)
from app.services.reference import next_payrun_reference, next_payslip_reference
from app.services.salary_engine import ZERO, execute_salary_computation, money, to_decimal

# Contracts ending within this horizon are flagged so payroll can chase renewals.
CONTRACT_EXPIRY_WARNING_DAYS = 45


# ---------------------------------------------------------------------------
# SHARED HELPERS
# ---------------------------------------------------------------------------
def get_structure(db: Session, structure_id: uuid.UUID | str) -> SalaryStructure:
    structure = db.get(SalaryStructure, structure_id)
    if not structure:
        raise NotFoundError(f"Salary structure {structure_id} not found.")
    if not structure.is_active:
        raise ValidationError(f"Salary structure '{structure.name}' is inactive.")
    return structure


def get_active_rules(db: Session, structure_id: uuid.UUID | str) -> List[SalaryRule]:
    rules = (
        db.execute(
            select(SalaryRule)
            .where(
                SalaryRule.salary_structure_id == structure_id,
                SalaryRule.is_active.is_(True),
            )
            .order_by(SalaryRule.sequence.asc(), SalaryRule.code.asc())
        )
        .scalars()
        .all()
    )
    if not rules:
        raise ValidationError(
            "This salary structure has no active salary rules; nothing to compute."
        )
    return list(rules)


def get_payrun(db: Session, payrun_id: uuid.UUID | str) -> Payrun:
    payrun = db.get(Payrun, payrun_id)
    if not payrun:
        raise NotFoundError(f"Payrun {payrun_id} not found.")
    return payrun


def _already_paid_employee_ids(
    db: Session, date_start: date, date_end: date, *, exclude_payrun: uuid.UUID | None = None
) -> Dict[uuid.UUID, str]:
    """Employees who already have a payslip covering an overlapping period.

    This is the duplicate-payment guard: the UNIQUE(payrun_id, employee_id)
    constraint only stops duplicates *within* one payrun.
    """
    stmt = (
        select(Payslip.employee_id, Payrun.reference_code)
        .join(Payrun, Payrun.id == Payslip.payrun_id)
        .where(Payslip.date_start <= date_end, Payslip.date_end >= date_start)
    )
    if exclude_payrun is not None:
        stmt = stmt.where(Payslip.payrun_id != exclude_payrun)
    return {row[0]: row[1] for row in db.execute(stmt).all()}


def _anomalies_for(
    db: Session,
    employee: Employee,
    date_start: date,
    date_end: date,
    duplicates: Dict[uuid.UUID, str],
    structure_id: uuid.UUID | str | None = None,
) -> Dict[str, Any]:
    """Every pre-flight check for one employee. Blocking vs. advisory is explicit."""
    blocking: List[str] = []
    warnings: List[str] = []
    contract: HrContract | None = None

    # --- Contract resolution (blocking) ------------------------------------
    # Payable, not merely RUNNING: a contract that ended inside the period was
    # still the contract in force then, and must be resolvable for back pay and
    # final settlements.
    contracts = find_payable_contracts(db, employee.id, date_start, date_end)
    if not contracts:
        draft_or_cancelled = find_overlapping_contracts(
            db,
            employee.id,
            date_start,
            date_end,
            statuses=("DRAFT", "CANCELLED"),
        )
        if draft_or_cancelled:
            states = ", ".join(
                f"{c.reference_code} ({c.status})" for c in draft_or_cancelled
            )
            blocking.append(
                f"No payable contract covering {date_start} to {date_end}. Found "
                f"{states}; activate the contract before running payroll."
            )
        else:
            blocking.append(
                f"No active RUNNING contract covering {date_start} to {date_end}."
            )
    elif len(contracts) > 1:
        wages = {to_decimal(c.wage_monthly) for c in contracts}
        detail = ", ".join(
            f"{c.reference_code} ({c.status}, {c.start_date} to "
            f"{c.end_date or 'ongoing'} at {c.wage_monthly})"
            for c in contracts
        )
        reason = (
            "the wage changed inside this period"
            if len(wages) > 1
            else "the contract changed inside this period"
        )
        blocking.append(
            f"{len(contracts)} contracts govern this period because {reason}: "
            f"{detail}. Split the payrun at the changeover date so each run covers "
            "one contract."
        )
    else:
        contract = contracts[0]
        if to_decimal(contract.wage_monthly) <= ZERO:
            blocking.append(
                f"Contract {contract.reference_code} has a zero or negative wage."
            )
        # --- Contract expiry (advisory) ------------------------------------
        if contract.end_date is not None:
            days_left = (contract.end_date - date_end).days
            if contract.end_date <= date_end:
                warnings.append(
                    f"Contract {contract.reference_code} expires inside this period "
                    f"({contract.end_date})."
                )
            elif days_left <= CONTRACT_EXPIRY_WARNING_DAYS:
                warnings.append(
                    f"Contract {contract.reference_code} expires in {days_left} days."
                )

    # --- Contract ending inside the period (advisory) ----------------------
    # The single resolved contract stops partway through the run, so this payslip
    # covers only part of the period. Not an error (it is exactly what a leaver's
    # final payslip looks like), but the operator should know.
    if contract is not None and contract.end_date and contract.end_date < date_end:
        warnings.append(
            f"Contract {contract.reference_code} ends {contract.end_date}, before the "
            f"period end {date_end}. This payslip covers only part of the period."
        )
    if contract is not None and contract.start_date > date_start:
        warnings.append(
            f"Contract {contract.reference_code} starts {contract.start_date}, after "
            f"the period start {date_start}. This payslip covers only part of the "
            "period."
        )

    # --- Contract structure mismatch (advisory) ---------------------------
    if contract is not None and contract.salary_structure_id is not None:
        if str(contract.salary_structure_id) != str(structure_id):
            warnings.append(
                "This payrun's salary structure differs from the one named on "
                f"contract {contract.reference_code}."
            )

    # --- Duplicate payslip (blocking) -------------------------------------
    if employee.id in duplicates:
        blocking.append(
            f"A payslip already exists for this period in payrun {duplicates[employee.id]}."
        )

    # --- Employment status (blocking) -------------------------------------
    if employee.status == "TERMINATED":
        blocking.append("Employee is TERMINATED.")
    elif employee.status == "INACTIVE":
        warnings.append("Employee is INACTIVE.")

    # --- Payment details (advisory: payroll may still compute) -------------
    if not employee.has_bank_details:
        warnings.append("Missing Bank Details")
    if not employee.pan_or_ssn:
        warnings.append("Missing PAN / SSN (statutory reporting will be incomplete).")
    if not employee.working_schedule_id:
        warnings.append("No working schedule assigned; proration uses a Mon-Fri default.")

    # --- Attendance sanity (advisory) -------------------------------------
    attendance = compute_worked_days_and_hours(
        db, employee.id, date_start, date_end, employee.working_schedule_id
    )
    if attendance["expected_days"] and attendance["worked_days"] == ZERO:
        warnings.append("Zero attendance recorded for the whole period.")
    if attendance["absent_days"] > ZERO:
        warnings.append(
            f"{attendance['absent_days']} unexplained absent day(s) in the period."
        )

    return {
        "employee": employee,
        "contract": contract,
        "attendance": attendance,
        "blocking": blocking,
        "warnings": warnings,
        "eligible": not blocking,
    }


# ---------------------------------------------------------------------------
# STEP 1: READ-ONLY SCOPE VALIDATION
# ---------------------------------------------------------------------------
def validate_payrun_scope(
    db: Session,
    *,
    structure_id: uuid.UUID | str,
    date_start: date,
    date_end: date,
    department_ids: Sequence[uuid.UUID | str] | None = None,
    employee_ids: Sequence[uuid.UUID | str] | None = None,
) -> Dict[str, Any]:
    """Step 1 of the wizard. Creates NOTHING; returns eligibility + anomalies."""
    if date_end < date_start:
        raise ValidationError("date_end cannot precede date_start.")

    structure = get_structure(db, structure_id)
    get_active_rules(db, structure.id)  # fail early if the structure is unusable

    stmt = select(Employee).options(
        selectinload(Employee.department), selectinload(Employee.job_position)
    )
    if employee_ids:
        stmt = stmt.where(Employee.id.in_(list(employee_ids)))
    else:
        stmt = stmt.where(Employee.status != "TERMINATED")
        if department_ids:
            stmt = stmt.where(Employee.department_id.in_(list(department_ids)))
    employees = db.execute(stmt.order_by(Employee.badge_id)).scalars().all()

    duplicates = _already_paid_employee_ids(db, date_start, date_end)

    candidates: List[Dict[str, Any]] = []
    projected_total = ZERO
    for employee in employees:
        finding = _anomalies_for(
            db, employee, date_start, date_end, duplicates, structure.id
        )
        wage = (
            to_decimal(finding["contract"].wage_monthly) if finding["contract"] else ZERO
        )
        projected_total += wage if finding["eligible"] else ZERO
        candidates.append(
            {
                "employee_id": employee.id,
                "badge_id": employee.badge_id,
                "name": employee.name,
                "department": employee.department.name if employee.department else None,
                "job_position": (
                    employee.job_position.name if employee.job_position else None
                ),
                "contract_reference": (
                    finding["contract"].reference_code if finding["contract"] else None
                ),
                "wage_monthly": wage,
                "worked_days": finding["attendance"]["worked_days"],
                "expected_days": finding["attendance"]["expected_days"],
                "eligible": finding["eligible"],
                "blocking_issues": finding["blocking"],
                "warnings": finding["warnings"],
            }
        )

    eligible = [c for c in candidates if c["eligible"]]
    return {
        "salary_structure_id": structure.id,
        "salary_structure_name": structure.name,
        "date_start": date_start,
        "date_end": date_end,
        "candidate_count": len(candidates),
        "eligible_count": len(eligible),
        "blocked_count": len(candidates) - len(eligible),
        "warning_count": sum(len(c["warnings"]) for c in candidates),
        "projected_wage_total": money(projected_total),
        "candidates": candidates,
    }


# ---------------------------------------------------------------------------
# STEP 2: CREATE THE BATCH
# ---------------------------------------------------------------------------
def create_payrun_batch(
    db: Session,
    *,
    name: str,
    structure_id: uuid.UUID | str,
    date_start: date,
    date_end: date,
    selected_employee_ids: Sequence[uuid.UUID | str],
    user_id: uuid.UUID | str | None,
    skip_blocked: bool = False,
) -> Payrun:
    """Step 2: create the Payrun and one payslip per explicitly selected employee.

    By default a blocking anomaly aborts the whole batch (all-or-nothing, so the
    operator sees the problem instead of a silently short batch). Pass
    `skip_blocked=True` to generate for the eligible subset and report the rest.
    """
    if date_end < date_start:
        raise ValidationError("date_end cannot precede date_start.")
    if not selected_employee_ids:
        raise ValidationError("Select at least one employee for this payrun.")

    structure = get_structure(db, structure_id)
    rules = get_active_rules(db, structure.id)

    unique_ids = list(dict.fromkeys(str(e) for e in selected_employee_ids))
    employees = (
        db.execute(select(Employee).where(Employee.id.in_(unique_ids)))
        .scalars()
        .all()
    )
    found = {str(e.id) for e in employees}
    missing = [eid for eid in unique_ids if eid not in found]
    if missing:
        raise NotFoundError(f"Unknown employee id(s): {', '.join(missing)}")

    duplicates = _already_paid_employee_ids(db, date_start, date_end)
    findings = [
        _anomalies_for(db, emp, date_start, date_end, duplicates, structure.id)
        for emp in employees
    ]

    blocked = [f for f in findings if not f["eligible"]]
    if blocked and not skip_blocked:
        detail = {
            f["employee"].badge_id: f["blocking"] for f in blocked
        }
        raise ConflictError(
            f"{len(blocked)} selected employee(s) cannot be paid for this period. "
            "Resolve the issues or resubmit with skip_blocked=true.",
            details=detail,
        )

    payable = [f for f in findings if f["eligible"]]
    if not payable:
        raise ValidationError(
            "None of the selected employees are eligible for this period."
        )

    payrun = Payrun(
        reference_code=next_payrun_reference(db, date_start),
        name=name,
        salary_structure_id=structure.id,
        date_start=date_start,
        date_end=date_end,
        status="DRAFT",
        employee_count=0,
        created_by_user_id=user_id,
    )
    db.add(payrun)
    db.flush()

    total_basic = total_gross = total_net = ZERO
    warnings_total = 0

    for finding in payable:
        employee: Employee = finding["employee"]
        contract: HrContract = finding["contract"]
        attendance = finding["attendance"]
        warning_notes: List[str] = list(finding["warnings"])

        computation = execute_salary_computation(
            contract,
            attendance["worked_days"],
            rules,
            attendance=attendance,
            employee=employee,
        )

        payslip = Payslip(
            reference_code=next_payslip_reference(db, date_start),
            payrun_id=payrun.id,
            employee_id=employee.id,
            contract_id=contract.id,
            salary_structure_id=structure.id,
            date_start=date_start,
            date_end=date_end,
            worked_days=attendance["worked_days"],
            basic_amount=computation["basic"],
            gross_amount=computation["gross"],
            net_amount=computation["net"],
            status="DRAFT",
            warning_notes="; ".join(warning_notes) if warning_notes else None,
        )
        db.add(payslip)
        db.flush()

        for line in computation["lines"]:
            db.add(PayslipLine(payslip_id=payslip.id, **line))

        total_basic += computation["basic"]
        total_gross += computation["gross"]
        total_net += computation["net"]
        warnings_total += len(warning_notes)

    payrun.employee_count = len(payable)
    payrun.total_basic = money(total_basic)
    payrun.total_gross = money(total_gross)
    payrun.total_net = money(total_net)
    payrun.warnings_count = warnings_total

    db.commit()
    db.refresh(payrun)
    return payrun


# ---------------------------------------------------------------------------
# COMPUTE / VALIDATE / PAY
# ---------------------------------------------------------------------------
def compute_payrun(db: Session, payrun_id: uuid.UUID | str) -> Payrun:
    """Recompute every DRAFT payslip through the salary engine (idempotent)."""
    payrun = get_payrun(db, payrun_id)
    if payrun.status not in ("DRAFT", "COMPUTED"):
        raise ConflictError(
            f"Payrun {payrun.reference_code} is {payrun.status}; it can no longer be computed."
        )

    rules = get_active_rules(db, payrun.salary_structure_id)
    payslips = (
        db.execute(
            select(Payslip)
            .where(Payslip.payrun_id == payrun.id, Payslip.status == "DRAFT")
            .options(selectinload(Payslip.lines))
        )
        .scalars()
        .all()
    )

    total_basic = total_gross = total_net = ZERO
    warnings_total = 0

    for payslip in payslips:
        employee = db.get(Employee, payslip.employee_id)
        contract = db.get(HrContract, payslip.contract_id)
        attendance = compute_worked_days_and_hours(
            db,
            payslip.employee_id,
            payslip.date_start,
            payslip.date_end,
            employee.working_schedule_id if employee else None,
        )
        computation = execute_salary_computation(
            contract, attendance["worked_days"], rules, attendance=attendance, employee=employee
        )

        # Replace lines wholesale: a rule may have been deleted since last compute.
        for line in list(payslip.lines):
            db.delete(line)
        db.flush()
        for line in computation["lines"]:
            db.add(PayslipLine(payslip_id=payslip.id, **line))

        payslip.worked_days = attendance["worked_days"]
        payslip.basic_amount = computation["basic"]
        payslip.gross_amount = computation["gross"]
        payslip.net_amount = computation["net"]

        total_basic += computation["basic"]
        total_gross += computation["gross"]
        total_net += computation["net"]
        if payslip.warning_notes:
            warnings_total += len(payslip.warning_notes.split(";"))

    # Payslips already DONE/PAID keep contributing to the batch totals.
    settled = db.execute(
        select(
            func.coalesce(func.sum(Payslip.basic_amount), 0),
            func.coalesce(func.sum(Payslip.gross_amount), 0),
            func.coalesce(func.sum(Payslip.net_amount), 0),
            func.count(Payslip.id),
        ).where(Payslip.payrun_id == payrun.id, Payslip.status != "DRAFT")
    ).one()

    payrun.total_basic = money(total_basic + to_decimal(settled[0]))
    payrun.total_gross = money(total_gross + to_decimal(settled[1]))
    payrun.total_net = money(total_net + to_decimal(settled[2]))
    payrun.employee_count = len(payslips) + int(settled[3])
    payrun.warnings_count = warnings_total
    payrun.status = "COMPUTED"

    db.commit()
    db.refresh(payrun)
    return payrun


def validate_payrun(db: Session, payrun_id: uuid.UUID | str) -> Payrun:
    """Lock the batch for payout. Refuses while blocking anomalies remain."""
    payrun = get_payrun(db, payrun_id)
    if payrun.status == "DRAFT":
        raise ConflictError(
            f"Payrun {payrun.reference_code} must be computed before validation."
        )
    if payrun.status != "COMPUTED":
        raise ConflictError(
            f"Payrun {payrun.reference_code} is {payrun.status}; it cannot be validated."
        )

    payslips = (
        db.execute(select(Payslip).where(Payslip.payrun_id == payrun.id)).scalars().all()
    )
    if not payslips:
        raise ValidationError("This payrun has no payslips to validate.")

    negatives = [p.reference_code for p in payslips if to_decimal(p.net_amount) < ZERO]
    if negatives:
        raise ConflictError(
            "Refusing to validate: negative net pay on payslip(s) "
            f"{', '.join(negatives)}."
        )

    for payslip in payslips:
        if payslip.status == "DRAFT":
            payslip.status = "DONE"

    payrun.status = "VALIDATED"
    db.commit()
    db.refresh(payrun)
    return payrun


def mark_payrun_paid(db: Session, payrun_id: uuid.UUID | str) -> Payrun:
    payrun = get_payrun(db, payrun_id)
    if payrun.status != "VALIDATED":
        raise ConflictError(
            f"Payrun {payrun.reference_code} must be VALIDATED before it is marked paid."
        )

    payslips = (
        db.execute(select(Payslip).where(Payslip.payrun_id == payrun.id)).scalars().all()
    )
    missing_bank = [
        p.reference_code
        for p in payslips
        if (emp := db.get(Employee, p.employee_id)) and not emp.has_bank_details
    ]
    if missing_bank:
        raise ConflictError(
            "Cannot mark paid: bank details are missing for payslip(s) "
            f"{', '.join(missing_bank)}."
        )

    for payslip in payslips:
        payslip.status = "PAID"
    payrun.status = "PAID"
    db.commit()
    db.refresh(payrun)
    return payrun


def delete_payrun(db: Session, payrun_id: uuid.UUID | str) -> None:
    """Only DRAFT/COMPUTED batches may be deleted; paid history is immutable."""
    payrun = get_payrun(db, payrun_id)
    if payrun.status in ("VALIDATED", "PAID"):
        raise ConflictError(
            f"Payrun {payrun.reference_code} is {payrun.status} and cannot be deleted."
        )
    db.delete(payrun)
    db.commit()


def payrun_detail(db: Session, payrun_id: uuid.UUID | str) -> Dict[str, Any]:
    payrun = get_payrun(db, payrun_id)
    rows = db.execute(
        select(Payslip, Employee)
        .join(Employee, Employee.id == Payslip.employee_id)
        .where(Payslip.payrun_id == payrun.id)
        .order_by(Employee.badge_id)
    ).all()
    return {
        "payrun": payrun,
        "payslips": [
            {
                "payslip": payslip,
                "employee_name": employee.name,
                "badge_id": employee.badge_id,
            }
            for payslip, employee in rows
        ],
    }
