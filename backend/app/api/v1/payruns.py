"""Payrun 2-step wizard, the compute/validate/pay workflow and payslips."""

from __future__ import annotations

import uuid
from datetime import date
from decimal import Decimal
from typing import Dict, List, Optional

from fastapi import APIRouter, Depends, Query, Response
from sqlalchemy import select
from sqlalchemy.orm import aliased, selectinload

from app.api.deps import DbSession, PageParams, User, scope_employee_filter
from app.core.errors import NotFoundError
from app.core.security import CurrentUser, require_payroll, require_payroll_manager
from app.models.employee import Employee
from app.models.payrun import Payrun, Payslip
from app.models.salary import SalaryStructure
from app.schemas.common import MessageResponse
from app.schemas.payroll import (
    LeaveImpactOut,
    PayrunCreate,
    PayrunDetailOut,
    PayrunOut,
    PayrunScopeRequest,
    PayrunScopeResponse,
    PayslipDetailOut,
    PayslipLineOut,
    PayslipOut,
    SendPayslipsResponse,
)
from app.services import (
    attendance_service,
    email_service,
    payrun_service,
    pdf_service,
)

router = APIRouter(tags=["Payroll"])


def _payrun_out(db, payrun: Payrun) -> PayrunOut:
    structure = db.get(SalaryStructure, payrun.salary_structure_id)
    return PayrunOut(
        id=payrun.id,
        reference_code=payrun.reference_code,
        name=payrun.name,
        salary_structure_id=payrun.salary_structure_id,
        salary_structure_name=structure.name if structure else None,
        date_start=payrun.date_start,
        date_end=payrun.date_end,
        status=payrun.status,
        total_basic=payrun.total_basic,
        total_gross=payrun.total_gross,
        total_net=payrun.total_net,
        employee_count=payrun.employee_count,
        warnings_count=payrun.warnings_count,
        created_at=payrun.created_at,
    )


def _payslip_out(
    payslip: Payslip, employee_name: str | None = None, badge_id: str | None = None
) -> PayslipOut:
    ot_amount = Decimal("0.00")
    if hasattr(payslip, "lines") and payslip.lines:
        for line in payslip.lines:
            if getattr(line, "rule_code", None) == "OT":
                ot_amount = getattr(line, "amount", Decimal("0.00"))
                break

    return PayslipOut(
        id=payslip.id,
        reference_code=payslip.reference_code,
        payrun_id=payslip.payrun_id,
        employee_id=payslip.employee_id,
        employee_name=employee_name,
        badge_id=badge_id,
        contract_id=payslip.contract_id,
        salary_structure_id=payslip.salary_structure_id,
        date_start=payslip.date_start,
        date_end=payslip.date_end,
        worked_days=payslip.worked_days,
        worked_hours=getattr(payslip, "worked_hours", Decimal("0.00")) or Decimal("0.00"),
        overtime_hours=getattr(payslip, "overtime_hours", Decimal("0.00")) or Decimal("0.00"),
        scheduled_hours=payslip.worked_days * Decimal("8.00"),
        overtime_pay=ot_amount,
        basic_amount=payslip.basic_amount,
        gross_amount=payslip.gross_amount,
        net_amount=payslip.net_amount,
        status=payslip.status,
        warning_notes=payslip.warning_notes,
        emailed_at=payslip.emailed_at,
        created_at=payslip.created_at,
    )



# ===========================================================================
# STEP 1 + STEP 2
# ===========================================================================
@router.post(
    "/payruns/step1-validate",
    response_model=PayrunScopeResponse,
    summary="Step 1 wizard validator: returns eligible employees. Writes NOTHING.",
)
def step1_validate(
    payload: PayrunScopeRequest,
    db: DbSession,
    _: CurrentUser = Depends(require_payroll),
) -> PayrunScopeResponse:
    result = payrun_service.validate_payrun_scope(
        db,
        structure_id=payload.salary_structure_id,
        date_start=payload.date_start,
        date_end=payload.date_end,
        department_ids=payload.department_ids,
        employee_ids=payload.employee_ids,
    )
    return PayrunScopeResponse(**result)


@router.post(
    "/payruns",
    response_model=PayrunDetailOut,
    status_code=201,
    summary="Step 2 wizard finalizer: creates the batch and its payslips",
)
def create_payrun(
    payload: PayrunCreate,
    db: DbSession,
    user: CurrentUser = Depends(require_payroll),
) -> PayrunDetailOut:
    payrun = payrun_service.create_payrun_batch(
        db,
        name=payload.name,
        structure_id=payload.salary_structure_id,
        date_start=payload.date_start,
        date_end=payload.date_end,
        selected_employee_ids=payload.employee_ids,
        user_id=user.user_id,
        skip_blocked=payload.skip_blocked,
    )
    return _detail(db, payrun.id)


