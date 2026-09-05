"""Dynamic Working Schedule & Attendance Calculation Engine (section 3.2).

Two halves:
  * **Expected** working days/hours, derived from the employee's assigned
    `working_schedule` lines minus public holidays. This is the denominator for
    proration and the baseline for overtime.
  * **Actual** worked days/hours/overtime, derived from check-in logs.
"""

from __future__ import annotations

import uuid
from datetime import date, datetime, time, timedelta, timezone
from decimal import Decimal
from typing import Any, Dict, Sequence

from sqlalchemy import select
from sqlalchemy.orm import Session

from app.core.errors import ConflictError, NotFoundError, ValidationError
from app.models.attendance import Attendance
from app.models.employee import Employee
from app.models.master import PublicHoliday, WorkingSchedule, WorkingScheduleLine
from app.models.timeoff import LeaveRequest
from app.services.salary_engine import ZERO, to_decimal

LATE_GRACE_MINUTES = 15
HALF_DAY_RATIO = Decimal("0.5")


# ---------------------------------------------------------------------------
# EXPECTED SIDE: what the schedule says the employee owes
# ---------------------------------------------------------------------------
def _holiday_dates(db: Session, date_start: date, date_end: date) -> set[date]:
    rows = db.execute(
        select(PublicHoliday.holiday_date).where(
            PublicHoliday.holiday_date.between(date_start, date_end)
        )
    ).scalars()
    return set(rows)


def compute_expected_schedule(
    db: Session,
    schedule_id: uuid.UUID | str | None,
    date_start: date,
    date_end: date,
) -> Dict[str, Any]:
    """Expand a working schedule across a period into expected days and hours."""
    if date_end < date_start:
        raise ValidationError("date_end cannot precede date_start.")

    if not schedule_id:
        # No schedule assigned: fall back to a Mon-Fri 8h calendar so payroll can
        # still prorate instead of dividing by zero.
        expected_days = sum(
            1
            for offset in range((date_end - date_start).days + 1)
            if (date_start + timedelta(days=offset)).weekday() < 5
        )
        return {
            "schedule_name": None,
            "expected_days": Decimal(expected_days),
            "expected_hours": Decimal(expected_days) * Decimal("8.00"),
            "hours_per_day_by_dow": {},
            "holidays": 0,
        }

    schedule = db.get(WorkingSchedule, schedule_id)
    if not schedule:
        raise NotFoundError(f"Working schedule {schedule_id} not found.")

    lines: Sequence[WorkingScheduleLine] = (
        db.execute(
            select(WorkingScheduleLine).where(
                WorkingScheduleLine.schedule_id == schedule.id
            )
        )
        .scalars()
        .all()
    )

    hours_by_dow: Dict[int, Decimal] = {}
    starts_by_dow: Dict[int, time] = {}
    for line in lines:
        hours_by_dow[line.day_of_week] = hours_by_dow.get(
            line.day_of_week, ZERO
        ) + to_decimal(line.work_hours or 0)
        current = starts_by_dow.get(line.day_of_week)
        if current is None or line.start_time < current:
            starts_by_dow[line.day_of_week] = line.start_time

    holidays = _holiday_dates(db, date_start, date_end)

    expected_days = ZERO
    expected_hours = ZERO
    for offset in range((date_end - date_start).days + 1):
        day = date_start + timedelta(days=offset)
        if day in holidays:
            continue
        day_hours = hours_by_dow.get(day.weekday())
        if day_hours:
            expected_days += Decimal(1)
            expected_hours += day_hours

    return {
        "schedule_name": schedule.name,
        "expected_days": expected_days,
        "expected_hours": expected_hours,
        "hours_per_day_by_dow": {k: str(v) for k, v in hours_by_dow.items()},
        "expected_start_by_dow": starts_by_dow,
        "holidays": len(holidays),
    }


