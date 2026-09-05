"""Tier 0 answers: exact, local, offline-safe, zero LLM involvement.

These cover the majority of real employee questions. Questions about *the
employee's own data* must never be paraphrased by a language model - a
hallucinated salary figure is a serious defect, not a cosmetic one. Every number
below comes straight from SQL and is rendered through a deterministic template.
"""

from __future__ import annotations

import re
import uuid
from dataclasses import dataclass
from decimal import Decimal
from typing import Any, Callable, Dict, List, Optional

from sqlalchemy import text
from sqlalchemy.orm import Session

from app.core.config import settings

CURRENCY = settings.company_currency_symbol


def _money(value: Any) -> str:
    return f"{CURRENCY}{Decimal(str(value or 0)):,.2f}"


def _num(value: Any) -> str:
    """Trim pointless decimals: 12.00 -> 12, 12.50 -> 12.5."""
    dec = Decimal(str(value or 0)).normalize()
    return f"{dec:f}"


# ---------------------------------------------------------------------------
# TEMPLATES
# ---------------------------------------------------------------------------
def answer_leave_balance(db: Session, employee_id: uuid.UUID | str) -> Optional[str]:
    rows = db.execute(
        text(
            """
            SELECT t.name, t.unit, a.allocated_days, a.taken_days,
                   a.remaining_days, a.validity_year
            FROM leave_allocations a
            JOIN timeoff_types t ON a.timeoff_type_id = t.id
            WHERE a.employee_id = :emp AND a.status = 'APPROVED'
            ORDER BY a.validity_year DESC, t.name
            """
        ),
        {"emp": str(employee_id)},
    ).fetchall()

    if not rows:
        return (
            "You don't have any approved leave allocations yet. "
            "Your HR manager grants these."
        )

    lines = [
        f"- **{r.name}** ({r.validity_year}): {_num(r.remaining_days)} "
        f"{r.unit.lower()} remaining "
        f"(allocated {_num(r.allocated_days)}, taken {_num(r.taken_days)})"
        for r in rows
    ]
    return "Here is your current leave balance:\n\n" + "\n".join(lines)


def answer_pending_leave_requests(
    db: Session, employee_id: uuid.UUID | str
) -> Optional[str]:
    rows = db.execute(
        text(
            """
            SELECT t.name, r.start_date, r.end_date, r.duration_days, r.status
            FROM leave_requests r
            JOIN timeoff_types t ON r.timeoff_type_id = t.id
            WHERE r.employee_id = :emp
            ORDER BY r.created_at DESC
            LIMIT 5
            """
        ),
        {"emp": str(employee_id)},
    ).fetchall()

    if not rows:
        return "You haven't submitted any time off requests yet."

    lines = [
        f"- **{r.name}**: {r.start_date} to {r.end_date} "
        f"({_num(r.duration_days)} day(s)) - _{r.status.replace('_', ' ').title()}_"
        for r in rows
    ]
    return "Your most recent time off requests:\n\n" + "\n".join(lines)


def _latest_payslip_id(db: Session, employee_id: uuid.UUID | str) -> Optional[str]:
    row = db.execute(
        text(
            """
            SELECT id FROM payslips
            WHERE employee_id = :emp
            ORDER BY date_end DESC, created_at DESC
            LIMIT 1
            """
        ),
        {"emp": str(employee_id)},
    ).fetchone()
    return str(row.id) if row else None


