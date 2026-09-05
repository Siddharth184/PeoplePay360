"""Time off: types, allocations, requests and the approval workflow."""

from __future__ import annotations

import uuid
from datetime import date
from decimal import Decimal
from typing import List, Optional

from fastapi import APIRouter, Depends, Query
from sqlalchemy import func, select
from sqlalchemy.orm import aliased

from app.api.deps import (
    DbSession,
    PageParams,
    User,
    resolve_target_employee,
    scope_employee_filter,
)
from app.core.errors import ConflictError, ForbiddenError, NotFoundError
from app.core.security import CurrentUser, require_hr
from app.models.employee import Employee
from app.models.timeoff import LeaveAllocation, LeaveRequest, TimeOffType
from app.schemas.common import MessageResponse
from app.schemas.hr import (
    AllocationCreate,
    AllocationOut,
    AllocationStatusUpdate,
    AllocationUpdate,
    LeaveBalanceOut,
    LeaveDurationPreview,
    LeaveRequestCreate,
    LeaveRequestOut,
    LeaveRequestUpdate,
    TimeOffTypeCreate,
    TimeOffTypeOut,
    TimeOffTypeUpdate,
)
from app.services import timeoff_service

router = APIRouter(prefix="/timeoff", tags=["Time Off"])


# ===========================================================================
# TYPES
# ===========================================================================
@router.get("/types", response_model=List[TimeOffTypeOut], summary="List time off types")
def list_types(
    db: DbSession, user: User, include_inactive: bool = Query(default=False)
) -> List[TimeOffTypeOut]:
    stmt = select(TimeOffType).order_by(TimeOffType.name)
    if not include_inactive:
        stmt = stmt.where(TimeOffType.is_active.is_(True))
    return [
        TimeOffTypeOut.model_validate(t) for t in db.execute(stmt).scalars().all()
    ]


@router.post(
    "/types",
    response_model=TimeOffTypeOut,
    status_code=201,
    summary="Create a time off type",
)
def create_type(
    payload: TimeOffTypeCreate, db: DbSession, _: CurrentUser = Depends(require_hr)
) -> TimeOffTypeOut:
    kind = TimeOffType(**payload.model_dump())
    db.add(kind)
    db.commit()
    db.refresh(kind)
    return TimeOffTypeOut.model_validate(kind)


@router.patch(
    "/types/{type_id}",
    response_model=TimeOffTypeOut,
    summary="Update a time off type's policy behaviour",
)
def update_type(
    type_id: uuid.UUID,
    payload: TimeOffTypeUpdate,
    db: DbSession,
    _: CurrentUser = Depends(require_hr),
) -> TimeOffTypeOut:
    kind = db.get(TimeOffType, type_id)
    if not kind:
        raise NotFoundError("Time off type not found.")

    updates = payload.model_dump(exclude_unset=True)

    # Turning allocation tracking ON retroactively would leave already-approved
    # requests unfunded, so surface that rather than silently breaking the ledger.
    if updates.get("requires_allocation") and not kind.requires_allocation:
        approved = db.execute(
            select(func.count(LeaveRequest.id)).where(
                LeaveRequest.timeoff_type_id == kind.id,
                LeaveRequest.status == "APPROVED",
                LeaveRequest.allocation_id.is_(None),
            )
        ).scalar_one()
        if approved:
            raise ConflictError(
                f"{approved} approved '{kind.name}' request(s) were granted without "
                "an allocation. Requiring allocation now would leave them unfunded. "
                "Grant allocations for those employees first."
            )

    for field, value in updates.items():
        setattr(kind, field, value)

    db.commit()
    db.refresh(kind)
    return TimeOffTypeOut.model_validate(kind)


@router.delete(
    "/types/{type_id}",
    response_model=MessageResponse,
    summary="Delete a time off type, or deactivate it when already used",
)
def delete_type(
    type_id: uuid.UUID, db: DbSession, _: CurrentUser = Depends(require_hr)
) -> MessageResponse:
    kind = db.get(TimeOffType, type_id)
    if not kind:
        raise NotFoundError("Time off type not found.")

    requests = db.execute(
        select(func.count(LeaveRequest.id)).where(
            LeaveRequest.timeoff_type_id == kind.id
        )
    ).scalar_one()
    allocations = db.execute(
        select(func.count(LeaveAllocation.id)).where(
            LeaveAllocation.timeoff_type_id == kind.id
        )
    ).scalar_one()

    if requests or allocations:
        kind.is_active = False
        db.commit()
        return MessageResponse(
            detail=(
                f"'{kind.name}' has {requests} request(s) and {allocations} "
                "allocation(s) against it, so it was deactivated instead of deleted. "
                "It no longer appears for new requests."
            )
        )

    db.delete(kind)
    db.commit()
    return MessageResponse(detail=f"Time off type '{kind.name}' deleted.")