# ---------------------------------------------------------------------------
# ACTUAL SIDE: what the punches say happened
# ---------------------------------------------------------------------------
def compute_worked_days_and_hours(
    db: Session,
    employee_id: uuid.UUID | str,
    date_start: date,
    date_end: date,
    schedule_id: uuid.UUID | str | None = None,
) -> Dict[str, Any]:
    """Actual worked days/hours plus overtime, measured against the schedule."""
    window_start = datetime.combine(date_start, time.min, tzinfo=timezone.utc)
    window_end = datetime.combine(date_end, time.max, tzinfo=timezone.utc)

    records: Sequence[Attendance] = (
        db.execute(
            select(Attendance).where(
                Attendance.employee_id == employee_id,
                Attendance.check_in >= window_start,
                Attendance.check_in <= window_end,
                Attendance.status.in_(["PRESENT", "LATE", "HALF_DAY"]),
            )
        )
        .scalars()
        .all()
    )

    total_worked_hours = sum((to_decimal(r.worked_hours) for r in records), ZERO)
    total_overtime_hours = sum((to_decimal(r.overtime_hours) for r in records), ZERO)

    distinct_days = {r.check_in.date() for r in records}
    half_days = {r.check_in.date() for r in records if r.status == "HALF_DAY"}
    # A day that has ANY full punch counts as full, even if it also has a
    # half-day punch, so an employee is never penalised twice.
    full_days = distinct_days - half_days

    adjusted_worked_days = Decimal(len(full_days)) + (
        Decimal(len(half_days)) * HALF_DAY_RATIO
    )

    expected = compute_expected_schedule(db, schedule_id, date_start, date_end)
    leave_days = approved_leave_days(db, employee_id, date_start, date_end)

    return {
        "worked_days": adjusted_worked_days,
        "expected_days": expected["expected_days"],
        "expected_hours": expected["expected_hours"],
        "total_worked_hours": total_worked_hours,
        "total_overtime_hours": total_overtime_hours,
        "leave_days": leave_days,
        "absent_days": max(
            ZERO, expected["expected_days"] - adjusted_worked_days - leave_days
        ),
        "late_punches": sum(1 for r in records if r.status == "LATE"),
        "half_day_count": len(half_days),
        "present_punches": len(records),
    }


def approved_leave_days(
    db: Session, employee_id: uuid.UUID | str, date_start: date, date_end: date
) -> Decimal:
    """Approved leave overlapping the period, clipped to the period bounds."""
    requests = (
        db.execute(
            select(LeaveRequest).where(
                LeaveRequest.employee_id == employee_id,
                LeaveRequest.status == "APPROVED",
                LeaveRequest.start_date <= date_end,
                LeaveRequest.end_date >= date_start,
            )
        )
        .scalars()
        .all()
    )

    total = ZERO
    for req in requests:
        overlap_start = max(req.start_date, date_start)
        overlap_end = min(req.end_date, date_end)
        overlap_days = Decimal((overlap_end - overlap_start).days + 1)
        span_days = Decimal((req.end_date - req.start_date).days + 1)
        # Prorate the recorded duration across the overlapping portion so a leave
        # straddling two payruns is not counted twice in either.
        total += (to_decimal(req.duration_days) * overlap_days) / span_days
    return total


# ---------------------------------------------------------------------------
# PUNCH TOGGLE
# ---------------------------------------------------------------------------
def get_open_punch(db: Session, employee_id: uuid.UUID | str) -> Attendance | None:
    return db.execute(
        select(Attendance)
        .where(Attendance.employee_id == employee_id, Attendance.check_out.is_(None))
        .order_by(Attendance.check_in.desc())
    ).scalars().first()


def _expected_start_for(
    db: Session, employee: Employee, moment: datetime
) -> time | None:
    if not employee.working_schedule_id:
        return None
    expected = compute_expected_schedule(
        db, employee.working_schedule_id, moment.date(), moment.date()
    )
    return (expected.get("expected_start_by_dow") or {}).get(moment.weekday())


