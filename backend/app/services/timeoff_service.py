"""Leave Allocation Consumption & Validation Engine (architecture section 3.3).

The allocation row is the ledger. Approving a request debits it; refusing or
reverting an already-approved request credits it back. Every mutation takes a
`FOR UPDATE` row lock so two managers approving simultaneously cannot both spend
the same remaining balance.
"""

from __future__ import annotations

import uuid
from datetime import date, timedelta
from decimal import Decimal
from typing import Any, Dict, Sequence

from sqlalchemy import select
from sqlalchemy.orm import Session

from app.core.errors import ConflictError, NotFoundError, ValidationError
from app.models.employee import Employee
from app.models.master import PublicHoliday, WorkingScheduleLine
from app.models.timeoff import LeaveAllocation, LeaveRequest, TimeOffType
from app.services.salary_engine import ZERO, to_decimal


# ---------------------------------------------------------------------------
# DURATION
# ---------------------------------------------------------------------------
def compute_leave_duration(
    db: Session,
    employee_id: uuid.UUID | str,
    start_date: date,
    end_date: date,
) -> Decimal:
    """Working days between two dates, per the employee's schedule, minus holidays.

    Counting raw calendar days would charge employees for weekends.
    """
    if end_date < start_date:
        raise ValidationError("Leave end_date cannot precede start_date.")

    employee = db.get(Employee, employee_id)
    if not employee:
        raise NotFoundError(f"Employee {employee_id} not found.")

    working_dows: set[int] = set()
    if employee.working_schedule_id:
        working_dows = set(
            db.execute(
                select(WorkingScheduleLine.day_of_week).where(
                    WorkingScheduleLine.schedule_id == employee.working_schedule_id
                )
            ).scalars()
        )
    if not working_dows:
        working_dows = {0, 1, 2, 3, 4}  # sane Mon-Fri default

    holidays = set(
        db.execute(
            select(PublicHoliday.holiday_date).where(
                PublicHoliday.holiday_date.between(start_date, end_date)
            )
        ).scalars()
    )

    days = 0
    for offset in range((end_date - start_date).days + 1):
        day = start_date + timedelta(days=offset)
        if day.weekday() in working_dows and day not in holidays:
            days += 1

    if days == 0:
        raise ValidationError(
            "The selected range contains no working days for this employee."
        )
    return Decimal(days)


# ---------------------------------------------------------------------------
# BALANCE
# ---------------------------------------------------------------------------
def leave_balance(
    db: Session, employee_id: uuid.UUID | str, *, validity_year: int | None = None
) -> list[Dict[str, Any]]:
    stmt = (
        select(LeaveAllocation, TimeOffType)
        .join(TimeOffType, TimeOffType.id == LeaveAllocation.timeoff_type_id)
        .where(
            LeaveAllocation.employee_id == employee_id,
            LeaveAllocation.status == "APPROVED",
        )
        .order_by(TimeOffType.name)
    )
    if validity_year is not None:
        stmt = stmt.where(LeaveAllocation.validity_year == validity_year)

    return [
        {
            "allocation_id": alloc.id,
            "timeoff_type_id": kind.id,
            "timeoff_type_name": kind.name,
            "display_color": kind.display_color,
            "unit": kind.unit,
            "allocated_days": to_decimal(alloc.allocated_days),
            "taken_days": to_decimal(alloc.taken_days),
            "remaining_days": to_decimal(alloc.remaining_days),
            "validity_year": alloc.validity_year,
        }
        for alloc, kind in db.execute(stmt).all()
    ]


def _find_fundable_allocation(
    db: Session,
    employee_id: uuid.UUID | str,
    timeoff_type_id: uuid.UUID | str,
    needed: Decimal,
    *,
    lock: bool = True,
) -> LeaveAllocation | None:
    stmt = (
        select(LeaveAllocation)
        .where(
            LeaveAllocation.employee_id == employee_id,
            LeaveAllocation.timeoff_type_id == timeoff_type_id,
            LeaveAllocation.status == "APPROVED",
            LeaveAllocation.remaining_days >= needed,
        )
        # Spend the oldest validity year first so entitlements do not silently expire.
        .order_by(LeaveAllocation.validity_year.asc(), LeaveAllocation.created_at.asc())
    )
    if lock:
        # Generated columns cannot be locked with FOR UPDATE OF, so lock the row.
        stmt = stmt.with_for_update()
    return db.execute(stmt).scalars().first()


