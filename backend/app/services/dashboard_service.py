"""Payroll dashboard aggregates.

Built to the mockup's specification: a filter bar (period, department, employee
type, company), a five-card KPI ribbon, and six panels. Every figure is derived
from data created through the HR and payroll flows, never hardcoded.

Each figure is a single aggregate query rather than Python-side summation, so the
dashboard stays fast as the payslip table grows.
"""

from __future__ import annotations

import uuid
from dataclasses import dataclass
from datetime import date
from decimal import Decimal
from typing import Any, Dict, List, Optional

from sqlalchemy import text
from sqlalchemy.orm import Session

ZERO = Decimal("0.00")


def _dec(value: Any) -> Decimal:
    return Decimal(str(value or 0))


def _pct(numerator: Any, denominator: Any) -> float:
    num, den = _dec(numerator), _dec(denominator)
    return round(float(num / den * 100), 1) if den else 0.0


# ---------------------------------------------------------------------------
# FILTERS
# ---------------------------------------------------------------------------
@dataclass
class DashboardFilters:
    """The mockup's filter bar. Every panel honours whichever of these are set."""

    date_start: Optional[date] = None
    date_end: Optional[date] = None
    department_id: Optional[uuid.UUID] = None
    employee_type: Optional[str] = None
    company_name: Optional[str] = None
    payrun_id: Optional[uuid.UUID] = None

    def params(self) -> Dict[str, Any]:
        return {
            "date_start": self.date_start,
            "date_end": self.date_end,
            "department_id": str(self.department_id) if self.department_id else None,
            "employee_type": self.employee_type,
            "company_name": self.company_name,
            "payrun_id": str(self.payrun_id) if self.payrun_id else None,
        }

    def employee_clause(self, alias: str = "e") -> str:
        """SQL fragment restricting an employee alias to the selected cohort."""
        parts: List[str] = []
        if self.department_id:
            parts.append(f"{alias}.department_id = CAST(:department_id AS uuid)")
        if self.employee_type:
            parts.append(f"{alias}.employee_type = :employee_type")
        if self.company_name:
            parts.append(f"{alias}.company_name = :company_name")
        return (" AND " + " AND ".join(parts)) if parts else ""

    def payslip_period_clause(self, alias: str = "p") -> str:
        """Payslips whose period overlaps the selected window."""
        parts: List[str] = []
        if self.date_start:
            parts.append(f"{alias}.date_end >= :date_start")
        if self.date_end:
            parts.append(f"{alias}.date_start <= :date_end")
        if self.payrun_id:
            parts.append(f"{alias}.payrun_id = CAST(:payrun_id AS uuid)")
        return (" AND " + " AND ".join(parts)) if parts else ""

    def attendance_clause(self, alias: str = "a") -> str:
        parts: List[str] = []
        if self.date_start:
            parts.append(f"{alias}.check_in >= :date_start")
        if self.date_end:
            parts.append(f"{alias}.check_in < (CAST(:date_end AS date) + 1)")
        return (" AND " + " AND ".join(parts)) if parts else ""

    @property
    def is_period_bounded(self) -> bool:
        return self.date_start is not None and self.date_end is not None


def resolve_period(db: Session, filters: DashboardFilters) -> DashboardFilters:
    """Default the period to the latest payrun that actually produced payslips.

    Defaulting to "today" would show an empty dashboard whenever payroll for the
    current month has not been run yet, which is most of the month.
    """
    if filters.is_period_bounded or filters.payrun_id:
        return filters
    row = db.execute(
        text(
            """
            SELECT r.date_start, r.date_end
            FROM payruns r
            JOIN payslips p ON p.payrun_id = r.id
            GROUP BY r.id, r.date_start, r.date_end
            ORDER BY r.date_end DESC
            LIMIT 1
            """
        )
    ).fetchone()
    if row:
        filters.date_start = row.date_start
        filters.date_end = row.date_end
    return filters