# ===========================================================================
# ALLOCATIONS
# ===========================================================================
@router.get(
    "/allocations",
    response_model=List[AllocationOut],
    summary="Master allocation balance matrix (EMPLOYEE filtered to self)",
)
def list_allocations(
    db: DbSession,
    page: PageParams,
    user: User,
    employee_id: Optional[uuid.UUID] = Query(default=None),
    timeoff_type_id: Optional[uuid.UUID] = Query(default=None),
    status: Optional[str] = Query(default=None),
    validity_year: Optional[int] = Query(default=None),
) -> List[AllocationOut]:
    emp = aliased(Employee)
    kind = aliased(TimeOffType)
    stmt = (
        select(LeaveAllocation, emp.name, kind.name)
        .join(emp, emp.id == LeaveAllocation.employee_id)
        .join(kind, kind.id == LeaveAllocation.timeoff_type_id)
        .order_by(LeaveAllocation.validity_year.desc(), emp.badge_id)
    )

    scoped = scope_employee_filter(user)
    if scoped is not None:
        stmt = stmt.where(LeaveAllocation.employee_id == scoped)
    elif employee_id:
        stmt = stmt.where(LeaveAllocation.employee_id == employee_id)

    if timeoff_type_id:
        stmt = stmt.where(LeaveAllocation.timeoff_type_id == timeoff_type_id)
    if status:
        stmt = stmt.where(LeaveAllocation.status == status)
    if validity_year:
        stmt = stmt.where(LeaveAllocation.validity_year == validity_year)

    rows = db.execute(stmt.limit(page.limit).offset(page.offset)).all()
    return [
        AllocationOut(
            id=alloc.id,
            employee_id=alloc.employee_id,
            employee_name=emp_name,
            timeoff_type_id=alloc.timeoff_type_id,
            timeoff_type_name=type_name,
            allocated_days=alloc.allocated_days,
            taken_days=alloc.taken_days,
            remaining_days=alloc.remaining_days,
            validity_year=alloc.validity_year,
            validity_label=alloc.validity_label,
            status=alloc.status,
            description=alloc.description,
            created_at=alloc.created_at,
        )
        for alloc, emp_name, type_name in rows
    ]


@router.get(
    "/balance",
    response_model=List[LeaveBalanceOut],
    summary="Approved balances for one employee (defaults to the caller)",
)
def get_balance(
    db: DbSession,
    user: User,
    employee_id: Optional[uuid.UUID] = Query(default=None),
    validity_year: Optional[int] = Query(default=None),
) -> List[LeaveBalanceOut]:
    target = resolve_target_employee(user, employee_id)
    return [
        LeaveBalanceOut(**row)
        for row in timeoff_service.leave_balance(db, target, validity_year=validity_year)
    ]


@router.post(
    "/allocations",
    response_model=AllocationOut,
    status_code=201,
    summary="Grant a leave allocation",
)
def create_allocation(
    payload: AllocationCreate,
    db: DbSession,
    user: CurrentUser = Depends(require_hr),
) -> AllocationOut:
    allocation = timeoff_service.create_allocation(
        db,
        employee_id=payload.employee_id,
        timeoff_type_id=payload.timeoff_type_id,
        allocated_days=payload.allocated_days,
        validity_year=payload.validity_year,
        validity_label=payload.validity_label,
        description=payload.description,
        status=payload.status.value,
        approver_employee_id=user.employee_id,
    )
    return _allocation_out(db, allocation)


@router.patch(
    "/allocations/{allocation_id}",
    response_model=AllocationOut,
    summary=(
        "Adjust a granted allocation. Cannot be reduced below days already taken."
    ),
)
def update_allocation(
    allocation_id: uuid.UUID,
    payload: AllocationUpdate,
    db: DbSession,
    _: CurrentUser = Depends(require_hr),
) -> AllocationOut:
    allocation = timeoff_service.update_allocation(
        db, allocation_id, payload.model_dump(exclude_unset=True)
    )
    return _allocation_out(db, allocation)


@router.delete(
    "/allocations/{allocation_id}",
    response_model=MessageResponse,
    summary="Delete an allocation that has never been drawn against",
)
def delete_allocation(
    allocation_id: uuid.UUID, db: DbSession, _: CurrentUser = Depends(require_hr)
) -> MessageResponse:
    allocation = db.get(LeaveAllocation, allocation_id)
    if not allocation:
        raise NotFoundError("Leave allocation not found.")
    if Decimal(str(allocation.taken_days or 0)) > 0:
        raise ConflictError(
            f"{allocation.taken_days} day(s) have been taken from this allocation. "
            "Refuse it instead so the ledger stays consistent."
        )
    db.delete(allocation)
    db.commit()
    return MessageResponse(detail="Allocation deleted.")