def _overlapping_requests(
    db: Session,
    employee_id: uuid.UUID | str,
    start_date: date,
    end_date: date,
    *,
    exclude_id: uuid.UUID | str | None = None,
) -> Sequence[LeaveRequest]:
    stmt = select(LeaveRequest).where(
        LeaveRequest.employee_id == employee_id,
        LeaveRequest.status.in_(["TO_APPROVE", "APPROVED"]),
        LeaveRequest.start_date <= end_date,
        LeaveRequest.end_date >= start_date,
    )
    if exclude_id:
        stmt = stmt.where(LeaveRequest.id != exclude_id)
    return db.execute(stmt).scalars().all()


# ---------------------------------------------------------------------------
# REQUEST LIFECYCLE
# ---------------------------------------------------------------------------
def create_leave_request(
    db: Session,
    *,
    employee_id: uuid.UUID | str,
    timeoff_type_id: uuid.UUID | str,
    start_date: date,
    end_date: date,
    reason: str | None = None,
    duration_days: Decimal | None = None,
) -> LeaveRequest:
    kind = db.get(TimeOffType, timeoff_type_id)
    if not kind or not kind.is_active:
        raise NotFoundError("Time off type not found or inactive.")

    duration = (
        to_decimal(duration_days)
        if duration_days is not None
        else compute_leave_duration(db, employee_id, start_date, end_date)
    )
    if duration <= ZERO:
        raise ValidationError("Leave duration must be greater than zero.")

    clashes = _overlapping_requests(db, employee_id, start_date, end_date)
    if clashes:
        raise ConflictError(
            "You already have a pending or approved leave request overlapping "
            f"{clashes[0].start_date} to {clashes[0].end_date}."
        )

    # Fail fast at submission time rather than surprising the approver later.
    if kind.requires_allocation:
        if not _find_fundable_allocation(
            db, employee_id, timeoff_type_id, duration, lock=False
        ):
            raise ValidationError(
                f"Insufficient approved '{kind.name}' balance for {duration} day(s)."
            )

    request = LeaveRequest(
        employee_id=employee_id,
        timeoff_type_id=timeoff_type_id,
        start_date=start_date,
        end_date=end_date,
        duration_days=duration,
        reason=reason,
        status="TO_APPROVE",
    )
    db.add(request)
    db.commit()
    db.refresh(request)
    return request


def process_leave_approval(
    db: Session,
    request_id: uuid.UUID | str,
    approver_employee_id: uuid.UUID | str | None,
) -> LeaveRequest:
    """Approve a request and debit the matching allocation atomically."""
    request = db.execute(
        select(LeaveRequest).where(LeaveRequest.id == request_id).with_for_update()
    ).scalars().first()
    if not request:
        raise NotFoundError("Leave request not found.")
    if request.status != "TO_APPROVE":
        raise ConflictError(
            f"Cannot approve request with status '{request.status}'."
        )

    kind = db.get(TimeOffType, request.timeoff_type_id)
    if not kind:
        raise NotFoundError("Time off type not found.")

    if kind.requires_allocation:
        allocation = _find_fundable_allocation(
            db, request.employee_id, request.timeoff_type_id, to_decimal(request.duration_days)
        )
        if not allocation:
            raise ValidationError(
                "Insufficient approved leave allocation balance for this request."
            )
        allocation.taken_days = to_decimal(allocation.taken_days) + to_decimal(
            request.duration_days
        )
        request.allocation_id = allocation.id

    request.status = "APPROVED"
    request.approver_employee_id = approver_employee_id
    db.commit()
    db.refresh(request)
    return request