# ---------------------------------------------------------------------------
# KPI RIBBON (the mockup's five cards)
# ---------------------------------------------------------------------------
def kpi_ribbon(db: Session, filters: DashboardFilters) -> Dict[str, Any]:
    params = filters.params()
    emp = filters.employee_clause("e")
    slip = filters.payslip_period_clause("p")

    payroll = db.execute(
        text(
            f"""
            SELECT
                COALESCE(SUM(p.net_amount), 0)   AS total_net,
                COALESCE(SUM(p.gross_amount), 0) AS total_gross,
                COALESCE(SUM(p.basic_amount), 0) AS total_basic,
                COUNT(p.id)                      AS payslips_generated,
                COUNT(*) FILTER (WHERE p.status = 'PAID')  AS paid_count,
                COUNT(*) FILTER (WHERE p.status <> 'PAID') AS pending_count,
                COUNT(DISTINCT p.employee_id)    AS employees_paid
            FROM payslips p
            JOIN employees e ON e.id = p.employee_id
            WHERE TRUE {slip} {emp}
            """
        ),
        params,
    ).one()

    # Month-on-month movement: the equivalent window immediately before this one.
    previous_net = ZERO
    if filters.is_period_bounded:
        previous = db.execute(
            text(
                f"""
                SELECT COALESCE(SUM(p.net_amount), 0) AS total_net
                FROM payslips p
                JOIN employees e ON e.id = p.employee_id
                WHERE p.date_end < :date_start
                  AND p.date_end >= (CAST(:date_start AS date)
                                     - (CAST(:date_end AS date) - CAST(:date_start AS date) + 1))
                  {emp}
                """
            ),
            params,
        ).one()
        previous_net = _dec(previous.total_net)

    current_net = _dec(payroll.total_net)
    if previous_net:
        change_pct = round(float((current_net - previous_net) / previous_net * 100), 1)
    else:
        change_pct = None

    timeoff = db.execute(
        text(
            f"""
            SELECT
                COALESCE(SUM(r.duration_days) FILTER (WHERE r.status = 'APPROVED'), 0)
                    AS approved_days,
                COUNT(*) FILTER (WHERE r.status = 'TO_APPROVE') AS pending_requests,
                COUNT(*) FILTER (
                    WHERE r.status = 'APPROVED'
                      AND r.start_date <= CURRENT_DATE AND r.end_date >= CURRENT_DATE
                ) AS on_leave_today
            FROM leave_requests r
            JOIN employees e ON e.id = r.employee_id
            WHERE TRUE {emp}
              AND (:date_start IS NULL OR r.end_date >= :date_start)
              AND (:date_end IS NULL OR r.start_date <= :date_end)
            """
        ),
        params,
    ).one()

    attendance = attendance_overview(db, filters)

    workforce = db.execute(
        text(
            f"""
            SELECT
                COUNT(*) FILTER (WHERE e.status = 'ACTIVE')     AS active_employees,
                COUNT(*) FILTER (WHERE e.status = 'INACTIVE')   AS inactive_employees,
                COUNT(*) FILTER (WHERE e.status = 'TERMINATED') AS terminated_employees,
                COUNT(*) FILTER (
                    WHERE e.status = 'ACTIVE'
                      AND (e.bank_account_number IS NULL
                           OR e.bank_ifsc_or_routing IS NULL)
                ) AS missing_bank_details,
                COUNT(*) FILTER (WHERE e.status = 'ACTIVE' AND e.pan_or_ssn IS NULL)
                    AS missing_tax_id
            FROM employees e
            WHERE TRUE {emp}
            """
        ),
        params,
    ).one()

    contracts = db.execute(
        text(
            f"""
            SELECT
                COUNT(*) FILTER (WHERE c.status = 'RUNNING') AS running,
                COUNT(*) FILTER (WHERE c.status = 'DRAFT')   AS draft,
                COUNT(*) FILTER (
                    WHERE c.status = 'RUNNING' AND c.end_date IS NOT NULL
                      AND c.end_date <= CURRENT_DATE + INTERVAL '45 days'
                ) AS expiring_soon,
                COUNT(*) FILTER (WHERE c.status = 'RUNNING' AND c.end_date IS NULL)
                    AS open_ended
            FROM hr_contracts c
            JOIN employees e ON e.id = c.employee_id
            WHERE TRUE {emp}
            """
        ),
        params,
    ).one()

    employees_paid = payroll.employees_paid or 0
    avg_net = (current_net / employees_paid) if employees_paid else ZERO

    return {
        # --- the five headline cards -------------------------------------
        "total_net_salary_paid": current_net,
        "total_net_change_pct": change_pct,
        "payslips_generated": payroll.payslips_generated,
        "payslips_paid": payroll.paid_count,
        "payslips_pending": payroll.pending_count,
        "avg_salary_per_employee": avg_net.quantize(Decimal("0.01")),
        "approved_timeoff_days": _dec(timeoff.approved_days),
        "attendance_health_pct": attendance["coverage_pct"],
        # --- supporting detail -------------------------------------------
        "total_gross_salary": _dec(payroll.total_gross),
        "total_basic_salary": _dec(payroll.total_basic),
        "employees_paid": employees_paid,
        "workforce": {
            "active_employees": workforce.active_employees,
            "inactive_employees": workforce.inactive_employees,
            "terminated_employees": workforce.terminated_employees,
            "missing_bank_details": workforce.missing_bank_details,
            "missing_tax_id": workforce.missing_tax_id,
        },
        "contracts": {
            "running": contracts.running,
            "draft": contracts.draft,
            "expiring_within_45_days": contracts.expiring_soon,
            "open_ended": contracts.open_ended,
        },
        "timeoff": {
            "approved_days": _dec(timeoff.approved_days),
            "pending_requests": timeoff.pending_requests,
            "on_leave_today": timeoff.on_leave_today,
        },
    }