def _detail(db, payrun_id: uuid.UUID) -> PayrunDetailOut:
    data = payrun_service.payrun_detail(db, payrun_id)
    return PayrunDetailOut(
        payrun=_payrun_out(db, data["payrun"]),
        payslips=[
            _payslip_out(row["payslip"], row["employee_name"], row["badge_id"])
            for row in data["payslips"]
        ],
    )


# ===========================================================================
# LISTING
# ===========================================================================
@router.get(
    "/payruns",
    response_model=List[PayrunOut],
    summary="List payrun batches",
)
def list_payruns(
    db: DbSession,
    page: PageParams,
    _: CurrentUser = Depends(require_payroll),
    status: Optional[str] = Query(default=None),
    year: Optional[int] = Query(default=None, ge=2000, le=2100),
) -> List[PayrunOut]:
    stmt = select(Payrun).order_by(Payrun.date_end.desc())
    if status:
        stmt = stmt.where(Payrun.status == status)
    if year:
        stmt = stmt.where(
            Payrun.date_start >= date(year, 1, 1), Payrun.date_start <= date(year, 12, 31)
        )
    payruns = db.execute(stmt.limit(page.limit).offset(page.offset)).scalars().all()
    return [_payrun_out(db, p) for p in payruns]


@router.get(
    "/payruns/{payrun_id}",
    response_model=PayrunDetailOut,
    summary="Payrun detail with all its payslips",
)
def get_payrun(
    payrun_id: uuid.UUID, db: DbSession, _: CurrentUser = Depends(require_payroll)
) -> PayrunDetailOut:
    return _detail(db, payrun_id)


# ===========================================================================
# WORKFLOW
# ===========================================================================
@router.post(
    "/payruns/{payrun_id}/compute",
    response_model=PayrunDetailOut,
    summary="Mass compute all draft payslips through the salary engine",
)
def compute(
    payrun_id: uuid.UUID, db: DbSession, _: CurrentUser = Depends(require_payroll)
) -> PayrunDetailOut:
    payrun_service.compute_payrun(db, payrun_id)
    return _detail(db, payrun_id)


@router.post(
    "/payruns/{payrun_id}/validate",
    response_model=PayrunDetailOut,
    summary="Validate the batch and lock it for payout",
)
def validate(
    payrun_id: uuid.UUID, db: DbSession, _: CurrentUser = Depends(require_payroll)
) -> PayrunDetailOut:
    payrun_service.validate_payrun(db, payrun_id)
    return _detail(db, payrun_id)


@router.post(
    "/payruns/{payrun_id}/mark-paid",
    response_model=PayrunDetailOut,
    summary="Mark the batch paid (refuses when bank details are missing)",
)
def mark_paid(
    payrun_id: uuid.UUID, db: DbSession, _: CurrentUser = Depends(require_payroll)
) -> PayrunDetailOut:
    payrun_service.mark_payrun_paid(db, payrun_id)
    return _detail(db, payrun_id)


@router.delete(
    "/payruns/{payrun_id}",
    response_model=MessageResponse,
    summary="Delete a DRAFT or COMPUTED batch (paid history is immutable)",
)
def delete_payrun(
    payrun_id: uuid.UUID, db: DbSession, _: CurrentUser = Depends(require_payroll_manager)
) -> MessageResponse:
    payrun_service.delete_payrun(db, payrun_id)
    return MessageResponse(detail="Payrun deleted.")


@router.post(
    "/payruns/{payrun_id}/send-payslips",
    response_model=SendPayslipsResponse,
    summary="Bulk email payslip PDFs to every included employee",
)
def send_payslips(
    payrun_id: uuid.UUID,
    db: DbSession,
    _: CurrentUser = Depends(require_payroll),
    only_unsent: bool = Query(default=True),
) -> SendPayslipsResponse:
    result = email_service.send_payrun_payslips(db, payrun_id, only_unsent=only_unsent)
    return SendPayslipsResponse(**result)


# ===========================================================================
# PAYSLIPS
# ===========================================================================
@router.get(
    "/payslips",
    response_model=List[PayslipOut],
    summary="List payslips (EMPLOYEE filtered to self)",
)
def list_payslips(
    db: DbSession,
    page: PageParams,
    user: User,
    payrun_id: Optional[uuid.UUID] = Query(default=None),
    employee_id: Optional[uuid.UUID] = Query(default=None),
    status: Optional[str] = Query(default=None),
) -> List[PayslipOut]:
    emp = aliased(Employee)
    stmt = (
        select(Payslip, emp.name, emp.badge_id)
        .join(emp, emp.id == Payslip.employee_id)
        .order_by(Payslip.date_end.desc(), emp.badge_id)
    )

    scoped = scope_employee_filter(user)
    if scoped is not None:
        stmt = stmt.where(Payslip.employee_id == scoped)
    elif employee_id:
        stmt = stmt.where(Payslip.employee_id == employee_id)

    if payrun_id:
        stmt = stmt.where(Payslip.payrun_id == payrun_id)
    if status:
        stmt = stmt.where(Payslip.status == status)

    rows = db.execute(stmt.limit(page.limit).offset(page.offset)).all()
    return [_payslip_out(slip, name, badge) for slip, name, badge in rows]


