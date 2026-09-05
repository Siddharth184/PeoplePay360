"""Punch state-machine tests for attendance_service.

Covers the toggle semantics, the single-open-punch guarantee, the inactive
employee guard and the status helper. These exercise the service directly
against PostgreSQL so the partial unique index and row locking are real.
"""

from __future__ import annotations

from datetime import datetime, timedelta, timezone

import pytest

from app.core.errors import ConflictError, ValidationError
from app.models.attendance import Attendance
from app.services import attendance_service


def _open_count(db, employee_id) -> int:
    return (
        db.query(Attendance)
        .filter(Attendance.employee_id == employee_id, Attendance.check_out.is_(None))
        .count()
    )


def test_first_punch_creates_open_attendance(db, employee):
    result = attendance_service.punch(db, employee.id)

    assert result["action"] == "CHECK_IN"
    record = result["attendance"]
    assert record.check_out is None
    assert record.employee_id == employee.id
    assert _open_count(db, employee.id) == 1


def test_second_punch_closes_same_attendance(db, employee):
    first = attendance_service.punch(db, employee.id)["attendance"]
    first_id = first.id

    # Close it a bit later so worked_hours is positive.
    later = datetime.now(timezone.utc) + timedelta(hours=8)
    result = attendance_service.punch(db, employee.id, at=later)

    assert result["action"] == "CHECK_OUT"
    closed = result["attendance"]
    assert closed.id == first_id
    assert closed.check_out is not None
    assert closed.worked_hours is not None and closed.worked_hours > 0
    assert closed.overtime_hours is not None
    assert _open_count(db, employee.id) == 0


def test_third_punch_creates_new_open_attendance(db, employee):
    # check in
    attendance_service.punch(db, employee.id)
    # check out
    attendance_service.punch(
        db, employee.id, at=datetime.now(timezone.utc) + timedelta(hours=8)
    )
    # third punch -> a brand new open row
    result = attendance_service.punch(
        db, employee.id, at=datetime.now(timezone.utc) + timedelta(hours=9)
    )

    assert result["action"] == "CHECK_IN"
    assert result["attendance"].check_out is None
    assert _open_count(db, employee.id) == 1


def test_cannot_create_two_open_rows_via_direct_insert(db, employee):
    """The partial unique index rejects a second open punch.

    This simulates the race a double-tap would cause if two check-ins slipped
    past the application-level check at the same instant: the database must be
    the last line of defence.
    """
    attendance_service.punch(db, employee.id)
    assert _open_count(db, employee.id) == 1

    dup = Attendance(
        employee_id=employee.id,
        check_in=datetime.now(timezone.utc),
        status="PRESENT",
    )
    db.add(dup)
    from sqlalchemy.exc import IntegrityError

    with pytest.raises(IntegrityError):
        db.flush()
    db.rollback()


def test_inactive_employee_cannot_punch(db, make_employee):
    inactive = make_employee(name="Inactive Person", status="INACTIVE")
    with pytest.raises(ConflictError) as exc:
        attendance_service.punch(db, inactive.id)
    assert "inactive or terminated" in str(exc.value).lower()
    assert _open_count(db, inactive.id) == 0


def test_terminated_employee_cannot_punch(db, make_employee):
    terminated = make_employee(name="Gone Person", status="TERMINATED")
    with pytest.raises(ConflictError):
        attendance_service.punch(db, terminated.id)


def test_checkout_before_checkin_is_rejected(db, employee):
    checked_in = attendance_service.punch(db, employee.id)["attendance"]
    before = checked_in.check_in - timedelta(hours=1)
    with pytest.raises(ValidationError) as exc:
        attendance_service.punch(db, employee.id, at=before)
    assert "punch in" in str(exc.value).lower()
    # The open punch is untouched.
    assert _open_count(db, employee.id) == 1


def test_get_open_punch_reflects_state(db, employee):
    assert attendance_service.get_open_punch(db, employee.id) is None

    attendance_service.punch(db, employee.id)
    open_punch = attendance_service.get_open_punch(db, employee.id)
    assert open_punch is not None
    assert open_punch.check_out is None

    attendance_service.punch(
        db, employee.id, at=datetime.now(timezone.utc) + timedelta(hours=8)
    )
    assert attendance_service.get_open_punch(db, employee.id) is None


def test_two_employees_have_independent_open_punches(db, employee, other_employee):
    attendance_service.punch(db, employee.id)
    attendance_service.punch(db, other_employee.id)

    assert _open_count(db, employee.id) == 1
    assert _open_count(db, other_employee.id) == 1