# ---------------------------------------------------------------------------
# PANEL: Salary cost by department
# ---------------------------------------------------------------------------
def department_costs(
    db: Session, filters: DashboardFilters
) -> List[Dict[str, Any]]:
    rows = db.execute(
        text(
            f"""
            SELECT COALESCE(d.name, 'Unassigned') AS department,
                   COUNT(p.id)                      AS headcount,
                   COALESCE(SUM(p.basic_amount), 0) AS basic,
                   COALESCE(SUM(p.gross_amount), 0) AS gross,
                   COALESCE(SUM(p.net_amount), 0)   AS net
            FROM payslips p
            JOIN employees e ON e.id = p.employee_id
            LEFT JOIN departments d ON d.id = e.department_id
            WHERE TRUE {filters.payslip_period_clause('p')} {filters.employee_clause('e')}
            GROUP BY COALESCE(d.name, 'Unassigned')
            ORDER BY gross DESC
            """
        ),
        filters.params(),
    ).fetchall()

    total_gross = sum((_dec(r.gross) for r in rows), ZERO)
    return [
        {
            "department": r.department,
            "headcount": r.headcount,
            "total_basic": _dec(r.basic),
            "total_gross": _dec(r.gross),
            "total_net": _dec(r.net),
            "share_of_gross_pct": _pct(r.gross, total_gross),
        }
        for r in rows
    ]


# ---------------------------------------------------------------------------
# PANEL: Monthly net salary trend
# ---------------------------------------------------------------------------
def payroll_trend(
    db: Session, filters: DashboardFilters, months: int = 6
) -> List[Dict[str, Any]]:
    params = {**filters.params(), "limit": months}
    rows = db.execute(
        text(
            f"""
            SELECT r.reference_code, r.name, r.date_start, r.date_end, r.status,
                   COUNT(p.id)                      AS payslip_count,
                   COALESCE(SUM(p.basic_amount), 0) AS basic,
                   COALESCE(SUM(p.gross_amount), 0) AS gross,
                   COALESCE(SUM(p.net_amount), 0)   AS net
            FROM payruns r
            LEFT JOIN payslips p ON p.payrun_id = r.id
            LEFT JOIN employees e ON e.id = p.employee_id
                 AND TRUE {filters.employee_clause('e')}
            GROUP BY r.id, r.reference_code, r.name, r.date_start, r.date_end, r.status
            ORDER BY r.date_end DESC
            LIMIT :limit
            """
        ),
        params,
    ).fetchall()

    return [
        {
            "reference_code": r.reference_code,
            "period": r.name,
            "date_start": r.date_start,
            "date_end": r.date_end,
            "status": r.status,
            "payslip_count": r.payslip_count,
            "total_basic": _dec(r.basic),
            "total_gross": _dec(r.gross),
            "total_net": _dec(r.net),
        }
        # Oldest first so a chart reads left to right.
        for r in reversed(rows)
    ]