@router.post(
    "/allocations/{allocation_id}/status",
    response_model=AllocationOut,
    summary="Approve or refuse an allocation",
)
def set_allocation_status(
    allocation_id: uuid.UUID,
    payload: AllocationStatusUpdate,
    db: DbSession,
    user: CurrentUser = Depends(require_hr),
) -> AllocationOut:
    allocation = timeoff_service.set_allocation_status(
        db, allocation_id, payload.status.value, user.employee_id
    )
    return _allocation_out(db, allocation)


def _allocation_out(db, allocation: LeaveAllocation) -> AllocationOut:
    employee = db.get(Employee, allocation.employee_id)
    kind = db.get(TimeOffType, allocation.timeoff_type_id)
    return AllocationOut(
        id=allocation.id,
        employee_id=allocation.employee_id,
        employee_name=employee.name if employee else None,
        timeoff_type_id=allocation.timeoff_type_id,
        timeoff_type_name=kind.name if kind else None,
        allocated_days=allocation.allocated_days,
        taken_days=allocation.taken_days,
        remaining_days=allocation.remaining_days,
        validity_year=allocation.validity_year,
        validity_label=allocation.validity_label,
        status=allocation.status,
        description=allocation.description,
        created_at=allocation.created_at,
    )


# ===========================================================================
# REQUESTS
# ===========================================================================
@router.get(
    "/requests",
    response_model=List[LeaveRequestOut],
    summary="List leave requests (EMPLOYEE filtered to self)",
)
def list_requests(
    db: DbSession,
    page: PageParams,
    user: User,
    employee_id: Optional[uuid.UUID] = Query(default=None),
    status: Optional[str] = Query(default=None),
    timeoff_type_id: Optional[uuid.UUID] = Query(default=None),
    date_from: Optional[date] = Query(default=None),
    date_to: Optional[date] = Query(default=None),
    pending_for_my_team: bool = Query(
        default=False, description="Only requests from the caller's direct reports"
    ),
) -> List[LeaveRequestOut]:
    emp = aliased(Employee)
    kind = aliased(TimeOffType)
    stmt = (
        select(LeaveRequest, emp.name, kind.name)
        .join(emp, emp.id == LeaveRequest.employee_id)
        .join(kind, kind.id == LeaveRequest.timeoff_type_id)
        .order_by(LeaveRequest.created_at.desc())
    )

    scoped = scope_employee_filter(user)
    if scoped is not None:
        stmt = stmt.where(LeaveRequest.employee_id == scoped)
    elif employee_id:
        stmt = stmt.where(LeaveRequest.employee_id == employee_id)

    if pending_for_my_team and user.employee_id:
        stmt = stmt.where(emp.manager_id == user.employee_id)
    if status:
        stmt = stmt.where(LeaveRequest.status == status)
    if timeoff_type_id:
        stmt = stmt.where(LeaveRequest.timeoff_type_id == timeoff_type_id)
    if date_from:
        stmt = stmt.where(LeaveRequest.end_date >= date_from)
    if date_to:
        stmt = stmt.where(LeaveRequest.start_date <= date_to)

    rows = db.execute(stmt.limit(page.limit).offset(page.offset)).all()
    return [
        LeaveRequestOut(
            id=req.id,
            employee_id=req.employee_id,
            employee_name=emp_name,
            timeoff_type_id=req.timeoff_type_id,
            timeoff_type_name=type_name,
            allocation_id=req.allocation_id,
            start_date=req.start_date,
            end_date=req.end_date,
            duration_days=req.duration_days,
            reason=req.reason,
            status=req.status,
            approver_employee_id=req.approver_employee_id,
            created_at=req.created_at,
        )
        for req, emp_name, type_name in rows
    ]


@router.get(
    "/requests/duration-preview",
    response_model=LeaveDurationPreview,
    summary="How many working days a date range costs, before submitting",
)
def duration_preview(
    db: DbSession,
    user: User,
    start_date: date = Query(...),
    end_date: date = Query(...),
    employee_id: Optional[uuid.UUID] = Query(default=None),
) -> LeaveDurationPreview:
    target = resolve_target_employee(user, employee_id)
    working = timeoff_service.compute_leave_duration(db, target, start_date, end_date)
    return LeaveDurationPreview(
        start_date=start_date,
        end_date=end_date,
        working_days=working,
        calendar_days=(end_date - start_date).days + 1,
    )