def answer_payslip_breakdown(
    db: Session, employee_id: uuid.UUID | str, payslip_id: str | None = None
) -> Optional[str]:
    """'Explain the deductions on my payslip.'

    Rendered from the ACTUAL computed payslip lines and the rule definitions that
    produced them, so every number is traceable to the salary engine.
    """
    payslip_id = payslip_id or _latest_payslip_id(db, employee_id)
    if not payslip_id:
        return "I couldn't find any payslip on your record yet."

    slip = db.execute(
        text(
            """
            SELECT p.reference_code, p.date_start, p.date_end, p.worked_days,
                   p.basic_amount, p.gross_amount, p.net_amount, p.status
            FROM payslips p
            WHERE p.id = :sid AND p.employee_id = :emp
            """
        ),
        {"sid": payslip_id, "emp": str(employee_id)},
    ).fetchone()

    if not slip:
        return "I couldn't find that payslip under your record."

    lines = db.execute(
        text(
            """
            SELECT l.rule_name, l.rule_code, l.category, l.amount,
                   r.computation_type, r.percentage_base, r.percentage_rate
            FROM payslip_lines l
            LEFT JOIN salary_rules r ON r.id = l.salary_rule_id
            WHERE l.payslip_id = :sid
            ORDER BY l.sequence ASC
            """
        ),
        {"sid": payslip_id},
    ).fetchall()

    def explain(row) -> str:
        if row.computation_type == "PERCENTAGE" and row.percentage_base:
            return f"{_num(row.percentage_rate)}% of {row.percentage_base.title()}"
        if row.computation_type == "FIXED":
            return "fixed amount"
        return "formula-based"

    earnings = [l for l in lines if l.category in ("BASIC", "ALLOWANCE")]
    deductions = [l for l in lines if l.category == "DEDUCTION"]

    body = [
        f"**Payslip {slip.reference_code}** ({slip.date_start} to {slip.date_end}), "
        f"{_num(slip.worked_days)} worked days. Status: {slip.status}.",
        "",
        "Earnings:",
    ]
    body += [
        f"- **{e.rule_name}** ({e.rule_code}): {_money(e.amount)} - {explain(e)}"
        for e in earnings
    ] or ["- (none recorded)"]

    body += ["", f"Gross: {_money(slip.gross_amount)}", "", "Deductions applied:"]
    body += [
        f"- **{d.rule_name}** ({d.rule_code}): {_money(abs(d.amount))} - {explain(d)}"
        for d in deductions
    ] or ["- (none)"]

    total_deductions = sum(abs(Decimal(str(d.amount))) for d in deductions)
    body += [
        "",
        f"Total deductions: {_money(total_deductions)}",
        f"**Net pay: {_money(slip.net_amount)}**",
    ]
    return "\n".join(body)


def answer_payslip_history(db: Session, employee_id: uuid.UUID | str) -> Optional[str]:
    rows = db.execute(
        text(
            """
            SELECT reference_code, date_start, date_end, gross_amount,
                   net_amount, status
            FROM payslips
            WHERE employee_id = :emp
            ORDER BY date_end DESC
            LIMIT 6
            """
        ),
        {"emp": str(employee_id)},
    ).fetchall()

    if not rows:
        return "No payslips have been generated for you yet."

    lines = [
        f"- **{r.reference_code}** ({r.date_start} to {r.date_end}): "
        f"gross {_money(r.gross_amount)}, net {_money(r.net_amount)} - {r.status}"
        for r in rows
    ]
    return "Your recent payslips:\n\n" + "\n".join(lines)


def answer_attendance_summary(
    db: Session, employee_id: uuid.UUID | str
) -> Optional[str]:
    row = db.execute(
        text(
            """
            SELECT COUNT(*) AS punches,
                   COUNT(DISTINCT DATE(check_in)) AS days,
                   COALESCE(SUM(worked_hours), 0) AS hours,
                   COALESCE(SUM(overtime_hours), 0) AS overtime,
                   COUNT(*) FILTER (WHERE status = 'LATE') AS late_count
            FROM attendances
            WHERE employee_id = :emp
              AND check_in >= DATE_TRUNC('month', CURRENT_DATE)
            """
        ),
        {"emp": str(employee_id)},
    ).fetchone()

    open_punch = db.execute(
        text(
            """
            SELECT check_in FROM attendances
            WHERE employee_id = :emp AND check_out IS NULL
            ORDER BY check_in DESC LIMIT 1
            """
        ),
        {"emp": str(employee_id)},
    ).fetchone()

    parts = [
        "Your attendance this month:",
        "",
        f"- Days present: {row.days}",
        f"- Hours worked: {_num(row.hours)}",
        f"- Overtime hours: {_num(row.overtime)}",
        f"- Late arrivals: {row.late_count}",
    ]
    if open_punch:
        parts += ["", f"You are currently checked in since {open_punch.check_in:%H:%M on %d %b %Y}."]
    return "\n".join(parts)


def answer_contract_details(db: Session, employee_id: uuid.UUID | str) -> Optional[str]:
    row = db.execute(
        text(
            """
            SELECT c.reference_code, c.start_date, c.end_date, c.wage_monthly,
                   c.status, d.name AS department, j.name AS position,
                   w.name AS schedule
            FROM hr_contracts c
            LEFT JOIN departments d ON d.id = c.department_id
            LEFT JOIN job_positions j ON j.id = c.job_position_id
            LEFT JOIN working_schedules w ON w.id = c.working_schedule_id
            WHERE c.employee_id = :emp AND c.status = 'RUNNING'
            ORDER BY c.start_date DESC
            LIMIT 1
            """
        ),
        {"emp": str(employee_id)},
    ).fetchone()

    if not row:
        return (
            "I don't see a running contract on your record. "
            "Your HR manager can confirm your contract status."
        )

    return "\n".join(
        [
            f"**Contract {row.reference_code}** (status: {row.status})",
            "",
            f"- Position: {row.position or 'not set'}",
            f"- Department: {row.department or 'not set'}",
            f"- Working schedule: {row.schedule or 'not set'}",
            f"- Monthly wage: {_money(row.wage_monthly)}",
            f"- Start date: {row.start_date}",
            f"- End date: {row.end_date or 'ongoing'}",
        ]
    )