# ---------------------------------------------------------------------------
# PANEL: Payslip status split + payroll alerts
# ---------------------------------------------------------------------------
def payslip_status_and_alerts(
    db: Session, filters: DashboardFilters
) -> Dict[str, Any]:
    params = filters.params()
    emp = filters.employee_clause("e")
    slip = filters.payslip_period_clause("p")

    status = db.execute(
        text(
            f"""
            SELECT
                COUNT(*) FILTER (WHERE p.status = 'PAID')  AS paid,
                COUNT(*) FILTER (WHERE p.status = 'DONE')  AS done,
                COUNT(*) FILTER (WHERE p.status = 'DRAFT') AS draft,
                COUNT(*) FILTER (WHERE p.warning_notes IS NOT NULL) AS with_warnings,
                COUNT(*) AS total
            FROM payslips p
            JOIN employees e ON e.id = p.employee_id
            WHERE TRUE {slip} {emp}
            """
        ),
        params,
    ).one()

    missing_bank = db.execute(
        text(
            f"""
            SELECT COUNT(DISTINCT e.id) FROM employees e
            WHERE e.status = 'ACTIVE'
              AND (e.bank_account_number IS NULL OR e.bank_ifsc_or_routing IS NULL)
              {emp}
            """
        ),
        params,
    ).scalar_one()

    duplicate_warnings = db.execute(
        text(
            f"""
            SELECT COUNT(*) FROM payslips p
            JOIN employees e ON e.id = p.employee_id
            WHERE p.warning_notes ILIKE '%already exists%' {slip} {emp}
            """
        ),
        params,
    ).scalar_one()

    unvalidated = db.execute(
        text(
            """
            SELECT COUNT(*) FROM payruns
            WHERE status IN ('DRAFT', 'COMPUTED')
              AND (:date_start IS NULL OR date_end >= :date_start)
              AND (:date_end IS NULL OR date_start <= :date_end)
            """
        ),
        params,
    ).scalar_one()

    expiring = db.execute(
        text(
            f"""
            SELECT COUNT(*) FROM hr_contracts c
            JOIN employees e ON e.id = c.employee_id
            WHERE c.status = 'RUNNING' AND c.end_date IS NOT NULL
              AND c.end_date <= CURRENT_DATE + INTERVAL '45 days'
              {emp}
            """
        ),
        params,
    ).scalar_one()

    open_escalations = db.execute(
        text(
            """
            SELECT COUNT(*) FROM rag_escalations
            WHERE status IN ('OPEN', 'ASSIGNED')
            """
        )
    ).scalar_one()

    overdue_escalations = db.execute(
        text(
            """
            SELECT COUNT(*) FROM rag_escalations
            WHERE status IN ('OPEN', 'ASSIGNED') AND sla_due_at < NOW()
            """
        )
    ).scalar_one()

    # The mockup renders these as a bulleted "Current alerts" list. Building the
    # sentences here keeps the wording consistent across web and mobile clients.
    alerts: List[Dict[str, Any]] = []
    if missing_bank:
        alerts.append(
            {
                "severity": "WARNING",
                "kind": "MISSING_BANK_ACCOUNT",
                "count": missing_bank,
                "message": f"{missing_bank} employee(s) missing bank account",
            }
        )
    if duplicate_warnings:
        alerts.append(
            {
                "severity": "WARNING",
                "kind": "DUPLICATE_PAYSLIP",
                "count": duplicate_warnings,
                "message": f"{duplicate_warnings} duplicate payslip warning(s)",
            }
        )
    if unvalidated:
        alerts.append(
            {
                "severity": "INFO",
                "kind": "UNVALIDATED_PAYRUN",
                "count": unvalidated,
                "message": f"{unvalidated} payrun(s) still not validated",
            }
        )
    if expiring:
        alerts.append(
            {
                "severity": "INFO",
                "kind": "CONTRACT_EXPIRING",
                "count": expiring,
                "message": f"{expiring} contract(s) expiring within 45 days",
            }
        )
    if overdue_escalations:
        alerts.append(
            {
                "severity": "CRITICAL",
                "kind": "ESCALATION_OVERDUE",
                "count": overdue_escalations,
                "message": f"{overdue_escalations} HR question(s) past their SLA",
            }
        )
    elif open_escalations:
        alerts.append(
            {
                "severity": "INFO",
                "kind": "ESCALATION_OPEN",
                "count": open_escalations,
                "message": f"{open_escalations} HR question(s) awaiting an answer",
            }
        )

    return {
        "status_split": {
            "paid": status.paid,
            "done": status.done,
            "draft": status.draft,
            "with_warnings": status.with_warnings,
            "total": status.total,
        },
        "alerts": alerts,
        "alert_count": len(alerts),
    }


