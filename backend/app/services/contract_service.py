"""Period-Based Active Contract Resolution Engine (architecture section 3.1).

Payroll for a period [date_start, date_end] must select the exact contract valid
for that period - not "the latest" contract, not "the first" contract. Zero or
multiple matches are both hard errors: guessing here silently mis-pays people.
"""

from __future__ import annotations

import uuid
from datetime import date, timedelta
from typing import Sequence

from sqlalchemy import or_, select
from sqlalchemy.orm import Session

from app.core.errors import ConflictError, NotFoundError, ValidationError
from app.models.contract import HrContract
from app.models.employee import Employee
from app.services.reference import next_contract_reference
from app.services.salary_engine import to_decimal


# Statuses that make a contract PAYABLE for a period it covers.
#
# `RUNNING` alone is not enough. RUNNING describes the contract today, not the
# period being paid. A contract that ended in March is still the contract that was
# in force during March, so March payroll must resolve it, otherwise a wage
# revision or a leaver makes past-period and final-settlement payroll impossible.
# DRAFT was never activated and CANCELLED was voided, so neither is ever payable.
PAYABLE_CONTRACT_STATUSES = ("RUNNING", "EXPIRED")

# The integrity guard is narrower: only two simultaneously RUNNING contracts are a
# data error. A superseded EXPIRED contract legitimately abuts a new RUNNING one.
ACTIVE_CONTRACT_STATUSES = ("RUNNING",)


def find_overlapping_contracts(
    db: Session,
    employee_id: uuid.UUID | str,
    date_start: date,
    date_end: date,
    *,
    statuses: Sequence[str] = ACTIVE_CONTRACT_STATUSES,
    exclude_id: uuid.UUID | str | None = None,
) -> Sequence[HrContract]:
    stmt = (
        select(HrContract)
        .where(
            HrContract.employee_id == employee_id,
            HrContract.status.in_(list(statuses)),
            HrContract.start_date <= date_end,
            or_(HrContract.end_date.is_(None), HrContract.end_date >= date_start),
        )
        .order_by(HrContract.start_date)
    )
    if exclude_id is not None:
        stmt = stmt.where(HrContract.id != exclude_id)
    return db.execute(stmt).scalars().all()


def find_payable_contracts(
    db: Session,
    employee_id: uuid.UUID | str,
    date_start: date,
    date_end: date,
) -> Sequence[HrContract]:
    """Contracts that were legitimately in force during any part of the period."""
    return find_overlapping_contracts(
        db, employee_id, date_start, date_end, statuses=PAYABLE_CONTRACT_STATUSES
    )


def resolve_applicable_contract(
    db: Session,
    employee_id: uuid.UUID | str,
    date_start: date,
    date_end: date,
) -> HrContract:
    """Return THE single contract that governs pay for this exact period.

    Raises ValidationError when none exist and ConflictError when several do.
    Two payable contracts inside one period means two different wages applied, and
    a single payslip cannot represent both, so the caller must split the payrun at
    the changeover date rather than have the engine guess.
    """
    contracts = find_payable_contracts(db, employee_id, date_start, date_end)

    if not contracts:
        raise ValidationError(
            f"No payable contract found for employee {employee_id} covering period "
            f"{date_start} to {date_end}. A contract must be RUNNING or EXPIRED and "
            "cover the period; DRAFT and CANCELLED contracts are never paid."
        )
    if len(contracts) > 1:
        detail = ", ".join(
            f"{c.reference_code} ({c.status}, {c.start_date} to "
            f"{c.end_date or 'ongoing'} at {c.wage_monthly})"
            for c in contracts
        )
        raise ConflictError(
            f"{len(contracts)} contracts govern part of {date_start} to {date_end} "
            f"for employee {employee_id}: {detail}. Split the payrun so each run "
            "covers a single contract period."
        )
    return contracts[0]


def get_contract(db: Session, contract_id: uuid.UUID | str) -> HrContract:
    contract = db.get(HrContract, contract_id)
    if not contract:
        raise NotFoundError(f"Contract {contract_id} not found.")
    return contract


