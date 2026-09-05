"""API-level tests for the attendance punch endpoints and role scoping.

These use FastAPI's TestClient with ``get_db`` and ``get_current_user``
overridden so we can act as a specific EMPLOYEE or HR user without minting real
JWTs. The TestClient is created WITHOUT its context manager so the app lifespan
(which warms up the embedding model and LLM provider) does not run.
"""

from __future__ import annotations

import uuid

import pytest
from fastapi.testclient import TestClient

from fastapi import FastAPI

from app.api.v1 import attendance as attendance_router
from app.core.database import get_db
from app.core.errors import register_exception_handlers
from app.core.security import CurrentUser, get_current_user
from app.models.enums import UserRole

# A minimal app mounting ONLY the attendance router. This deliberately avoids
# app.main, whose lifespan warms up the embedding model and LLM provider (heavy,
# and irrelevant to attendance). Exception handlers are registered so domain
# errors (403/409/422) map to the same status codes as production.
app = FastAPI()
register_exception_handlers(app)
app.include_router(attendance_router.router, prefix="/api/v1")


def _principal(role: str, employee_id) -> CurrentUser:
    """Build a CurrentUser without decoding a token."""
    return CurrentUser(
        {
            "sub": str(uuid.uuid4()),
            "email": "actor@test.local",
            "role": role,
            "employee_id": str(employee_id) if employee_id else None,
        }
    )


@pytest.fixture()
def client(db):
    """TestClient wired to the rolled-back test session."""
    app.dependency_overrides[get_db] = lambda: db
    try:
        yield TestClient(app, raise_server_exceptions=True)
    finally:
        app.dependency_overrides.clear()


def _act_as(role: str, employee_id):
    app.dependency_overrides[get_current_user] = lambda: _principal(role, employee_id)


def test_status_reports_not_checked_in(client, employee):
    _act_as(UserRole.EMPLOYEE.value, employee.id)
    resp = client.get("/api/v1/attendance/status")
    assert resp.status_code == 200
    assert resp.json()["checked_in"] is False


def test_employee_punch_in_then_status_true(client, employee):
    _act_as(UserRole.EMPLOYEE.value, employee.id)

    punch = client.post("/api/v1/attendance/punch", json={})
    assert punch.status_code == 200
    body = punch.json()
    assert body["action"] == "CHECK_IN"
    assert body["attendance"]["check_out"] is None

    status = client.get("/api/v1/attendance/status")
    assert status.status_code == 200
    assert status.json()["checked_in"] is True


def _db_from(client):
    """The overridden get_db returns our test session; fetch it back for asserts."""
    return app.dependency_overrides[get_db]()


def test_employee_cannot_punch_for_another_employee(client, employee, other_employee):
    _act_as(UserRole.EMPLOYEE.value, employee.id)
    resp = client.post(
        "/api/v1/attendance/punch",
        json={"employee_id": str(other_employee.id)},
    )
    assert resp.status_code == 403
    # And nothing was created for the target.
    from tests.test_attendance_punch import _open_count

    assert _open_count(_db_from(client), other_employee.id) == 0


def test_hr_can_punch_for_another_employee(client, employee, other_employee):
    _act_as(UserRole.HR_PAYROLL_MANAGER.value, employee.id)
    resp = client.post(
        "/api/v1/attendance/punch",
        json={"employee_id": str(other_employee.id)},
    )
    assert resp.status_code == 200
    assert resp.json()["attendance"]["employee_id"] == str(other_employee.id)


def test_hr_manual_create_is_marked_manual(client, employee, other_employee):
    _act_as(UserRole.HR_PAYROLL_MANAGER.value, employee.id)
    resp = client.post(
        "/api/v1/attendance/manual",
        json={
            "employee_id": str(other_employee.id),
            "check_in": "2024-01-02T09:00:00+00:00",
            "check_out": "2024-01-02T17:00:00+00:00",
            "status": "PRESENT",
            "audit_notes": "Forgot to punch out",
        },
    )
    assert resp.status_code == 201
    body = resp.json()
    assert body["is_manual_edit"] is True
    assert body["employee_id"] == str(other_employee.id)


def test_employee_cannot_manual_create(client, employee):
    _act_as(UserRole.EMPLOYEE.value, employee.id)
    resp = client.post(
        "/api/v1/attendance/manual",
        json={
            "employee_id": str(employee.id),
            "check_in": "2024-01-02T09:00:00+00:00",
        },
    )
    assert resp.status_code == 403


def test_double_punch_in_never_creates_two_open_rows(client, employee):
    """Two check-ins in a row must not both open a punch.

    The second call sees the open punch and closes it (toggle), so at no point
    are there two open rows.
    """
    _act_as(UserRole.EMPLOYEE.value, employee.id)

    first = client.post("/api/v1/attendance/punch", json={})
    assert first.status_code == 200
    assert first.json()["action"] == "CHECK_IN"

    second = client.post("/api/v1/attendance/punch", json={})
    assert second.status_code == 200
    # Toggle semantics: the immediate second tap closes the same punch.
    assert second.json()["action"] == "CHECK_OUT"

    from tests.test_attendance_punch import _open_count

    assert _open_count(_db_from(client), employee.id) == 0