def process_leave_refusal(
    db: Session,
    request_id: uuid.UUID | str,
    approver_employee_id: uuid.UUID | str | None,
) -> LeaveRequest:
    """Refuse a request. If it was already approved, credit the allocation back."""
    request = db.execute(
        select(LeaveRequest).where(LeaveRequest.id == request_id).with_for_update()
    ).scalars().first()
    if not request:
        raise NotFoundError("Leave request not found.")
    if request.status == "REFUSED":
        return request

    if request.status == "APPROVED" and request.allocation_id:
        allocation = db.execute(
            select(LeaveAllocation)
            .where(LeaveAllocation.id == request.allocation_id)
            .with_for_update()
        ).scalars().first()
        if allocation:
            restored = to_decimal(allocation.taken_days) - to_decimal(
                request.duration_days
            )
            allocation.taken_days = max(ZERO, restored)
        request.allocation_id = None

    request.status = "REFUSED"
    request.approver_employee_id = approver_employee_id
    db.commit()
    db.refresh(request)
    return request


# ---------------------------------------------------------------------------
# ALLOCATION LIFECYCLE
# ---------------------------------------------------------------------------
def create_allocation(
    db: Session,
    *,
    employee_id: uuid.UUID | str,
    timeoff_type_id: uuid.UUID | str,
    allocated_days: Decimal,
    validity_year: int | None = None,
    validity_label: str | None = None,
    description: str | None = None,
    status: str = "TO_APPROVE",
    approver_employee_id: uuid.UUID | str | None = None,
) -> LeaveAllocation:
    if to_decimal(allocated_days) < ZERO:
        raise ValidationError("allocated_days cannot be negative.")
    if not db.get(Employee, employee_id):
        raise NotFoundError(f"Employee {employee_id} not found.")
    if not db.get(TimeOffType, timeoff_type_id):
        raise NotFoundError("Time off type not found.")

    year = validity_year or date.today().year
    allocation = LeaveAllocation(
        employee_id=employee_id,
        timeoff_type_id=timeoff_type_id,
        allocated_days=to_decimal(allocated_days),
        validity_year=year,
        validity_label=validity_label or f"{year} Annual Balance",
        description=description,
        status=status,
        approver_employee_id=approver_employee_id,
    )
    db.add(allocation)
    db.commit()
    db.refresh(allocation)
    return allocation


def update_allocation(
    db: Session,
    allocation_id: uuid.UUID | str,
    changes: dict,
) -> LeaveAllocation:
    """Adjust a granted allocation.

    The one rule that matters: `allocated_days` can never drop below what has
    already been consumed, or the ledger would go negative and the database CHECK
    would reject it with an opaque error. We refuse with an explanatory message
    instead, naming the floor.
    """
    allocation = db.execute(
        select(LeaveAllocation)
        .where(LeaveAllocation.id == allocation_id)
        .with_for_update()
    ).scalars().first()
    if not allocation:
        raise NotFoundError("Leave allocation not found.")

    changes = {k: v for k, v in changes.items() if v is not None}
    if not changes:
        raise ValidationError("No fields supplied to update.")

    allowed = {"allocated_days", "validity_year", "validity_label", "description"}
    unknown = set(changes) - allowed
    if unknown:
        raise ValidationError(f"Fields cannot be updated here: {sorted(unknown)}")

    if "allocated_days" in changes:
        new_total = to_decimal(changes["allocated_days"])
        taken = to_decimal(allocation.taken_days)
        if new_total < ZERO:
            raise ValidationError("allocated_days cannot be negative.")
        if new_total < taken:
            raise ConflictError(
                f"{taken} day(s) have already been taken from this allocation, so it "
                f"cannot be reduced below {taken}. Refuse or cancel the approved "
                "requests first."
            )
        allocation.allocated_days = new_total

    for field in ("validity_year", "validity_label", "description"):
        if field in changes:
            setattr(allocation, field, changes[field])

    db.commit()
    db.refresh(allocation)
    return allocation