def create_contract(
    db: Session,
    *,
    employee_id: uuid.UUID | str,
    start_date: date,
    wage_monthly,
    end_date: date | None = None,
    department_id: uuid.UUID | str | None = None,
    job_position_id: uuid.UUID | str | None = None,
    working_schedule_id: uuid.UUID | str | None = None,
    salary_structure_id: uuid.UUID | str | None = None,
    status: str = "DRAFT",
    notes: str | None = None,
    reference_code: str | None = None,
) -> HrContract:
    """Create a contract, defaulting the org fields from the employee record.

    The overlap guard lives in a database trigger, so it holds even for direct
    SQL writes; we pre-check here only to return a friendlier message.
    """
    employee = db.get(Employee, employee_id)
    if not employee:
        raise NotFoundError(f"Employee {employee_id} not found.")

    if end_date and end_date < start_date:
        raise ValidationError("Contract end_date cannot precede start_date.")

    if status == "RUNNING":
        clashes = find_overlapping_contracts(
            db, employee_id, start_date, end_date or date(9999, 12, 31)
        )
        if clashes:
            raise ConflictError(
                f"{employee.name} already has a RUNNING contract "
                f"({clashes[0].reference_code}) overlapping that period."
            )

    contract = HrContract(
        reference_code=reference_code or next_contract_reference(db, start_date),
        employee_id=employee.id,
        department_id=department_id or employee.department_id,
        job_position_id=job_position_id or employee.job_position_id,
        working_schedule_id=working_schedule_id or employee.working_schedule_id,
        salary_structure_id=salary_structure_id,
        start_date=start_date,
        end_date=end_date,
        wage_monthly=wage_monthly,
        status=status,
        notes=notes,
    )
    db.add(contract)
    db.commit()
    db.refresh(contract)
    return contract


def _payslip_usage(db: Session, contract_id: uuid.UUID | str) -> dict:
    """Where a contract has already been used to pay someone.

    Financial history must not shift under a payslip that has been validated or
    paid, so this decides whether an edit is allowed, allowed-with-recompute, or
    refused outright.
    """
    from app.models.payrun import Payrun, Payslip

    rows = db.execute(
        select(Payslip.reference_code, Payrun.status, Payrun.reference_code)
        .join(Payrun, Payrun.id == Payslip.payrun_id)
        .where(Payslip.contract_id == contract_id)
    ).all()

    locked = [
        f"{slip} in {run} ({run_status})"
        for slip, run_status, run in rows
        if run_status in ("VALIDATED", "PAID")
    ]
    editable = [
        f"{slip} in {run}" for slip, run_status, run in rows
        if run_status not in ("VALIDATED", "PAID")
    ]
    return {"locked": locked, "editable": editable, "total": len(rows)}


# Fields that change what an employee is paid, so they are frozen once a payslip
# generated from this contract has been validated or paid.
FINANCIAL_FIELDS = {"wage_monthly", "start_date", "end_date"}


def update_contract(
    db: Session,
    contract_id: uuid.UUID | str,
    changes: dict,
) -> tuple[HrContract, list[str]]:
    """Correct a contract in place. Returns (contract, advisory notes).

    Use this for genuine corrections, e.g. a typo in the wage before payroll runs.
    For a real pay revision effective from a date, use `revise_wage` instead so the
    old rate stays on record for the periods it applied to.
    """
    contract = get_contract(db, contract_id)
    changes = {k: v for k, v in changes.items() if v is not None}
    if not changes:
        raise ValidationError("No fields supplied to update.")

    unknown = set(changes) - {
        "wage_monthly",
        "start_date",
        "end_date",
        "department_id",
        "job_position_id",
        "working_schedule_id",
        "salary_structure_id",
        "notes",
    }
    if unknown:
        raise ValidationError(f"Fields cannot be updated here: {sorted(unknown)}")

    usage = _payslip_usage(db, contract.id)
    touching_money = FINANCIAL_FIELDS & set(changes)

    if touching_money and usage["locked"]:
        raise ConflictError(
            "This contract has already produced validated or paid payslips, so its "
            "wage and dates are frozen. Use a wage revision effective from a future "
            "date instead.",
            details={"blocking_payslips": usage["locked"]},
        )

    new_start = changes.get("start_date", contract.start_date)
    new_end = changes.get("end_date", contract.end_date)
    if new_end and new_end < new_start:
        raise ValidationError("Contract end_date cannot precede start_date.")

    if contract.status == "RUNNING" and touching_money & {"start_date", "end_date"}:
        clashes = find_overlapping_contracts(
            db,
            contract.employee_id,
            new_start,
            new_end or date(9999, 12, 31),
            exclude_id=contract.id,
        )
        if clashes:
            raise ConflictError(
                "Those dates would overlap RUNNING contract "
                f"{clashes[0].reference_code}."
            )

    if "wage_monthly" in changes and to_decimal(changes["wage_monthly"]) < 0:
        raise ValidationError("wage_monthly cannot be negative.")

    for field, value in changes.items():
        setattr(contract, field, value)

    db.commit()
    db.refresh(contract)

    notes: list[str] = []
    if touching_money and usage["editable"]:
        notes.append(
            f"{len(usage['editable'])} draft payslip(s) were generated from this "
            "contract. Recompute their payrun so the new figures take effect."
        )
    return contract, notes


