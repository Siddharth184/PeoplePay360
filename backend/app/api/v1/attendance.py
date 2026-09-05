"""Attendance: the punch toggle, the master log and HR corrections."""

from __future__ import annotations

import uuid
from datetime import date, datetime, time, timezone
from decimal import Decimal
from typing import List, Optional

from fastapi import APIRouter, Depends, Query
from sqlalchemy import select
from sqlalchemy.orm import aliased

from app.api.deps import (
    DbSession,
    PageParams,
    User,
    require_linked_employee,
    resolve_target_employee,
    scope_employee_filter,
)
from app.core.errors import NotFoundError
from app.core.security import CurrentUser, require_hr
from app.models.attendance import Attendance
from app.models.employee import Employee
from app.schemas.hr import (
    AttendanceManualUpsert,
    AttendanceOut,
    AttendanceSummaryOut,
    PunchRequest,
    PunchResponse,
)
from app.services import attendance_service

router = APIRouter(prefix="/attendance", tags=["Attendance"])


def _serialise(record: Attendance, employee_name: str | None = None) -> AttendanceOut:
    return AttendanceOut(
        id=record.id,
        employee_id=record.employee_id,
        employee_name=employee_name,
        check_in=record.check_in,
        check_out=record.check_out,
        worked_hours=record.worked_hours,
        overtime_hours=record.overtime_hours,
        status=record.status,
        is_manual_edit=record.is_manual_edit,
        audit_notes=record.audit_notes,
        created_at=record.created_at,
    )


@router.post(
    "/punch",
    response_model=PunchResponse,
    summary="Quick Check-In / Check-Out toggle with elapsed timer",
)
def punch(payload: PunchRequest, db: DbSession, user: User) -> PunchResponse:
    # HR may punch on someone's behalf; everyone else is pinned to themselves.
    employee_id = resolve_target_employee(user, payload.employee_id)
    result = attendance_service.punch(
        db, employee_id, at=payload.at, note=payload.note
    )
    record: Attendance = result["attendance"]
    employee = db.get(Employee, employee_id)

    elapsed: Optional[Decimal] = None
    if record.check_out is None:
        seconds = (datetime.now(timezone.utc) - record.check_in).total_seconds()
        elapsed = Decimal(str(round(seconds / 3600, 2)))
    else:
        elapsed = record.worked_hours

    return PunchResponse(
        action=result["action"],
        attendance=_serialise(record, employee.name if employee else None),
        elapsed_hours=elapsed,
    )


@router.get(
    "/status",
    summary="Is the caller currently clocked in?",
)
def punch_status(db: DbSession, user: User) -> dict:
    employee_id = require_linked_employee(user)
    open_punch = attendance_service.get_open_punch(db, employee_id)
    if not open_punch:
        return {"checked_in": False, "since": None, "elapsed_hours": 0}
    seconds = (datetime.now(timezone.utc) - open_punch.check_in).total_seconds()
    return {
        "checked_in": True,
        "attendance_id": str(open_punch.id),
        "since": open_punch.check_in,
        "elapsed_hours": round(seconds / 3600, 2),
    }


@router.get(
    "",
    response_model=List[AttendanceOut],
    summary="Master attendance log (EMPLOYEE filtered to self)",
)
def list_attendance(
    db: DbSession,
    page: PageParams,
    user: User,
    employee_id: Optional[uuid.UUID] = Query(default=None),
    date_from: Optional[date] = Query(default=None),
    date_to: Optional[date] = Query(default=None),
    status: Optional[str] = Query(default=None),
    manual_only: bool = Query(default=False),
) -> List[AttendanceOut]:
    emp = aliased(Employee)
    stmt = (
        select(Attendance, emp.name)
        .join(emp, emp.id == Attendance.employee_id)
        .order_by(Attendance.check_in.desc())
    )

    # Row scoping happens here, server-side.
    scoped = scope_employee_filter(user)
    if scoped is not None:
        stmt = stmt.where(Attendance.employee_id == scoped)
    elif employee_id:
        stmt = stmt.where(Attendance.employee_id == employee_id)

    if date_from:
        stmt = stmt.where(
            Attendance.check_in >= datetime.combine(date_from, time.min, tzinfo=timezone.utc)
        )
    if date_to:
        stmt = stmt.where(
            Attendance.check_in <= datetime.combine(date_to, time.max, tzinfo=timezone.utc)
        )
    if status:
        stmt = stmt.where(Attendance.status == status)
    if manual_only:
        stmt = stmt.where(Attendance.is_manual_edit.is_(True))

    rows = db.execute(stmt.limit(page.limit).offset(page.offset)).all()
    return [_serialise(record, name) for record, name in rows]


@router.get(
    "/summary",
    response_model=AttendanceSummaryOut,
    summary="Worked vs expected days, overtime and unexplained absences",
)
def summary(
    db: DbSession,
    user: User,
    date_start: date = Query(...),
    date_end: date = Query(...),
    employee_id: Optional[uuid.UUID] = Query(default=None),
) -> AttendanceSummaryOut:
    target = resolve_target_employee(user, employee_id)
    data = attendance_service.attendance_summary(db, target, date_start, date_end)
    return AttendanceSummaryOut(**data)


@router.post(
    "/manual",
    response_model=AttendanceOut,
    status_code=201,
    summary="HR correction: create a punch by hand (stamped is_manual_edit)",
)
def create_manual(
    payload: AttendanceManualUpsert,
    db: DbSession,
    _: CurrentUser = Depends(require_hr),
) -> AttendanceOut:
    record = attendance_service.manual_upsert(
        db,
        employee_id=payload.employee_id,
        check_in=payload.check_in,
        check_out=payload.check_out,
        status=payload.status.value if payload.status else None,
        audit_notes=payload.audit_notes,
    )
    employee = db.get(Employee, record.employee_id)
    return _serialise(record, employee.name if employee else None)


@router.put(
    "/{attendance_id}",
    response_model=AttendanceOut,
    summary="HR correction: edit an existing punch",
)
def update_manual(
    attendance_id: uuid.UUID,
    payload: AttendanceManualUpsert,
    db: DbSession,
    _: CurrentUser = Depends(require_hr),
) -> AttendanceOut:
    record = attendance_service.manual_upsert(
        db,
        attendance_id=attendance_id,
        employee_id=payload.employee_id,
        check_in=payload.check_in,
        check_out=payload.check_out,
        status=payload.status.value if payload.status else None,
        audit_notes=payload.audit_notes,
    )
    employee = db.get(Employee, record.employee_id)
    return _serialise(record, employee.name if employee else None)


@router.delete(
    "/{attendance_id}",
    summary="Delete a punch (HR only; always leaves an audit note behind)",
)
def delete_attendance(
    attendance_id: uuid.UUID, db: DbSession, _: CurrentUser = Depends(require_hr)
) -> dict:
    record = db.get(Attendance, attendance_id)
    if not record:
        raise NotFoundError(f"Attendance record {attendance_id} not found.")
    db.delete(record)
    db.commit()
    return {"detail": "Attendance record deleted."}