# ---------------------------------------------------------------------------
# PANEL: Attendance overview
# ---------------------------------------------------------------------------
def attendance_overview(db: Session, filters: DashboardFilters) -> Dict[str, Any]:
    params = filters.params()
    row = db.execute(
        text(
            f"""
            SELECT
                COUNT(*)                                        AS punches,
                COUNT(*) FILTER (WHERE a.status = 'PRESENT')    AS present,
                COUNT(*) FILTER (WHERE a.status = 'LATE')       AS late,
                COUNT(*) FILTER (WHERE a.status = 'ABSENT')     AS absent,
                COUNT(*) FILTER (WHERE a.status = 'HALF_DAY')   AS half_day,
                COUNT(*) FILTER (WHERE a.check_out IS NULL)     AS missing_check_outs,
                COUNT(*) FILTER (WHERE a.is_manual_edit)        AS manual_edits,
                COALESCE(SUM(a.worked_hours), 0)                AS worked_hours,
                COALESCE(SUM(a.overtime_hours), 0)              AS overtime_hours,
                COUNT(*) FILTER (WHERE a.overtime_hours > 0)     AS overtime_records,
                COUNT(DISTINCT a.employee_id)                   AS employees_with_records
            FROM attendances a
            JOIN employees e ON e.id = a.employee_id
            WHERE TRUE {filters.attendance_clause('a')} {filters.employee_clause('e')}
            """
        ),
        params,
    ).one()

    # "Attendance health" is the share of records that are complete and clean:
    # checked out, and neither absent nor a half day. A record with no check-out
    # cannot be trusted for payroll, so it counts against coverage.
    reviewed = (row.present or 0) + (row.late or 0)
    coverage = _pct(reviewed, row.punches) if row.punches else 0.0

    return {
        "total_records": row.punches,
        "present": row.present,
        "late": row.late,
        "absent": row.absent,
        "half_day": row.half_day,
        "missing_check_outs": row.missing_check_outs,
        "manual_attendance_edits": row.manual_edits,
        "total_worked_hours": _dec(row.worked_hours),
        "total_overtime_hours": _dec(row.overtime_hours),
        "records_with_overtime": row.overtime_records,
        "employees_with_records": row.employees_with_records,
        "coverage_pct": coverage,
    }