def revise_wage(
    db: Session,
    contract_id: uuid.UUID | str,
    *,
    new_wage,
    effective_from: date,
    reason: str | None = None,
) -> dict:
    """The correct way to change someone's salary: supersede, never overwrite.

    Closes the current contract the day before `effective_from` and opens a new
    RUNNING contract at the new wage. Payroll for an earlier period still resolves
    the old contract and still pays the old rate, which is what an audit expects.
    """
    old = get_contract(db, contract_id)
    if old.status != "RUNNING":
        raise ConflictError(
            f"Only a RUNNING contract can be revised; {old.reference_code} is "
            f"{old.status}."
        )
    if effective_from <= old.start_date:
        raise ValidationError(
            "effective_from must be after the current contract's start date "
            f"({old.start_date})."
        )
    if old.end_date and effective_from > old.end_date:
        raise ValidationError(
            f"effective_from must fall within the current contract, which ends "
            f"{old.end_date}."
        )
    if to_decimal(new_wage) < 0:
        raise ValidationError("new_wage cannot be negative.")

    # Refuse if the period being closed has already been paid beyond the split.
    from app.models.payrun import Payrun, Payslip

    paid_after = db.execute(
        select(Payslip.reference_code)
        .join(Payrun, Payrun.id == Payslip.payrun_id)
        .where(
            Payslip.contract_id == old.id,
            Payslip.date_end >= effective_from,
            Payrun.status.in_(["VALIDATED", "PAID"]),
        )
    ).scalars().all()
    if paid_after:
        raise ConflictError(
            "Payroll has already been finalised for a period on or after "
            f"{effective_from} using this contract, so it cannot be split there.",
            details={"payslips": list(paid_after)},
        )

    old_end = effective_from - timedelta(days=1)
    old.end_date = old_end
    old.status = "EXPIRED"
    old.notes = (
        f"{old.notes}\n" if old.notes else ""
    ) + f"Superseded by a wage revision effective {effective_from}."
    db.flush()

    new_contract = HrContract(
        reference_code=next_contract_reference(db, effective_from),
        employee_id=old.employee_id,
        department_id=old.department_id,
        job_position_id=old.job_position_id,
        working_schedule_id=old.working_schedule_id,
        salary_structure_id=old.salary_structure_id,
        start_date=effective_from,
        end_date=None,
        wage_monthly=new_wage,
        status="RUNNING",
        notes=(reason or f"Wage revision effective {effective_from}.")
        + f" Supersedes {old.reference_code}.",
    )
    db.add(new_contract)
    db.commit()
    db.refresh(old)
    db.refresh(new_contract)

    return {
        "previous_contract": old,
        "new_contract": new_contract,
        "previous_wage": to_decimal(old.wage_monthly),
        "new_wage": to_decimal(new_contract.wage_monthly),
        "effective_from": effective_from,
        "note": (
            f"{old.reference_code} now ends {old_end} and is EXPIRED. "
            f"{new_contract.reference_code} runs from {effective_from} at the new "
            "wage. Payroll for earlier periods still uses the old rate."
        ),
    }


