"""Dashboard metrics: the HR/payroll ribbon and the employee self-service view."""

from __future__ import annotations

import uuid
from datetime import date
from typing import Annotated, List, Optional

from fastapi import APIRouter, Depends, Query

from app.api.deps import DbSession, User, require_linked_employee
from app.core.security import CurrentUser, require_payroll
from app.schemas.payroll import (
    AttendanceOverviewOut,
    DashboardFilterOptionsOut,
    DashboardMetricsOut,
    DepartmentCostOut,
    DepartmentOverviewOut,
    PayrollAlertOut,
    PayrollTrendPointOut,
    PayslipStatusSplitOut,
    TimeOffOverviewOut,
)
from app.services import dashboard_service
from app.services.dashboard_service import DashboardFilters

router = APIRouter(prefix="/dashboard", tags=["Dashboard"])


class FilterParams:
    """The mockup's filter bar, shared by every dashboard endpoint.

    Leaving the period unset makes the service default to the latest payrun that
    actually produced payslips, so the dashboard is never blank just because this
    month's payroll has not been run yet.
    """

    def __init__(
        self,
        date_start: Optional[date] = Query(
            default=None, description="Period start. Defaults to the latest payrun."
        ),
        date_end: Optional[date] = Query(default=None, description="Period end."),
        payrun_id: Optional[uuid.UUID] = Query(
            default=None, description="Scope to one payrun instead of a date range."
        ),
        department_id: Optional[uuid.UUID] = Query(default=None),
        employee_type: Optional[str] = Query(
            default=None,
            pattern="^(PERMANENT|PROBATION|CONTRACT|INTERN|CONSULTANT)$",
        ),
        company_name: Optional[str] = Query(default=None, max_length=100),
    ) -> None:
        self.filters = DashboardFilters(
            date_start=date_start,
            date_end=date_end,
            payrun_id=payrun_id,
            department_id=department_id,
            employee_type=employee_type,
            company_name=company_name,
        )


Filters = Annotated[FilterParams, Depends(FilterParams)]


@router.get(
    "/filters",
    response_model=DashboardFilterOptionsOut,
    summary="Options for the Period / Department / Employee Type / Company filter bar",
)
def filter_options(
    db: DbSession, _: CurrentUser = Depends(require_payroll)
) -> DashboardFilterOptionsOut:
    return DashboardFilterOptionsOut(**dashboard_service.filter_options(db))


@router.get(
    "/metrics",
    response_model=DashboardMetricsOut,
    summary="The full dashboard: KPI ribbon, six panels and payroll alerts",
)
def metrics(
    db: DbSession, params: Filters, _: CurrentUser = Depends(require_payroll)
) -> DashboardMetricsOut:
    return DashboardMetricsOut(
        **dashboard_service.dashboard_metrics(db, params.filters)
    )


@router.get(
    "/department-costs",
    response_model=List[DepartmentCostOut],
    summary="Salary cost by department for the selected period",
)
def department_costs(
    db: DbSession, params: Filters, _: CurrentUser = Depends(require_payroll)
) -> List[DepartmentCostOut]:
    filters = dashboard_service.resolve_period(db, params.filters)
    return [
        DepartmentCostOut(**row)
        for row in dashboard_service.department_costs(db, filters)
    ]


@router.get(
    "/payroll-trend",
    response_model=List[PayrollTrendPointOut],
    summary="Net salary totals over the last N payruns, oldest first",
)
def payroll_trend(
    db: DbSession,
    params: Filters,
    _: CurrentUser = Depends(require_payroll),
    months: int = Query(default=6, ge=1, le=36),
) -> List[PayrollTrendPointOut]:
    return [
        PayrollTrendPointOut(**row)
        for row in dashboard_service.payroll_trend(db, params.filters, months)
    ]


@router.get(
    "/attendance-overview",
    response_model=AttendanceOverviewOut,
    summary="Present / late / absent / overtime, missing check-outs and manual edits",
)
def attendance_overview(
    db: DbSession, params: Filters, _: CurrentUser = Depends(require_payroll)
) -> AttendanceOverviewOut:
    filters = dashboard_service.resolve_period(db, params.filters)
    return AttendanceOverviewOut(
        **dashboard_service.attendance_overview(db, filters)
    )


@router.get(
    "/timeoff-overview",
    response_model=List[TimeOffOverviewOut],
    summary="Approved days, pending requests and remaining balance per leave type",
)
def timeoff_overview(
    db: DbSession, params: Filters, _: CurrentUser = Depends(require_payroll)
) -> List[TimeOffOverviewOut]:
    filters = dashboard_service.resolve_period(db, params.filters)
    return [
        TimeOffOverviewOut(**row)
        for row in dashboard_service.timeoff_overview(db, filters)
    ]


@router.get(
    "/department-overview",
    response_model=List[DepartmentOverviewOut],
    summary="Headcount and monthly wage bill per department",
)
def department_overview(
    db: DbSession, params: Filters, _: CurrentUser = Depends(require_payroll)
) -> List[DepartmentOverviewOut]:
    return [
        DepartmentOverviewOut(**row)
        for row in dashboard_service.department_overview(db, params.filters)
    ]


@router.get(
    "/alerts",
    response_model=List[PayrollAlertOut],
    summary="Payroll items requiring attention",
)
def alerts(
    db: DbSession, params: Filters, _: CurrentUser = Depends(require_payroll)
) -> List[PayrollAlertOut]:
    filters = dashboard_service.resolve_period(db, params.filters)
    return [
        PayrollAlertOut(**a)
        for a in dashboard_service.payslip_status_and_alerts(db, filters)["alerts"]
    ]


@router.get(
    "/payslip-status",
    response_model=PayslipStatusSplitOut,
    summary="Paid / done / draft / warning split for the selected period",
)
def payslip_status(
    db: DbSession, params: Filters, _: CurrentUser = Depends(require_payroll)
) -> PayslipStatusSplitOut:
    filters = dashboard_service.resolve_period(db, params.filters)
    return PayslipStatusSplitOut(
        **dashboard_service.payslip_status_and_alerts(db, filters)["status_split"]
    )


@router.get(
    "/me",
    summary="The employee's own dashboard: balances, latest payslip, attendance",
)
def my_dashboard(db: DbSession, user: User) -> dict:
    employee_id = require_linked_employee(user)
    return dashboard_service.employee_self_dashboard(db, employee_id)
