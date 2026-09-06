"""Unit tests for contract compensation revision and payroll assignments."""

from __future__ import annotations

import uuid
from datetime import date

import pytest
from fastapi import FastAPI
from fastapi.testclient import TestClient

from app.api.v1 import contracts as contracts_router
from app.core.database import get_db
from app.core.errors import ConflictError, ValidationError, register_exception_handlers
from app.core.security import CurrentUser, get_current_user
from app.models.contract import HrContract
from app.models.enums import ContractStatus, UserRole
from app.models.salary import SalaryStructure
from app.services import contract_service

app = FastAPI()
register_exception_handlers(app)
app.include_router(contracts_router.router, prefix="/api/v1")


def _principal(role: str, employee_id=None) -> CurrentUser:
    return CurrentUser(
        {
            "sub": str(uuid.uuid4()),
            "email": "manager@test.local",
            "role": role,
            "employee_id": str(employee_id) if employee_id else None,
        }
    )


@pytest.fixture()
def client(db):
    app.dependency_overrides[get_db] = lambda: db
    try:
        yield TestClient(app, raise_server_exceptions=True)
    finally:
        app.dependency_overrides.clear()


def test_service_revise_compensation(db, employee):
    contract = HrContract(
        reference_code="CON/TEST/001",
        employee_id=employee.id,
        start_date=date(2026, 1, 1),
        end_date=None,
        wage_monthly=80000.0,
        status="RUNNING",
        notes="Initial contract",
    )
    db.add(contract)
    db.flush()

    res = contract_service.revise_compensation(
        db,
        contract.id,
        new_wage=95000.0,
        effective_from=date(2026, 6, 1),
        reason="Mid-year appraisal",
    )

    db.refresh(contract)
    assert contract.status == "EXPIRED"
    assert contract.end_date == date(2026, 5, 31)

    new_c = res["new_contract"]
    assert new_c.status == "RUNNING"
    assert new_c.start_date == date(2026, 6, 1)
    assert float(new_c.wage_monthly) == 95000.0
    assert new_c.employee_id == employee.id


def test_service_revise_compensation_validation_errors(db, employee):
    contract = HrContract(
        reference_code="CON/TEST/002",
        employee_id=employee.id,
        start_date=date(2026, 1, 1),
        end_date=None,
        wage_monthly=80000.0,
        status="RUNNING",
    )
    db.add(contract)
    db.flush()

    # Invalid effective_from before start_date
    with pytest.raises(ValidationError):
        contract_service.revise_compensation(
            db,
            contract.id,
            new_wage=90000.0,
            effective_from=date(2025, 12, 31),
        )

    # Invalid non-positive wage
    with pytest.raises(ValidationError):
        contract_service.revise_compensation(
            db,
            contract.id,
            new_wage=-500,
            effective_from=date(2026, 3, 1),
        )


def test_api_revise_compensation_rbac(client, db, employee):
    contract = HrContract(
        reference_code="CON/TEST/003",
        employee_id=employee.id,
        start_date=date(2026, 1, 1),
        wage_monthly=75000.0,
        status="RUNNING",
    )
    db.add(contract)
    db.flush()

    # Read-only user should be forbidden
    app.dependency_overrides[get_current_user] = lambda: _principal(
        UserRole.HR_PAYROLL_USER.value
    )
    resp = client.post(
        f"/api/v1/contracts/{contract.id}/revise-compensation",
        json={"new_wage": 88000, "effective_from": "2026-07-01", "reason": "Test"},
    )
    assert resp.status_code == 403

    # Payroll Manager should succeed
    app.dependency_overrides[get_current_user] = lambda: _principal(
        UserRole.HR_PAYROLL_MANAGER.value
    )
    resp = client.post(
        f"/api/v1/contracts/{contract.id}/revise-compensation",
        json={"new_wage": 88000, "effective_from": "2026-07-01", "reason": "Test"},
    )
    assert resp.status_code == 200
    data = resp.json()
    assert float(data["new_wage"]) == 88000.0
    assert data["previous_contract"]["status"] == "EXPIRED"
    assert data["new_contract"]["status"] == "RUNNING"