def revise_compensation(
    db: Session,
    contract_id: uuid.UUID | str,
    *,
    new_wage=None,
    new_salary_structure_id: uuid.UUID | str | None = None,
    effective_from: date,
    reason: str | None = None,
) -> dict:
    """The correct way to change salary or structure: supersede, never overwrite.

    Closes current contract at effective_from - 1 day and opens a new RUNNING
    contract at the new wage and/or salary structure.
    """
    stmt = select(HrContract).where(HrContract.id == contract_id).with_for_update()
    old = db.execute(stmt).scalars().first()
    if not old:
        raise NotFoundError(f"Contract {contract_id} not found.")

    if old.status != "RUNNING":
        raise ConflictError(
            f"Only a RUNNING contract can be revised; {old.reference_code} is {old.status}."
        )
    if effective_from <= old.start_date:
        raise ValidationError(
            f"effective_from must be after current contract's start date ({old.start_date})."
        )
    if old.end_date and effective_from > old.end_date:
        raise ValidationError(
            f"effective_from must fall within current contract, which ends {old.end_date}."
        )

    target_wage = old.wage_monthly if new_wage is None else new_wage
    if to_decimal(target_wage) <= 0:
        raise ValidationError("Wage must be greater than 0.")

    target_structure_id = old.salary_structure_id if new_salary_structure_id is None else new_salary_structure_id
    if target_structure_id:
        from app.models.salary import SalaryStructure
        struct = db.get(SalaryStructure, target_structure_id)
        if not struct:
            raise NotFoundError(f"Salary structure {target_structure_id} not found.")
        if not struct.is_active:
            raise ConflictError(f"Selected salary structure is inactive.")

    from app.models.payrun import Payrun, Payslip

    paid_after = db.execute(
        select(Payslip.reference_code)
        .join(Payrun, Payrun.id == Payslip.payrun_id)
        .where(
            Payslip.contract_id == old.id,
            Payslip.date_end >= effective_from,
            Payrun.status.in_(["VALIDATED", "PAID"]),
        )
    ).scalars().all()
    if paid_after:
        raise ConflictError(
            f"Payroll has already been finalised for a period on or after {effective_from} using this contract, so it cannot be split there.",
            details={"payslips": list(paid_after)},
        )

    open_runs = db.execute(
        select(Payrun.reference_code)
        .join(Payslip, Payslip.payrun_id == Payrun.id)
        .where(
            Payslip.contract_id == old.id,
            Payrun.status.in_(["DRAFT", "COMPUTED"]),
            Payrun.date_start <= effective_from,
            Payrun.date_end >= effective_from,
        )
    ).scalars().all()
    if open_runs:
        raise ConflictError(
            f"This employee is included in an open payrun ({', '.join(open_runs)}) for this period. Finalise or recompute the payrun before changing compensation."
        )

    old_end = effective_from - timedelta(days=1)
    old.end_date = old_end
    old.status = "EXPIRED"
    old.notes = (
        f"{old.notes}\n" if old.notes else ""
    ) + f"Superseded by compensation revision effective {effective_from}."
    db.flush()

    new_contract = HrContract(
        reference_code=next_contract_reference(db, effective_from),
        employee_id=old.employee_id,
        department_id=old.department_id,
        job_position_id=old.job_position_id,
        working_schedule_id=old.working_schedule_id,
        salary_structure_id=target_structure_id,
        start_date=effective_from,
        end_date=None,
        wage_monthly=target_wage,
        status="RUNNING",
        notes=(reason or f"Compensation revision effective {effective_from}.")
        + f" Supersedes {old.reference_code}.",
    )
    db.add(new_contract)
    db.commit()
    db.refresh(old)
    db.refresh(new_contract)

    return {
        "previous_contract": old,
        "new_contract": new_contract,
        "previous_wage": to_decimal(old.wage_monthly),
        "new_wage": to_decimal(new_contract.wage_monthly),
        "effective_from": effective_from,
        "note": (
            f"{old.reference_code} now ends {old_end} and is EXPIRED. "
            f"{new_contract.reference_code} runs from {effective_from} at new compensation."
        ),
    }



def set_contract_status(
    db: Session, contract_id: uuid.UUID | str, new_status: str
) -> HrContract:
    """Guarded state machine. DRAFT -> RUNNING -> EXPIRED, cancellable early."""
    allowed = {
        "DRAFT": {"RUNNING", "CANCELLED"},
        "RUNNING": {"EXPIRED", "CANCELLED"},
        "EXPIRED": set(),
        "CANCELLED": set(),
    }
    contract = get_contract(db, contract_id)
    if new_status == contract.status:
        return contract
    if new_status not in allowed[contract.status]:
        raise ConflictError(
            f"Cannot move contract {contract.reference_code} from "
            f"{contract.status} to {new_status}."
        )
    if new_status == "RUNNING":
        clashes = find_overlapping_contracts(
            db,
            contract.employee_id,
            contract.start_date,
            contract.end_date or date(9999, 12, 31),
            exclude_id=contract.id,
        )
        if clashes:
            raise ConflictError(
                "Activating this contract would overlap RUNNING contract "
                f"{clashes[0].reference_code}."
            )
    contract.status = new_status
    db.commit()
    db.refresh(contract)
    return contract


def expire_due_contracts(db: Session, as_of: date | None = None) -> int:
    """Scheduled housekeeping: flip RUNNING contracts past end_date to EXPIRED."""
    as_of = as_of or date.today()
    stmt = select(HrContract).where(
        HrContract.status == "RUNNING",
        HrContract.end_date.is_not(None),
        HrContract.end_date < as_of,
    )
    due = db.execute(stmt).scalars().all()
    for contract in due:
        contract.status = "EXPIRED"
    db.commit()
    return len(due)
