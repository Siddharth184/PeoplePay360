"""Aggregates every v1 router.

Route ORDER matters where a static segment could be captured by a path
parameter (for example `/ai/escalations/stats` must be declared before
`/ai/escalations/{escalation_id}`); that ordering is handled inside each module.
"""

from fastapi import APIRouter

from app.api.v1 import (
    ai,
    attendance,
    auth,
    contracts,
    dashboard,
    employees,
    payruns,
    salary_structures,
    timeoff,
    users,
)

api_router = APIRouter()

api_router.include_router(auth.router)
api_router.include_router(users.router)
api_router.include_router(employees.router)
api_router.include_router(contracts.router)
api_router.include_router(attendance.router)
api_router.include_router(timeoff.router)
api_router.include_router(salary_structures.router)
api_router.include_router(payruns.router)
api_router.include_router(dashboard.router)
api_router.include_router(ai.router)