@router.post(
    "/requests",
    response_model=LeaveRequestOut,
    status_code=201,
    summary="Create a leave request (validates the allocation balance up front)",
)
def create_request(
    payload: LeaveRequestCreate, db: DbSession, user: User
) -> LeaveRequestOut:
    target = resolve_target_employee(user, payload.employee_id)
    request = timeoff_service.create_leave_request(
        db,
        employee_id=target,
        timeoff_type_id=payload.timeoff_type_id,
        start_date=payload.start_date,
        end_date=payload.end_date,
        reason=payload.reason,
        duration_days=payload.duration_days,
    )
    return _request_out(db, request)


@router.patch(
    "/requests/{request_id}",
    response_model=LeaveRequestOut,
    summary="Amend a request that is still awaiting approval",
)
def update_request(
    request_id: uuid.UUID,
    payload: LeaveRequestUpdate,
    db: DbSession,
    user: User,
) -> LeaveRequestOut:
    request = db.get(LeaveRequest, request_id)
    if not request:
        raise NotFoundError("Leave request not found.")
    # Owner or HR. An employee may not edit someone else's request.
    if not user.has_hr_scope and str(request.employee_id) != str(user.employee_id):
        raise ForbiddenError("You may only edit your own time off requests.")

    updated = timeoff_service.update_leave_request(
        db,
        request_id,
        payload.model_dump(exclude_unset=True),
        actor_employee_id=user.employee_id,
    )
    return _request_out(db, updated)


@router.post(
    "/requests/{request_id}/cancel",
    response_model=LeaveRequestOut,
    summary=(
        "Withdraw a request. If it was already approved the days are credited back "
        "to the allocation."
    ),
)
def cancel_request(
    request_id: uuid.UUID, db: DbSession, user: User
) -> LeaveRequestOut:
    request = db.get(LeaveRequest, request_id)
    if not request:
        raise NotFoundError("Leave request not found.")
    if not user.has_hr_scope and str(request.employee_id) != str(user.employee_id):
        raise ForbiddenError("You may only cancel your own time off requests.")

    updated = timeoff_service.cancel_leave_request(
        db, request_id, actor_employee_id=user.employee_id
    )
    _notify_decision(db, updated, "cancelled")
    return _request_out(db, updated)


@router.post(
    "/requests/{request_id}/approve",
    response_model=LeaveRequestOut,
    summary="Approve a leave request (debits the allocation atomically)",
)
def approve_request(
    request_id: uuid.UUID,
    db: DbSession,
    user: CurrentUser = Depends(require_hr),
) -> LeaveRequestOut:
    request = db.get(LeaveRequest, request_id)
    if not request:
        raise NotFoundError("Leave request not found.")
    # Self-approval is a segregation-of-duties failure; only ADMIN may override.
    if str(request.employee_id) == str(user.employee_id) and not user.is_admin:
        raise ForbiddenError("You cannot approve your own leave request.")

    updated = timeoff_service.process_leave_approval(db, request_id, user.employee_id)
    _notify_decision(db, updated, "approved")
    return _request_out(db, updated)


@router.post(
    "/requests/{request_id}/refuse",
    response_model=LeaveRequestOut,
    summary="Refuse a request (credits the allocation back if already approved)",
)
def refuse_request(
    request_id: uuid.UUID,
    db: DbSession,
    user: CurrentUser = Depends(require_hr),
) -> LeaveRequestOut:
    updated = timeoff_service.process_leave_refusal(db, request_id, user.employee_id)
    _notify_decision(db, updated, "refused")
    return _request_out(db, updated)


def _notify_decision(db, request: LeaveRequest, verb: str) -> None:
    """Tell the employee. Silent approvals are a support-ticket generator."""
    from sqlalchemy import text

    employee = db.get(Employee, request.employee_id)
    if not employee or not employee.user_id:
        return
    db.execute(
        text(
            """
            INSERT INTO notifications
                (recipient_user_id, kind, title, body, deep_link)
            VALUES (CAST(:u AS uuid), 'TIMEOFF_DECISION', :title, :body, :link)
            """
        ),
        {
            "u": str(employee.user_id),
            "title": f"Your time off request was {verb}",
            "body": f"{request.start_date} to {request.end_date} "
            f"({request.duration_days} day(s))",
            "link": f"/timeoff/requests/{request.id}",
        },
    )
    db.commit()


def _request_out(db, request: LeaveRequest) -> LeaveRequestOut:
    employee = db.get(Employee, request.employee_id)
    kind = db.get(TimeOffType, request.timeoff_type_id)
    return LeaveRequestOut(
        id=request.id,
        employee_id=request.employee_id,
        employee_name=employee.name if employee else None,
        timeoff_type_id=request.timeoff_type_id,
        timeoff_type_name=kind.name if kind else None,
        allocation_id=request.allocation_id,
        start_date=request.start_date,
        end_date=request.end_date,
        duration_days=request.duration_days,
        reason=request.reason,
        status=request.status,
        approver_employee_id=request.approver_employee_id,
        created_at=request.created_at,
    )
