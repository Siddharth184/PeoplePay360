"""Domain exceptions and their HTTP translation.

Services raise domain errors; they never import FastAPI. The exception handlers
registered in main.py map them onto status codes, so business logic stays
transport-agnostic and unit-testable.
"""

from __future__ import annotations

from fastapi import FastAPI, Request, status
from fastapi.responses import JSONResponse
from sqlalchemy.exc import IntegrityError


class DomainError(Exception):
    """Base class. Carries the HTTP status the transport layer should use."""

    status_code = status.HTTP_400_BAD_REQUEST
    code = "domain_error"

    def __init__(self, message: str, *, details: dict | None = None) -> None:
        super().__init__(message)
        self.message = message
        self.details = details or {}


class NotFoundError(DomainError):
    status_code = status.HTTP_404_NOT_FOUND
    code = "not_found"


class ValidationError(DomainError):
    status_code = status.HTTP_422_UNPROCESSABLE_ENTITY
    code = "validation_error"


class ConflictError(DomainError):
    status_code = status.HTTP_409_CONFLICT
    code = "conflict"


class ForbiddenError(DomainError):
    status_code = status.HTTP_403_FORBIDDEN
    code = "forbidden"


class WorkflowError(DomainError):
    """An operation that is illegal in the record's current state."""

    status_code = status.HTTP_409_CONFLICT
    code = "invalid_workflow_state"


class RuleExecutionError(DomainError):
    """A salary rule failed to compile or evaluate safely."""

    status_code = status.HTTP_422_UNPROCESSABLE_ENTITY
    code = "salary_rule_error"


# Postgres constraint name -> human explanation. Keeps database guarantees and
# API messages in sync instead of leaking raw driver text to clients.
_CONSTRAINT_MESSAGES = {
    "uq_payslip_run_employee": "This employee already has a payslip in this payrun.",
    "chk_taken_le_alloc": "Leave taken cannot exceed the allocated balance.",
    "idx_attendance_single_open": "You already have an open attendance punch. Check out first.",
    "chk_check_in_out": "Check-out time cannot be earlier than check-in time.",
    "chk_dates": "The contract end date cannot precede its start date.",
    "chk_leave_dates": "The leave end date cannot precede its start date.",
    "chk_answer_completeness": "An answered ticket must carry answer text, author and timestamp.",
    "chk_assignment_completeness": "An assigned ticket must have an assignee.",
    "chk_rule_inputs": "This salary rule is missing the inputs its computation type requires.",
    "chk_not_self_manager": "An employee cannot be their own manager.",
    "auth_users_email_key": "That email address is already registered.",
    "employees_badge_id_key": "That badge ID is already in use.",
    "employees_work_email_key": "That work email is already in use.",
    "hr_contracts_reference_code_key": "That contract reference code already exists.",
}


def _explain_integrity_error(exc: IntegrityError) -> tuple[int, str]:
    raw = str(getattr(exc, "orig", exc))
    for constraint, message in _CONSTRAINT_MESSAGES.items():
        if constraint in raw:
            return status.HTTP_409_CONFLICT, message
    # The contract overlap guard is a RAISE EXCEPTION, not a named constraint.
    if "already has an active RUNNING contract" in raw:
        return (
            status.HTTP_409_CONFLICT,
            "This employee already has a RUNNING contract overlapping that period.",
        )
    if "violates foreign key constraint" in raw:
        return status.HTTP_409_CONFLICT, "Referenced record does not exist or is still in use."
    if "duplicate key value" in raw:
        return status.HTTP_409_CONFLICT, "A record with those unique values already exists."
    return status.HTTP_400_BAD_REQUEST, "The request violated a database integrity rule."


def register_exception_handlers(app: FastAPI) -> None:
    @app.exception_handler(DomainError)
    async def _domain_error_handler(_: Request, exc: DomainError) -> JSONResponse:
        return JSONResponse(
            status_code=exc.status_code,
            content={"detail": exc.message, "code": exc.code, **({"details": exc.details} if exc.details else {})},
        )

    @app.exception_handler(IntegrityError)
    async def _integrity_error_handler(_: Request, exc: IntegrityError) -> JSONResponse:
        code, message = _explain_integrity_error(exc)
        return JSONResponse(
            status_code=code, content={"detail": message, "code": "integrity_error"}
        )

    @app.exception_handler(ValueError)
    async def _value_error_handler(_: Request, exc: ValueError) -> JSONResponse:
        # Services in the architecture doc raise bare ValueError for business rule
        # violations; surface those as 422 rather than a 500.
        return JSONResponse(
            status_code=status.HTTP_422_UNPROCESSABLE_ENTITY,
            content={"detail": str(exc), "code": "validation_error"},
        )