def punch(
    db: Session,
    employee_id: uuid.UUID | str,
    *,
    at: datetime | None = None,
    note: str | None = None,
) -> Dict[str, Any]:
    """Quick Check-In / Check-Out toggle.

    An employee may only ever have one open punch: enforced by the partial unique
    index `idx_attendance_single_open`, so concurrent double-taps cannot both win.
    """
    employee = db.get(Employee, employee_id)
    if not employee:
        raise NotFoundError(f"Employee {employee_id} not found.")
    if employee.status != "ACTIVE":
        raise ConflictError(
            f"{employee.name} is {employee.status}; attendance cannot be recorded."
        )

    moment = at or datetime.now(timezone.utc)
    open_punch = get_open_punch(db, employee_id)

    if open_punch is None:
        expected_start = _expected_start_for(db, employee, moment)
        status = "PRESENT"
        if expected_start is not None:
            local_time = moment.timetz().replace(tzinfo=None)
            grace = (
                datetime.combine(date.min, expected_start)
                + timedelta(minutes=LATE_GRACE_MINUTES)
            ).time()
            if local_time > grace:
                status = "LATE"

        record = Attendance(
            employee_id=employee.id,
            check_in=moment,
            status=status,
            worked_hours=ZERO,
            overtime_hours=ZERO,
            audit_notes=note,
        )
        db.add(record)
        db.commit()
        db.refresh(record)
        return {"action": "CHECK_IN", "attendance": record}

    if moment < open_punch.check_in:
        raise ValidationError("Check-out time cannot precede check-in time.")

    open_punch.check_out = moment
    worked = to_decimal(
        (moment - open_punch.check_in).total_seconds() / 3600
    ).quantize(Decimal("0.01"))

    expected = compute_expected_schedule(
        db,
        employee.working_schedule_id,
        open_punch.check_in.date(),
        open_punch.check_in.date(),
    )
    expected_hours = to_decimal(expected["expected_hours"])

    open_punch.worked_hours = worked
    open_punch.overtime_hours = max(ZERO, worked - expected_hours) if expected_hours else ZERO

    if expected_hours and worked < (expected_hours * HALF_DAY_RATIO):
        open_punch.status = "HALF_DAY"

    if note:
        open_punch.audit_notes = (
            f"{open_punch.audit_notes}\n{note}" if open_punch.audit_notes else note
        )

    db.commit()
    db.refresh(open_punch)
    return {"action": "CHECK_OUT", "attendance": open_punch}


def manual_upsert(
    db: Session,
    *,
    employee_id: uuid.UUID | str,
    check_in: datetime,
    check_out: datetime | None,
    status: str | None,
    audit_notes: str | None,
    attendance_id: uuid.UUID | str | None = None,
) -> Attendance:
    """HR correction path. Always stamped `is_manual_edit` for the audit trail."""
    if check_out and check_out < check_in:
        raise ValidationError("check_out cannot precede check_in.")

    record = db.get(Attendance, attendance_id) if attendance_id else None
    if attendance_id and not record:
        raise NotFoundError(f"Attendance record {attendance_id} not found.")

    if record is None:
        record = Attendance(employee_id=employee_id, check_in=check_in)
        db.add(record)

    record.check_in = check_in
    record.check_out = check_out
    record.status = status or record.status or "PRESENT"
    record.is_manual_edit = True
    record.audit_notes = audit_notes

    if check_out:
        employee = db.get(Employee, employee_id)
        worked = to_decimal(
            (check_out - check_in).total_seconds() / 3600
        ).quantize(Decimal("0.01"))
        expected = compute_expected_schedule(
            db,
            employee.working_schedule_id if employee else None,
            check_in.date(),
            check_in.date(),
        )
        expected_hours = to_decimal(expected["expected_hours"])
        record.worked_hours = worked
        record.overtime_hours = (
            max(ZERO, worked - expected_hours) if expected_hours else ZERO
        )

    db.commit()
    db.refresh(record)
    return record


def attendance_summary(
    db: Session, employee_id: uuid.UUID | str, date_start: date, date_end: date
) -> Dict[str, Any]:
    employee = db.get(Employee, employee_id)
    if not employee:
        raise NotFoundError(f"Employee {employee_id} not found.")
    data = compute_worked_days_and_hours(
        db, employee_id, date_start, date_end, employee.working_schedule_id
    )
    data["employee_id"] = str(employee.id)
    data["employee_name"] = employee.name
    data["date_start"] = date_start
    data["date_end"] = date_end
    return data
