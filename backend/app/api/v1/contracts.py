"""Contract endpoints. Creation goes through the overlap-guarded service."""

from __future__ import annotations

import uuid
from datetime import date
from typing import List, Optional

from fastapi import APIRouter, Depends, Query
from sqlalchemy import select
from sqlalchemy.orm import aliased

from app.api.deps import DbSession, PageParams, User
from app.core.security import CurrentUser, require_hr, require_payroll_manager
from app.models.contract import HrContract
from app.models.employee import Employee
from app.schemas.common import MessageResponse
from app.schemas.hr import (
    ContractCreate,
    ContractOut,
    ContractRevisionResult,
    ContractStatusUpdate,
    ContractUpdate,
    ContractUpdateResult,
    ContractWageRevision,
)
from app.services import contract_service

router = APIRouter(prefix="/contracts", tags=["Contracts"])


def _serialise(contract: HrContract, employee_name: str | None) -> ContractOut:
    return ContractOut(
        id=contract.id,
        reference_code=contract.reference_code,
        employee_id=contract.employee_id,
        employee_name=employee_name,
        department_id=contract.department_id,
        job_position_id=contract.job_position_id,
        working_schedule_id=contract.working_schedule_id,
        salary_structure_id=contract.salary_structure_id,
        start_date=contract.start_date,
        end_date=contract.end_date,
        wage_monthly=contract.wage_monthly,
        status=contract.status,
        notes=contract.notes,
        created_at=contract.created_at,
    )


@router.get(
    "",
    response_model=List[ContractOut],
    summary="List contracts with running-status and period filters",
)
def list_contracts(
    db: DbSession,
    page: PageParams,
    user: CurrentUser = Depends(require_hr),
    employee_id: Optional[uuid.UUID] = Query(default=None),
    status: Optional[str] = Query(default=None),
    active_on: Optional[date] = Query(
        default=None, description="Only contracts covering this date"
    ),
    expiring_before: Optional[date] = Query(default=None),
) -> List[ContractOut]:
    emp = aliased(Employee)
    stmt = (
        select(HrContract, emp.name)
        .join(emp, emp.id == HrContract.employee_id)
        .order_by(HrContract.start_date.desc())
    )
    if employee_id:
        stmt = stmt.where(HrContract.employee_id == employee_id)
    if status:
        stmt = stmt.where(HrContract.status == status)
    if active_on:
        stmt = stmt.where(
            HrContract.start_date <= active_on,
            (HrContract.end_date.is_(None)) | (HrContract.end_date >= active_on),
        )
    if expiring_before:
        stmt = stmt.where(
            HrContract.end_date.is_not(None), HrContract.end_date <= expiring_before
        )

    rows = db.execute(stmt.limit(page.limit).offset(page.offset)).all()
    return [_serialise(c, name) for c, name in rows]


@router.get(
    "/my",
    response_model=List[ContractOut],
    summary="The caller's own contracts",
)
def my_contracts(db: DbSession, user: User) -> List[ContractOut]:
    from app.api.deps import require_linked_employee

    employee_id = require_linked_employee(user)
    employee = db.get(Employee, employee_id)
    rows = (
        db.execute(
            select(HrContract)
            .where(HrContract.employee_id == employee_id)
            .order_by(HrContract.start_date.desc())
        )
        .scalars()
        .all()
    )
    return [_serialise(c, employee.name if employee else None) for c in rows]


@router.post(
    "",
    response_model=ContractOut,
    status_code=201,
    summary="Create a contract (triggers the overlapping-period guard)",
)
def create_contract(
    payload: ContractCreate, db: DbSession, _: CurrentUser = Depends(require_hr)
) -> ContractOut:
    contract = contract_service.create_contract(
        db,
        employee_id=payload.employee_id,
        start_date=payload.start_date,
        end_date=payload.end_date,
        wage_monthly=payload.wage_monthly,
        department_id=payload.department_id,
        job_position_id=payload.job_position_id,
        working_schedule_id=payload.working_schedule_id,
        salary_structure_id=payload.salary_structure_id,
        status=payload.status.value,
        notes=payload.notes,
    )
    employee = db.get(Employee, contract.employee_id)
    return _serialise(contract, employee.name if employee else None)


@router.get(
    "/{contract_id}",
    response_model=ContractOut,
    summary="Contract detail (EMPLOYEE sees only their own)",
)
def get_contract(contract_id: uuid.UUID, db: DbSession, user: User) -> ContractOut:
    contract = contract_service.get_contract(db, contract_id)
    user.assert_can_read_employee(contract.employee_id)
    employee = db.get(Employee, contract.employee_id)
    return _serialise(contract, employee.name if employee else None)


@router.patch(
    "/{contract_id}",
    response_model=ContractUpdateResult,
    summary=(
        "Correct a contract in place. Wage and dates are frozen once the contract "
        "has produced a validated or paid payslip."
    ),
)
def update_contract(
    contract_id: uuid.UUID,
    payload: ContractUpdate,
    db: DbSession,
    _: CurrentUser = Depends(require_hr),
) -> ContractUpdateResult:
    contract, notes = contract_service.update_contract(
        db, contract_id, payload.model_dump(exclude_unset=True)
    )
    employee = db.get(Employee, contract.employee_id)
    return ContractUpdateResult(
        contract=_serialise(contract, employee.name if employee else None),
        notes=notes,
    )


@router.post(
    "/{contract_id}/revise-wage",
    response_model=ContractRevisionResult,
    summary=(
        "Salary revision: close this contract the day before the effective date "
        "and open a new RUNNING one at the new wage. Earlier periods keep the old "
        "rate."
    ),
)
def revise_wage(
    contract_id: uuid.UUID,
    payload: ContractWageRevision,
    db: DbSession,
    _: CurrentUser = Depends(require_payroll_manager),
) -> ContractRevisionResult:
    result = contract_service.revise_wage(
        db,
        contract_id,
        new_wage=payload.new_wage,
        effective_from=payload.effective_from,
        reason=payload.reason,
    )
    employee = db.get(Employee, result["previous_contract"].employee_id)
    name = employee.name if employee else None
    return ContractRevisionResult(
        previous_contract=_serialise(result["previous_contract"], name),
        new_contract=_serialise(result["new_contract"], name),
        previous_wage=result["previous_wage"],
        new_wage=result["new_wage"],
        effective_from=result["effective_from"],
        note=result["note"],
    )


@router.post(
    "/{contract_id}/status",
    response_model=ContractOut,
    summary="Move a contract through DRAFT -> RUNNING -> EXPIRED / CANCELLED",
)
def set_status(
    contract_id: uuid.UUID,
    payload: ContractStatusUpdate,
    db: DbSession,
    _: CurrentUser = Depends(require_hr),
) -> ContractOut:
    contract = contract_service.set_contract_status(
        db, contract_id, payload.status.value
    )
    employee = db.get(Employee, contract.employee_id)
    return _serialise(contract, employee.name if employee else None)


@router.post(
    "/expire-due",
    response_model=MessageResponse,
    summary="Housekeeping: flip RUNNING contracts past their end date to EXPIRED",
)
def expire_due(
    db: DbSession,
    _: CurrentUser = Depends(require_hr),
    as_of: Optional[date] = Query(default=None),
) -> MessageResponse:
    count = contract_service.expire_due_contracts(db, as_of)
    return MessageResponse(detail=f"{count} contract(s) marked EXPIRED.")