def update_leave_request(
    db: Session,
    request_id: uuid.UUID | str,
    changes: dict,
    *,
    actor_employee_id: uuid.UUID | str | None = None,
) -> LeaveRequest:
    """Amend a leave request that has not been approved yet.

    An approved request is not edited in place: the balance has already moved, so
    silently changing the dates or duration would desynchronise the ledger. Refuse
    or cancel it and submit a new one.
    """
    request = db.execute(
        select(LeaveRequest).where(LeaveRequest.id == request_id).with_for_update()
    ).scalars().first()
    if not request:
        raise NotFoundError("Leave request not found.")
    if request.status != "TO_APPROVE":
        raise ConflictError(
            f"This request is {request.status} and can no longer be edited. Cancel "
            "it and submit a new one."
        )

    changes = {k: v for k, v in changes.items() if v is not None}
    if not changes:
        raise ValidationError("No fields supplied to update.")

    allowed = {"start_date", "end_date", "timeoff_type_id", "reason", "duration_days"}
    unknown = set(changes) - allowed
    if unknown:
        raise ValidationError(f"Fields cannot be updated here: {sorted(unknown)}")

    new_start = changes.get("start_date", request.start_date)
    new_end = changes.get("end_date", request.end_date)
    if new_end < new_start:
        raise ValidationError("end_date cannot precede start_date.")

    new_type_id = changes.get("timeoff_type_id", request.timeoff_type_id)
    kind = db.get(TimeOffType, new_type_id)
    if not kind or not kind.is_active:
        raise NotFoundError("Time off type not found or inactive.")

    if "duration_days" in changes:
        duration = to_decimal(changes["duration_days"])
        if duration <= ZERO:
            raise ValidationError("duration_days must be greater than zero.")
    elif {"start_date", "end_date"} & set(changes):
        duration = compute_leave_duration(db, request.employee_id, new_start, new_end)
    else:
        duration = to_decimal(request.duration_days)

    clashes = _overlapping_requests(
        db, request.employee_id, new_start, new_end, exclude_id=request.id
    )
    if clashes:
        raise ConflictError(
            "That range overlaps another pending or approved request "
            f"({clashes[0].start_date} to {clashes[0].end_date})."
        )

    if kind.requires_allocation and not _find_fundable_allocation(
        db, request.employee_id, new_type_id, duration, lock=False
    ):
        raise ValidationError(
            f"Insufficient approved '{kind.name}' balance for {duration} day(s)."
        )

    request.start_date = new_start
    request.end_date = new_end
    request.timeoff_type_id = new_type_id
    request.duration_days = duration
    if "reason" in changes:
        request.reason = changes["reason"]

    db.commit()
    db.refresh(request)
    return request


def cancel_leave_request(
    db: Session,
    request_id: uuid.UUID | str,
    *,
    actor_employee_id: uuid.UUID | str | None = None,
    allow_approved: bool = True,
) -> LeaveRequest:
    """Withdraw a request, crediting the balance back if it was already approved.

    Modelled as REFUSED rather than a delete so the audit trail survives; the
    ledger correction is identical to a manager refusal.
    """
    request = db.execute(
        select(LeaveRequest).where(LeaveRequest.id == request_id).with_for_update()
    ).scalars().first()
    if not request:
        raise NotFoundError("Leave request not found.")
    if request.status == "REFUSED":
        return request
    if request.status == "APPROVED" and not allow_approved:
        raise ConflictError(
            "This request is already approved; ask HR to cancel it for you."
        )

    if request.status == "APPROVED" and request.allocation_id:
        allocation = db.execute(
            select(LeaveAllocation)
            .where(LeaveAllocation.id == request.allocation_id)
            .with_for_update()
        ).scalars().first()
        if allocation:
            allocation.taken_days = max(
                ZERO,
                to_decimal(allocation.taken_days) - to_decimal(request.duration_days),
            )
        request.allocation_id = None

    request.status = "REFUSED"
    request.reason = (
        f"{request.reason} " if request.reason else ""
    ) + "[cancelled by employee]"
    db.commit()
    db.refresh(request)
    return request


def set_allocation_status(
    db: Session,
    allocation_id: uuid.UUID | str,
    status: str,
    approver_employee_id: uuid.UUID | str | None,
) -> LeaveAllocation:
    allocation = db.get(LeaveAllocation, allocation_id)
    if not allocation:
        raise NotFoundError("Leave allocation not found.")
    if status not in ("TO_APPROVE", "APPROVED", "REFUSED"):
        raise ValidationError(f"Unsupported allocation status '{status}'.")
    if status == "REFUSED" and to_decimal(allocation.taken_days) > ZERO:
        raise ConflictError(
            "This allocation has already been partly consumed and cannot be refused."
        )
    allocation.status = status
    allocation.approver_employee_id = approver_employee_id
    db.commit()
    db.refresh(allocation)
    return allocation