@router.get(
    "/payslips/{payslip_id}",
    response_model=PayslipDetailOut,
    summary="Payslip detail with the rule-by-rule tree (EMPLOYEE self only)",
)
def get_payslip(
    payslip_id: uuid.UUID, db: DbSession, user: User
) -> PayslipDetailOut:
    payslip = db.execute(
        select(Payslip)
        .options(selectinload(Payslip.lines))
        .where(Payslip.id == payslip_id)
    ).scalars().first()
    if not payslip:
        raise NotFoundError(f"Payslip {payslip_id} not found.")

    # Row scoping: an employee may only ever open their own payslip.
    user.assert_can_read_employee(payslip.employee_id)

    employee = db.get(Employee, payslip.employee_id)
    payrun = db.get(Payrun, payslip.payrun_id)
    structure = db.get(SalaryStructure, payslip.salary_structure_id)
    from app.models.contract import HrContract

    contract = db.get(HrContract, payslip.contract_id)

    lines = [PayslipLineOut.model_validate(l) for l in payslip.lines]
    grouped: Dict[str, List[PayslipLineOut]] = {}
    for line in lines:
        grouped.setdefault(line.category.value, []).append(line)

    total_deductions = sum(
        (abs(l.amount) for l in lines if l.category.value == "DEDUCTION"),
        Decimal("0.00"),
    )

    # Time / Leave Impact block: recompute the same attendance + approved-leave
    # figures the salary engine saw for this period, and tie the unpaid-leave
    # deduction to the Loss-of-Pay ('LOP') salary line actually on the slip.
    leave_impact = None
    try:
        att = attendance_service.compute_worked_days_and_hours(
            db,
            payslip.employee_id,
            payslip.date_start,
            payslip.date_end,
            employee.working_schedule_id if employee else None,
        )
        lop_amount = next(
            (abs(l.amount) for l in lines if l.rule_code == "LOP"),
            Decimal("0.00"),
        )
        leave_impact = LeaveImpactOut(
            worked_days=payslip.worked_days,
            expected_days=att.get("expected_days", Decimal("0.00")),
            approved_leave_days=att.get("leave_days", Decimal("0.00")),
            paid_leave_days=att.get("paid_leave_days", Decimal("0.00")),
            unpaid_leave_days=att.get("unpaid_leave_days", Decimal("0.00")),
            absent_days=att.get("absent_days", Decimal("0.00")),
            unpaid_leave_deduction=lop_amount,
        )
    except Exception:  # noqa: BLE001 - leave impact is informational, never fatal
        leave_impact = None

    base = _payslip_out(
        payslip,
        employee.name if employee else None,
        employee.badge_id if employee else None,
    )
    return PayslipDetailOut(
        **base.model_dump(),
        payrun_reference=payrun.reference_code if payrun else None,
        payrun_name=payrun.name if payrun else None,
        contract_reference=contract.reference_code if contract else None,
        salary_structure_name=structure.name if structure else None,
        department=(
            employee.department.name if employee and employee.department else None
        ),
        job_position=(
            employee.job_position.name if employee and employee.job_position else None
        ),
        total_deductions=total_deductions,
        lines=lines,
        grouped_lines=grouped,
        leave_impact=leave_impact,
    )


@router.get(
    "/payslips/{payslip_id}/pdf",
    summary="Generate and stream the official A4 payslip PDF (EMPLOYEE self only)",
    response_class=Response,
    responses={200: {"content": {"application/pdf": {}}}},
)
def get_payslip_pdf(payslip_id: uuid.UUID, db: DbSession, user: User) -> Response:
    payslip = db.get(Payslip, payslip_id)
    if not payslip:
        raise NotFoundError(f"Payslip {payslip_id} not found.")
    user.assert_can_read_employee(payslip.employee_id)

    pdf_bytes = pdf_service.build_payslip_pdf(db, payslip_id)
    filename = pdf_service.payslip_filename(db, payslip_id)
    return Response(
        content=pdf_bytes,
        media_type="application/pdf",
        headers={
            "Content-Disposition": f'inline; filename="{filename}"',
            "Content-Length": str(len(pdf_bytes)),
        },
    )