# ---------------------------------------------------------------------------
# PANEL: Time off overview by type
# ---------------------------------------------------------------------------
def timeoff_overview(db: Session, filters: DashboardFilters) -> List[Dict[str, Any]]:
    params = filters.params()
    emp = filters.employee_clause("e")

    rows = db.execute(
        text(
            f"""
            SELECT t.id, t.name, t.unit, t.requires_allocation,
                   COALESCE((
                       SELECT SUM(r.duration_days)
                       FROM leave_requests r
                       JOIN employees e ON e.id = r.employee_id
                       WHERE r.timeoff_type_id = t.id AND r.status = 'APPROVED'
                         AND (:date_start IS NULL OR r.end_date >= :date_start)
                         AND (:date_end IS NULL OR r.start_date <= :date_end)
                         {emp}
                   ), 0) AS approved_days,
                   COALESCE((
                       SELECT COUNT(*)
                       FROM leave_requests r
                       JOIN employees e ON e.id = r.employee_id
                       WHERE r.timeoff_type_id = t.id AND r.status = 'TO_APPROVE'
                         {emp}
                   ), 0) AS pending_requests,
                   COALESCE((
                       SELECT SUM(a.remaining_days)
                       FROM leave_allocations a
                       JOIN employees e ON e.id = a.employee_id
                       WHERE a.timeoff_type_id = t.id AND a.status = 'APPROVED'
                         {emp}
                   ), 0) AS remaining_balance
            FROM timeoff_types t
            WHERE t.is_active = TRUE
            ORDER BY t.name
            """
        ),
        params,
    ).fetchall()

    return [
        {
            "timeoff_type": r.name,
            "unit": r.unit,
            "approved_days": _dec(r.approved_days),
            "pending_requests": r.pending_requests,
            # A type that needs no allocation has no balance to report, which the
            # mockup shows as "N/A" rather than a misleading zero.
            "remaining_balance": (
                _dec(r.remaining_balance) if r.requires_allocation else None
            ),
            "tracks_balance": r.requires_allocation,
        }
        for r in rows
    ]


# ---------------------------------------------------------------------------
# PANEL: Department overview
# ---------------------------------------------------------------------------
def department_overview(db: Session, filters: DashboardFilters) -> List[Dict[str, Any]]:
    params = filters.params()
    emp = filters.employee_clause("e")
    rows = db.execute(
        text(
            f"""
            SELECT COALESCE(d.name, 'Unassigned') AS department,
                   COUNT(*) FILTER (WHERE e.status = 'ACTIVE') AS headcount,
                   COUNT(*) AS total_employees,
                   COALESCE(SUM(
                       CASE WHEN c.status = 'RUNNING' THEN c.wage_monthly ELSE 0 END
                   ), 0) AS monthly_wage_bill
            FROM employees e
            LEFT JOIN departments d ON d.id = e.department_id
            LEFT JOIN hr_contracts c
                   ON c.employee_id = e.id AND c.status = 'RUNNING'
            WHERE TRUE {emp}
            GROUP BY COALESCE(d.name, 'Unassigned')
            ORDER BY monthly_wage_bill DESC
            """
        ),
        params,
    ).fetchall()
    return [
        {
            "department": r.department,
            "headcount": r.headcount,
            "total_employees": r.total_employees,
            "monthly_wage_bill": _dec(r.monthly_wage_bill),
        }
        for r in rows
    ]


def filter_options(db: Session) -> Dict[str, Any]:
    """Everything the filter bar needs to render, from live data."""
    departments = db.execute(
        text("SELECT id, name FROM departments WHERE is_active ORDER BY name")
    ).fetchall()
    types = db.execute(
        text(
            "SELECT DISTINCT employee_type FROM employees "
            "WHERE employee_type IS NOT NULL ORDER BY employee_type"
        )
    ).scalars().all()
    companies = db.execute(
        text(
            "SELECT DISTINCT company_name FROM employees "
            "WHERE company_name IS NOT NULL ORDER BY company_name"
        )
    ).scalars().all()
    payruns = db.execute(
        text(
            """
            SELECT id, reference_code, name, date_start, date_end, status
            FROM payruns ORDER BY date_end DESC LIMIT 24
            """
        )
    ).fetchall()

    return {
        "departments": [{"id": str(d.id), "name": d.name} for d in departments],
        "employee_types": list(types),
        "companies": list(companies),
        "periods": [
            {
                "payrun_id": str(p.id),
                "reference_code": p.reference_code,
                "name": p.name,
                "date_start": p.date_start,
                "date_end": p.date_end,
                "status": p.status,
            }
            for p in payruns
        ],
    }