def answer_next_holiday(db: Session, employee_id: uuid.UUID | str | None = None) -> Optional[str]:
    rows = db.execute(
        text(
            """
            SELECT name, holiday_date FROM public_holidays
            WHERE holiday_date >= CURRENT_DATE
            ORDER BY holiday_date ASC
            LIMIT 5
            """
        )
    ).fetchall()
    if not rows:
        return "There are no upcoming public holidays configured."
    lines = [f"- **{r.name}**: {r.holiday_date:%A, %d %B %Y}" for r in rows]
    return "Upcoming public holidays:\n\n" + "\n".join(lines)


def answer_employee_count(db: Session, employee_id: uuid.UUID | str | None = None) -> Optional[str]:
    total = db.execute(text("SELECT COUNT(*) FROM employees WHERE status = 'ACTIVE'")).scalar() or 0
    depts = db.execute(
        text(
            """
            SELECT d.name, COUNT(e.id) as cnt
            FROM departments d
            JOIN employees e ON e.department_id = d.id
            WHERE e.status = 'ACTIVE'
            GROUP BY d.name
            ORDER BY cnt DESC
            """
        )
    ).fetchall()

    lines = [f"### PeoplePay360 Headcount Summary\n\nThere are **{total} active employees** across the organization:\n"]
    for d in depts:
        lines.append(f"- **{d.name}**: {d.cnt} employee(s)")
    return "\n".join(lines)


# ---------------------------------------------------------------------------
# DETERMINISTIC INTENT ROUTER (no LLM, works with zero network)
# ---------------------------------------------------------------------------
@dataclass(frozen=True)
class Tier0Intent:
    name: str
    patterns: tuple[str, ...]
    handler: Callable[..., Optional[str]]
    description: str


# A question that mentions entitlement, policy or the company is asking what the
# HANDBOOK says, not what this employee's own record says. "How many PTO days do I
# get each year?" is a policy question even though it contains "I": answering it
# with a personal balance is a wrong answer, not a helpful one. This veto runs
# before intent matching and hands those questions to retrieval instead.
POLICY_VETO_RE = re.compile(
    r"\b(polic(y|ies)|entitle(d|ment)?|allowance|eligib(le|ility)|"
    r"per year|each year|annually|per month|every year|"
    r"am i allowed|can i|should i|rule|rules|handbook|company|"
    r"what happens if|how do i (apply|request|submit)|"
    r"carry (forward|over)|notice period|probation|statutory)\b",
    re.IGNORECASE,
)