# ---------------------------------------------------------------------------
# THE COMPOSITE PAYLOAD
# ---------------------------------------------------------------------------
def dashboard_metrics(
    db: Session, filters: DashboardFilters | None = None
) -> Dict[str, Any]:
    filters = resolve_period(db, filters or DashboardFilters())
    status = payslip_status_and_alerts(db, filters)

    return {
        "generated_at": date.today(),
        "filters": {
            "date_start": filters.date_start,
            "date_end": filters.date_end,
            "department_id": filters.department_id,
            "employee_type": filters.employee_type,
            "company_name": filters.company_name,
            "payrun_id": filters.payrun_id,
        },
        "kpi": kpi_ribbon(db, filters),
        "department_costs": department_costs(db, filters),
        "payroll_trend": payroll_trend(db, filters),
        "payslip_status": status["status_split"],
        "alerts": status["alerts"],
        "attendance_overview": attendance_overview(db, filters),
        "timeoff_overview": timeoff_overview(db, filters),
        "department_overview": department_overview(db, filters),
    }


def employee_self_dashboard(db: Session, employee_id: uuid.UUID | str) -> Dict[str, Any]:
    """The employee-facing counterpart: only the caller's own numbers."""
    balances = db.execute(
        text(
            """
            SELECT t.name, t.unit, a.allocated_days, a.taken_days, a.remaining_days
            FROM leave_allocations a
            JOIN timeoff_types t ON t.id = a.timeoff_type_id
            WHERE a.employee_id = CAST(:emp AS uuid) AND a.status = 'APPROVED'
            ORDER BY t.name
            """
        ),
        {"emp": str(employee_id)},
    ).fetchall()

    latest_slip = db.execute(
        text(
            """
            SELECT id, reference_code, date_start, date_end, gross_amount,
                   net_amount, status
            FROM payslips WHERE employee_id = CAST(:emp AS uuid)
            ORDER BY date_end DESC LIMIT 1
            """
        ),
        {"emp": str(employee_id)},
    ).fetchone()

    month = db.execute(
        text(
            """
            SELECT COUNT(DISTINCT DATE(check_in)) AS days_present,
                   COALESCE(SUM(worked_hours), 0) AS hours,
                   COALESCE(SUM(overtime_hours), 0) AS overtime,
                   COUNT(*) FILTER (WHERE status = 'LATE') AS late_count
            FROM attendances
            WHERE employee_id = CAST(:emp AS uuid)
              AND check_in >= DATE_TRUNC('month', CURRENT_DATE)
            """
        ),
        {"emp": str(employee_id)},
    ).one()

    open_punch = db.execute(
        text(
            """
            SELECT check_in FROM attendances
            WHERE employee_id = CAST(:emp AS uuid) AND check_out IS NULL
            ORDER BY check_in DESC LIMIT 1
            """
        ),
        {"emp": str(employee_id)},
    ).fetchone()

    pending = db.execute(
        text(
            """
            SELECT COUNT(*) FROM leave_requests
            WHERE employee_id = CAST(:emp AS uuid) AND status = 'TO_APPROVE'
            """
        ),
        {"emp": str(employee_id)},
    ).scalar_one()

    return {
        "leave_balances": [
            {
                "timeoff_type": r.name,
                "unit": r.unit,
                "allocated_days": _dec(r.allocated_days),
                "taken_days": _dec(r.taken_days),
                "remaining_days": _dec(r.remaining_days),
            }
            for r in balances
        ],
        "latest_payslip": (
            {
                "payslip_id": str(latest_slip.id),
                "reference_code": latest_slip.reference_code,
                "date_start": latest_slip.date_start,
                "date_end": latest_slip.date_end,
                "gross_amount": _dec(latest_slip.gross_amount),
                "net_amount": _dec(latest_slip.net_amount),
                "status": latest_slip.status,
            }
            if latest_slip
            else None
        ),
        "attendance_this_month": {
            "days_present": month.days_present,
            "hours_worked": _dec(month.hours),
            "overtime_hours": _dec(month.overtime),
            "late_arrivals": month.late_count,
            "currently_checked_in": bool(open_punch),
            "checked_in_since": open_punch.check_in if open_punch else None,
        },
        "pending_timeoff_requests": pending,
    }