TIER0_INTENTS: tuple[Tier0Intent, ...] = (
    Tier0Intent(
        name="EMPLOYEE_COUNT",
        patterns=(
            r"\b(total|how many|count|list|show)\b.*\b(employees?|staff|headcount|workforce|people|team)\b",
            r"\bheadcount\b",
            r"\btotal employee\b",
            r"\bemployee count\b",
        ),
        handler=answer_employee_count,
        description="Active employee count and departmental breakdown",
    ),
    Tier0Intent(
        name="LEAVE_BALANCE",
        patterns=(
            # Every pattern requires a first-person possessive anchor, so only
            # questions genuinely about the caller's own ledger reach Tier 0.
            r"\bmy\b[^.?]*\b(leave|pto|time off|vacation)\b[^.?]*\b(balance|left|remaining|available)\b",
            r"\b(balance|remaining|left|available)\b[^.?]*\bmy\b[^.?]*\b(leave|pto|time off|vacation)\b",
            r"\bmy (leave|pto|vacation|time off) balance\b",
            r"\bleave balance\b",
            r"\bhow (much|many)\b[^.?]*\b(leave|pto|vacation|time off|days off)\b[^.?]*"
            r"\b(do i have|have i got|do i have left|is left|are left|remaining)\b",
            r"\bhow (much|many)\b[^.?]*\bmy\b[^.?]*\b(leave|pto|vacation|time off)\b",
        ),
        handler=answer_leave_balance,
        description="Approved leave allocations and remaining days",
    ),
    Tier0Intent(
        name="LEAVE_REQUESTS",
        patterns=(
            r"\bmy\b.*\b(leave|time off)\b.*\b(request|application|status)\b",
            r"\b(status of|track)\b.*\b(leave|time off)\b",
            r"\bpending (leave|time off)\b",
        ),
        handler=answer_pending_leave_requests,
        description="Status of the employee's own time off requests",
    ),
    Tier0Intent(
        name="PAYSLIP_BREAKDOWN",
        patterns=(
            r"\b(explain|breakdown|break down|why)\b.*\b(payslip|salary|deduction|net pay|take home)\b",
            r"\bmy\b.*\bdeduction",
            r"\bhow much.*\b(deducted|net pay|take home)\b",
            r"\bpayslip\b.*\b(detail|breakdown|explain)\b",
        ),
        handler=answer_payslip_breakdown,
        description="Rule-by-rule explanation of a computed payslip",
    ),
    Tier0Intent(
        name="PAYSLIP_HISTORY",
        patterns=(
            r"\bmy\b.*\bpayslips?\b",
            r"\b(list|show|recent|past|previous)\b.*\bpayslips?\b",
            r"\bsalary history\b",
        ),
        handler=answer_payslip_history,
        description="Recent payslips for the caller",
    ),
    Tier0Intent(
        name="ATTENDANCE_SUMMARY",
        patterns=(
            r"\bmy\b.*\b(attendance|hours|overtime|check ?in|check ?out|punch)\b",
            r"\b(how many hours|hours worked|overtime)\b.*\b(month|week|i)\b",
            r"\bam i checked in\b",
        ),
        handler=answer_attendance_summary,
        description="This month's attendance totals for the caller",
    ),
    Tier0Intent(
        name="CONTRACT_DETAILS",
        patterns=(
            r"\bmy\b.*\b(contract|wage|salary)\b.*\b(detail|term|status|amount|how much)\b",
            r"\bmy contract\b",
            r"\b(what is|whats|what's)\b.*\bmy (wage|salary|ctc)\b",
        ),
        handler=answer_contract_details,
        description="The caller's running contract terms",
    ),
    Tier0Intent(
        name="NEXT_HOLIDAY",
        patterns=(
            r"\b(next|upcoming)\b.*\bholidays?\b",
            r"\bpublic holidays?\b",
            r"\bholiday (list|calendar)\b",
        ),
        handler=answer_next_holiday,
        description="Upcoming public holidays",
    ),
)

_COMPILED: Dict[str, List[re.Pattern[str]]] = {
    intent.name: [re.compile(p, re.IGNORECASE) for p in intent.patterns]
    for intent in TIER0_INTENTS
}


def detect_tier0_intent(prompt: str) -> Optional[Tier0Intent]:
    normalised = (prompt or "").strip()
    if not normalised:
        return None

    policy_flavoured = bool(POLICY_VETO_RE.search(normalised))

    for intent in TIER0_INTENTS:
        if not any(pattern.search(normalised) for pattern in _COMPILED[intent.name]):
            continue
        if policy_flavoured and intent.name not in ("NEXT_HOLIDAY", "EMPLOYEE_COUNT"):
            return None
        return intent
    return None


def answer_tier0(
    db: Session,
    employee_id: uuid.UUID | str | None,
    prompt: str,
    *,
    payslip_id: str | None = None,
) -> Optional[Dict[str, Any]]:
    """Try to answer entirely from SQL. Returns None when no intent matches."""
    intent = detect_tier0_intent(prompt)
    if intent is None:
        return None
    if employee_id is None and intent.name not in ("NEXT_HOLIDAY", "EMPLOYEE_COUNT"):
        # Personal-data intents are meaningless without a linked employee record.
        return None

    if intent.name == "PAYSLIP_BREAKDOWN":
        answer = intent.handler(db, employee_id, payslip_id)
    else:
        answer = intent.handler(db, employee_id)

    if not answer:
        return None

    return {
        "intent": intent.name,
        "answer": answer,
        "source": "Your PeoplePay360 records (retrieved directly from the database)",
    }


def tier0_catalogue() -> List[Dict[str, str]]:
    """Advertised to the client so the UI can show suggested questions."""
    return [
        {"intent": i.name, "description": i.description, "example": i.patterns[0]}
        for i in TIER0_INTENTS
    ]
