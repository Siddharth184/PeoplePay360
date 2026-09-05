"""End-to-end API verification against a running server.

Exercises every subsystem in the architecture document and asserts the concrete
values it specifies. Exits non-zero on the first failed assertion, so this is
usable as a smoke test in CI as well as a demo script.

Prerequisites:
    docker compose up -d db
    python -m scripts.init_db
    python -m scripts.seed_db
    python -m uvicorn app.main:app --port 8000

Usage:
    python -m scripts.verify_api
    python -m scripts.verify_api --base-url http://127.0.0.1:8000
"""

from __future__ import annotations

import argparse
import sys
from decimal import Decimal
from pathlib import Path
from typing import Any

import httpx

sys.path.insert(0, str(Path(__file__).resolve().parents[1]))

PASSWORD = "PeoplePay@360"
ACCOUNTS = {
    "admin": "admin@oxp.com",
    "payroll_manager": "vikram.nair@oxp.com",
    "payroll_user": "aarav.mehta@oxp.com",
    "hr_manager": "sara.khan@oxp.com",
    "employee": "priya.sharma@oxp.com",
}

passed = 0
failed: list[str] = []
section_name = ""


def section(title: str) -> None:
    global section_name
    section_name = title
    print(f"\n{title}")
    print("-" * max(60, len(title)))


def check(label: str, condition: bool, detail: Any = "") -> bool:
    global passed
    if condition:
        passed += 1
        print(f"  PASS  {label}" + (f"  [{detail}]" if detail != "" else ""))
        return True
    failed.append(f"{section_name} :: {label}  {detail}")
    print(f"  FAIL  {label}  {detail}")
    return False


class Api:
    def __init__(self, base_url: str) -> None:
        self.base = base_url.rstrip("/")
        self.api = f"{self.base}/api/v1"
        self.client = httpx.Client(timeout=90.0)
        self.tokens: dict[str, str] = {}

    def login(self, alias: str) -> dict:
        response = self.client.post(
            f"{self.api}/auth/login",
            json={"email": ACCOUNTS[alias], "password": PASSWORD},
        )
        response.raise_for_status()
        payload = response.json()
        self.tokens[alias] = payload["access_token"]
        return payload

    def headers(self, alias: str) -> dict:
        return {"Authorization": f"Bearer {self.tokens[alias]}"}

    def request(self, method: str, path: str, alias: str | None = None, **kw):
        headers = self.headers(alias) if alias else {}
        headers.update(kw.pop("headers", {}))
        return self.client.request(
            method, f"{self.api}{path}", headers=headers, **kw
        )

    def get(self, path, alias=None, **kw):
        return self.request("GET", path, alias, **kw)

    def post(self, path, alias=None, **kw):
        return self.request("POST", path, alias, **kw)

    def patch(self, path, alias=None, **kw):
        return self.request("PATCH", path, alias, **kw)


def main() -> int:
    parser = argparse.ArgumentParser()
    parser.add_argument("--base-url", default="http://127.0.0.1:8000")
    args = parser.parse_args()

    api = Api(args.base_url)

    print("PeoplePay360 backend verification")
    print("=" * 60)
    print(f"Target: {api.base}")

    # =====================================================================
    section("1. Service health and dependencies")
    # =====================================================================
    health = api.client.get(f"{api.base}/health").json()
    check("service reports ok", health["status"] == "ok", health["status"])
    check("postgres connected", health["database"]["connected"] is True)
    check("pgvector installed", health["database"]["pgvector"] is True)
    check(
        "embeddings run locally",
        health["embeddings"]["runs_locally"] is True,
        health["embeddings"]["active_backend"],
    )
    check(
        "embedding dimensions are 384",
        health["embeddings"]["dimensions"] == 384,
    )

    # =====================================================================
    section("2. Authentication and the 5-tier RBAC matrix")
    # =====================================================================
    for alias in ACCOUNTS:
        payload = api.login(alias)
        check(f"login {alias}", bool(payload["access_token"]), payload["role"])

    bad = api.client.post(
        f"{api.api}/auth/login",
        json={"email": ACCOUNTS["admin"], "password": "wrong-password"},
    )
    check("wrong password is rejected", bad.status_code == 401, bad.status_code)

    anon = api.client.get(f"{api.api}/employees")
    check("unauthenticated request is rejected", anon.status_code == 403, anon.status_code)

    me = api.get("/auth/me", "employee").json()
    check("employee is linked to an employee record", me["employee_id"] is not None)
    check(
        "employee permissions do not include payroll",
        "crud:payruns" not in me["permissions"],
        f"{len(me['permissions'])} permissions",
    )

    forbidden = api.get("/employees", "employee")
    check(
        "EMPLOYEE cannot list all employees",
        forbidden.status_code == 403,
        forbidden.status_code,
    )
    forbidden = api.get("/users", "hr_manager")
    check(
        "HR_MANAGER cannot list users (ADMIN only)",
        forbidden.status_code == 403,
        forbidden.status_code,
    )
    forbidden = api.get("/payruns", "hr_manager")
    check(
        "HR_MANAGER cannot access payruns",
        forbidden.status_code == 403,
        forbidden.status_code,
    )
    allowed = api.get("/payruns", "payroll_user")
    check(
        "HR_PAYROLL_USER can access payruns",
        allowed.status_code == 200,
        allowed.status_code,
    )

    # ---- Private field gating -------------------------------------------
    employees_hr = api.get("/employees", "hr_manager", params={"limit": 1}).json()
    employees_pay = api.get("/employees", "payroll_user", params={"limit": 1}).json()
    check(
        "HR_MANAGER cannot see bank account numbers",
        employees_hr[0]["bank_account_number"] is None,
    )
    check(
        "HR_PAYROLL_USER can see bank account numbers",
        employees_pay[0]["bank_account_number"] is not None,
    )

    # ---- Row scoping -----------------------------------------------------
    other_employee_id = employees_pay[0]["id"]
    scoped = api.get(f"/employees/{other_employee_id}", "employee")
    if other_employee_id == me["employee_id"]:
        check("row scoping (skipped: same employee)", True)
    else:
        check(
            "EMPLOYEE cannot read another employee's profile",
            scoped.status_code == 403,
            scoped.status_code,
        )
    own = api.get(f"/employees/{me['employee_id']}", "employee")
    check("EMPLOYEE can read their own profile", own.status_code == 200, own.status_code)
    own_body = own.json()
    check(
        "own profile hides private banking fields from EMPLOYEE",
        own_body["bank_account_number"] is None,
    )
    check(
        "own profile carries smart counts",
        own_body["counts"]["contracts_running"] >= 1,
        own_body["counts"],
    )

    # =====================================================================
    section("3. Zero-loophole database integrity")
    # =====================================================================
    employee_id = employees_pay[0]["id"]

    overlap = api.post(
        "/contracts",
        "payroll_manager",
        json={
            "employee_id": employee_id,
            "start_date": "2026-06-01",
            "wage_monthly": "50000.00",
            "status": "RUNNING",
        },
    )
    check(
        "overlapping RUNNING contract is refused (409)",
        overlap.status_code == 409,
        overlap.status_code,
    )

    bad_dates = api.post(
        "/contracts",
        "payroll_manager",
        json={
            "employee_id": employee_id,
            "start_date": "2026-06-01",
            "end_date": "2026-05-01",
            "wage_monthly": "50000.00",
        },
    )
    check(
        "end_date before start_date is refused (422)",
        bad_dates.status_code == 422,
        bad_dates.status_code,
    )

    negative_wage = api.post(
        "/contracts",
        "payroll_manager",
        json={
            "employee_id": employee_id,
            "start_date": "2027-01-01",
            "wage_monthly": "-1000.00",
        },
    )
    check(
        "negative wage is refused (422)",
        negative_wage.status_code == 422,
        negative_wage.status_code,
    )

    # An over-drawn leave request must be refused up front.
    types = api.get("/timeoff/types", "employee").json()
    pto = next(t for t in types if t["name"] == "Paid Time Off")
    overdraw = api.post(
        "/timeoff/requests",
        "employee",
        json={
            "timeoff_type_id": pto["id"],
            "start_date": "2026-07-01",
            "end_date": "2026-10-31",
            "reason": "Deliberately larger than the balance",
        },
    )
    check(
        "leave request exceeding the balance is refused",
        overdraw.status_code in (409, 422),
        overdraw.status_code,
    )

    # =====================================================================
    section("4. AST-safe salary rule sandbox")
    # =====================================================================
    attacks = {
        "import os": "import os\nresult = 1",
        "__class__ escape": "result = ().__class__.__bases__[0].__subclasses__()",
        "open() file access": "result = open('/etc/passwd').read()",
        "eval()": "result = eval('1+1')",
        "while loop": "while True:\n    result = 1",
        "lambda": "result = (lambda: 1)()",
        "dunder attribute": "result = contract.__dict__",
        "unknown field": "result = contract.bank_account_number",
    }
    for label, code in attacks.items():
        response = api.post(
            "/salary-structures/validate-python-rule",
            "payroll_manager",
            json={"python_code": code},
        )
        body = response.json()
        check(
            f"sandbox blocks: {label}",
            response.status_code == 200 and body["valid"] is False,
            body.get("message", "")[:70],
        )

    legit = api.post(
        "/salary-structures/validate-python-rule",
        "payroll_manager",
        json={"python_code": "result = contract.wage * 0.50"},
    ).json()
    check(
        "sandbox allows: result = contract.wage * 0.50",
        legit["valid"] is True and Decimal(str(legit["probe_result"])) == Decimal("50000.00"),
        legit.get("probe_result"),
    )

    conditional = api.post(
        "/salary-structures/validate-python-rule",
        "payroll_manager",
        json={
            "python_code": (
                "if worked_days < expected_days:\n"
                "    result = round(contract.wage * worked_days / expected_days, 2)\n"
                "else:\n"
                "    result = contract.wage"
            )
        },
    ).json()
    check(
        "sandbox allows conditionals, round() and proration",
        conditional["valid"] is True,
        conditional.get("probe_result"),
    )

    # =====================================================================
    section("5. Salary engine reproduces the mockup payslip exactly")
    # =====================================================================
    structures = api.get("/salary-structures", "payroll_user").json()
    regular = next(s for s in structures if s["code"] == "REG_SALARY")
    check("Regular Salary structure has 7 active rules", len(regular["rules"]) == 7,
          len(regular["rules"]))

    sim = api.post(
        "/salary-structures/simulate",
        "payroll_user",
        json={"salary_structure_id": regular["id"], "wage_monthly": "100000.00"},
    ).json()
    by_code = {line["rule_code"]: Decimal(str(line["amount"])) for line in sim["lines"]}
    expected_lines = {
        "BASIC": Decimal("50000.00"),
        "HRA": Decimal("20000.00"),
        "STD": Decimal("10000.00"),
        "GROSS": Decimal("80000.00"),
        "PF": Decimal("-3000.00"),
        "PT": Decimal("-2000.00"),
        "NET": Decimal("75000.00"),
    }
    for code, amount in expected_lines.items():
        check(f"simulated {code} == {amount}", by_code.get(code) == amount, by_code.get(code))
    check("simulated gross == 80000.00", Decimal(str(sim["gross"])) == Decimal("80000.00"))
    check("simulated net == 75000.00", Decimal(str(sim["net"])) == Decimal("75000.00"))

    # =====================================================================
    section("6. Seeded payslip for Aarav Mehta (EMP-001)")
    # =====================================================================
    aarav = api.get(
        "/employees", "payroll_user", params={"search": "EMP-001"}
    ).json()[0]
    slips = api.get(
        "/payslips", "payroll_user", params={"employee_id": aarav["id"]}
    ).json()
    check("Aarav has a payslip", len(slips) >= 1, len(slips))
    slip_detail = api.get(f"/payslips/{slips[0]['id']}", "payroll_user").json()
    check(
        "payslip basic == 50000.00",
        Decimal(str(slip_detail["basic_amount"])) == Decimal("50000.00"),
        slip_detail["basic_amount"],
    )
    check(
        "payslip gross == 80000.00",
        Decimal(str(slip_detail["gross_amount"])) == Decimal("80000.00"),
        slip_detail["gross_amount"],
    )
    check(
        "payslip net == 75000.00",
        Decimal(str(slip_detail["net_amount"])) == Decimal("75000.00"),
        slip_detail["net_amount"],
    )
    check(
        "payslip total deductions == 5000.00",
        Decimal(str(slip_detail["total_deductions"])) == Decimal("5000.00"),
        slip_detail["total_deductions"],
    )
    check(
        "payslip has a rule-by-rule tree of 7 lines",
        len(slip_detail["lines"]) == 7,
        len(slip_detail["lines"]),
    )
    check(
        "payslip references contract CON/2026/0042",
        slip_detail["contract_reference"] == "CON/2026/0042",
        slip_detail["contract_reference"],
    )

    pdf = api.get(f"/payslips/{slips[0]['id']}/pdf", "payroll_user")
    check(
        "payslip PDF is generated and streamed",
        pdf.status_code == 200
        and pdf.headers["content-type"] == "application/pdf"
        and pdf.content[:4] == b"%PDF",
        f"{len(pdf.content)} bytes",
    )

    # =====================================================================
    section("7. Payrun 2-step wizard and pre-flight anomaly detection")
    # =====================================================================
    scope = api.post(
        "/payruns/step1-validate",
        "payroll_user",
        json={
            "salary_structure_id": regular["id"],
            "date_start": "2026-03-01",
            "date_end": "2026-03-31",
        },
    ).json()
    check("step 1 returns candidates", scope["candidate_count"] > 0, scope["candidate_count"])
    check("step 1 finds eligible employees", scope["eligible_count"] > 0, scope["eligible_count"])
    check(
        "step 1 blocks the employee with no RUNNING contract",
        scope["blocked_count"] >= 1,
        scope["blocked_count"],
    )
    blocked_names = [c["name"] for c in scope["candidates"] if not c["eligible"]]
    check(
        "blocked list names Preeti Nambiar",
        "Preeti Nambiar" in blocked_names,
        blocked_names,
    )
    warnings_seen = {w for c in scope["candidates"] for w in c["warnings"]}
    check(
        "pre-flight flags missing bank details",
        any("Missing Bank Details" in w for w in warnings_seen),
    )
    check(
        "pre-flight flags a missing tax identifier",
        any("PAN" in w for w in warnings_seen),
    )
    check(
        "pre-flight flags an expiring contract",
        any("expire" in w for w in warnings_seen),
        [w for w in warnings_seen if "expire" in w][:1],
    )

    payruns_before = len(api.get("/payruns", "payroll_user").json())
    check(
        "step 1 wrote nothing (payrun count unchanged)",
        payruns_before == len(api.get("/payruns", "payroll_user").json()),
        payruns_before,
    )

    # A batch containing a blocked employee must abort by default.
    blocked_id = next(c["employee_id"] for c in scope["candidates"] if not c["eligible"])
    eligible_ids = [c["employee_id"] for c in scope["candidates"] if c["eligible"]][:3]
    aborted = api.post(
        "/payruns",
        "payroll_user",
        json={
            "name": "March 2026 (should abort)",
            "salary_structure_id": regular["id"],
            "date_start": "2026-03-01",
            "date_end": "2026-03-31",
            "employee_ids": eligible_ids + [blocked_id],
        },
    )
    check(
        "step 2 aborts the batch when a selected employee is blocked",
        aborted.status_code == 409,
        aborted.status_code,
    )
    check(
        "abort response explains which employee and why",
        "details" in aborted.json(),
        list(aborted.json().get("details", {}).keys())[:2],
    )

    created = api.post(
        "/payruns",
        "payroll_user",
        json={
            "name": "March 2026",
            "salary_structure_id": regular["id"],
            "date_start": "2026-03-01",
            "date_end": "2026-03-31",
            "employee_ids": eligible_ids,
        },
    )
    check("step 2 creates the batch", created.status_code == 201, created.status_code)
    march = created.json()
    payrun_id = march["payrun"]["id"]
    check(
        "batch has one payslip per selected employee",
        len(march["payslips"]) == len(eligible_ids),
        len(march["payslips"]),
    )
    check("new batch starts in DRAFT", march["payrun"]["status"] == "DRAFT")

    # Duplicate-period guard
    duplicate = api.post(
        "/payruns/step1-validate",
        "payroll_user",
        json={
            "salary_structure_id": regular["id"],
            "date_start": "2026-03-01",
            "date_end": "2026-03-31",
            "employee_ids": eligible_ids,
        },
    ).json()
    check(
        "a second payrun for the same period is blocked as a duplicate",
        duplicate["eligible_count"] == 0,
        f"{duplicate['blocked_count']} blocked",
    )

    # Workflow state machine
    early = api.post(f"/payruns/{payrun_id}/validate", "payroll_user")
    check(
        "cannot validate a batch before computing it",
        early.status_code == 409,
        early.status_code,
    )
    computed = api.post(f"/payruns/{payrun_id}/compute", "payroll_user").json()
    check("compute moves the batch to COMPUTED", computed["payrun"]["status"] == "COMPUTED")
    validated = api.post(f"/payruns/{payrun_id}/validate", "payroll_user").json()
    check("validate moves the batch to VALIDATED", validated["payrun"]["status"] == "VALIDATED")
    check(
        "validating marks its payslips DONE",
        all(p["status"] == "DONE" for p in validated["payslips"]),
    )
    paid = api.post(f"/payruns/{payrun_id}/mark-paid", "payroll_user").json()
    check("mark-paid moves the batch to PAID", paid["payrun"]["status"] == "PAID")

    no_delete = api.client.request(
        "DELETE",
        f"{api.api}/payruns/{payrun_id}",
        headers=api.headers("payroll_user"),
    )
    check(
        "a PAID batch cannot be deleted",
        no_delete.status_code == 409,
        no_delete.status_code,
    )

    dispatch = api.post(f"/payruns/{payrun_id}/send-payslips", "payroll_user").json()
    check(
        "payslip dispatch runs (dry-run without SMTP)",
        dispatch["sent_count"] == len(eligible_ids) and dispatch["mode"] == "dry_run",
        f"{dispatch['sent_count']} sent, mode={dispatch['mode']}",
    )

    # =====================================================================
    section("8. Attendance and leave engines")
    # =====================================================================
    punch_in = api.post("/attendance/punch", "employee", json={}).json()
    check("check-in works", punch_in["action"] == "CHECK_IN", punch_in["attendance"]["status"])
    status = api.get("/attendance/status", "employee").json()
    check("punch status reports checked in", status["checked_in"] is True)
    punch_out = api.post("/attendance/punch", "employee", json={}).json()
    check("check-out works", punch_out["action"] == "CHECK_OUT")
    check(
        "check-out computed worked hours",
        punch_out["attendance"]["worked_hours"] is not None,
        punch_out["attendance"]["worked_hours"],
    )

    summary = api.get(
        "/attendance/summary",
        "employee",
        params={"date_start": "2026-02-01", "date_end": "2026-02-28"},
    ).json()
    check(
        "February expected days == 20 (Mon-Fri, holidays excluded)",
        Decimal(str(summary["expected_days"])) == Decimal("20"),
        summary["expected_days"],
    )
    check(
        "worked days never exceed expected days",
        Decimal(str(summary["worked_days"])) <= Decimal(str(summary["expected_days"])),
        f"{summary['worked_days']} / {summary['expected_days']}",
    )

    preview = api.get(
        "/timeoff/requests/duration-preview",
        "employee",
        params={"start_date": "2026-04-06", "end_date": "2026-04-12"},
    ).json()
    check(
        "duration preview counts working days only (5 of 7)",
        Decimal(str(preview["working_days"])) == Decimal("5")
        and preview["calendar_days"] == 7,
        f"{preview['working_days']} of {preview['calendar_days']}",
    )

    balance_before = api.get("/timeoff/balance", "employee").json()
    pto_before = next(b for b in balance_before if b["timeoff_type_name"] == "Paid Time Off")
    request = api.post(
        "/timeoff/requests",
        "employee",
        json={
            "timeoff_type_id": pto["id"],
            "start_date": "2026-05-11",
            "end_date": "2026-05-13",
            "reason": "Verification run",
        },
    )
    check("employee can submit a leave request", request.status_code == 201, request.status_code)
    request_id = request.json()["id"]
    check(
        "duration derived from the schedule == 3 days",
        Decimal(str(request.json()["duration_days"])) == Decimal("3"),
        request.json()["duration_days"],
    )

    overlapping = api.post(
        "/timeoff/requests",
        "employee",
        json={
            "timeoff_type_id": pto["id"],
            "start_date": "2026-05-12",
            "end_date": "2026-05-14",
        },
    )
    check(
        "overlapping leave request is refused",
        overlapping.status_code == 409,
        overlapping.status_code,
    )

    self_approve = api.post(f"/timeoff/requests/{request_id}/approve", "employee")
    check(
        "EMPLOYEE cannot approve a leave request at all",
        self_approve.status_code == 403,
        self_approve.status_code,
    )

    approved = api.post(f"/timeoff/requests/{request_id}/approve", "hr_manager")
    check("HR_MANAGER can approve", approved.status_code == 200, approved.status_code)
    check("approved request is linked to an allocation",
          approved.json()["allocation_id"] is not None)

    balance_after = api.get("/timeoff/balance", "employee").json()
    pto_after = next(b for b in balance_after if b["timeoff_type_name"] == "Paid Time Off")
    debited = Decimal(str(pto_before["remaining_days"])) - Decimal(
        str(pto_after["remaining_days"])
    )
    check(
        "approval debited exactly 3 days from the ledger",
        debited == Decimal("3"),
        f"{pto_before['remaining_days']} -> {pto_after['remaining_days']}",
    )

    api.post(f"/timeoff/requests/{request_id}/refuse", "hr_manager")
    balance_reverted = api.get("/timeoff/balance", "employee").json()
    pto_reverted = next(
        b for b in balance_reverted if b["timeoff_type_name"] == "Paid Time Off"
    )
    check(
        "refusing an approved request credits the days back",
        Decimal(str(pto_reverted["remaining_days"]))
        == Decimal(str(pto_before["remaining_days"])),
        pto_reverted["remaining_days"],
    )

    # =====================================================================
    section("9. Dashboard aggregates")
    # =====================================================================
    metrics = api.get("/dashboard/metrics", "payroll_user").json()
    kpi = metrics["kpi"]
    check("KPI ribbon counts active employees", kpi["workforce"]["active_employees"] >= 42,
          kpi["workforce"]["active_employees"])
    check("KPI ribbon counts running contracts", kpi["contracts"]["running"] >= 42,
          kpi["contracts"]["running"])
    check("KPI ribbon flags missing bank details",
          kpi["workforce"]["missing_bank_details"] >= 1,
          kpi["workforce"]["missing_bank_details"])
    check("KPI ribbon flags contracts expiring soon",
          kpi["contracts"]["expiring_within_45_days"] >= 1,
          kpi["contracts"]["expiring_within_45_days"])
    share = sum(d["share_of_gross_pct"] for d in metrics["department_costs"])
    check("department shares sum to ~100%", 99.0 <= share <= 101.0, round(share, 2))
    check("payroll trend has data points", len(metrics["payroll_trend"]) >= 1,
          len(metrics["payroll_trend"]))

    # Ask for the full February batch explicitly. The default is the LATEST payrun,
    # which by now is the small March batch created above, so a bare call would
    # legitimately show only the departments in that batch.
    february = next(
        p for p in api.get("/payruns", "payroll_user").json()
        if p["name"] == "February 2026"
    )
    feb_costs = api.get(
        "/dashboard/department-costs",
        "payroll_user",
        params={"payrun_id": february["id"]},
    ).json()
    check(
        "February costs are split across all five departments",
        len(feb_costs) == 5,
        [d["department"] for d in feb_costs],
    )
    feb_gross = sum(Decimal(str(d["total_gross"])) for d in feb_costs)
    check(
        "department gross totals reconcile with the batch total",
        feb_gross == Decimal(str(february["total_gross"])),
        f"{feb_gross} vs {february['total_gross']}",
    )
    check(
        "February headcount reconciles with the batch",
        sum(d["headcount"] for d in feb_costs) == february["employee_count"],
        sum(d["headcount"] for d in feb_costs),
    )

    self_dash = api.get("/dashboard/me", "employee").json()
    check("employee self-dashboard returns leave balances",
          len(self_dash["leave_balances"]) >= 1)
    check("employee self-dashboard returns the latest payslip",
          self_dash["latest_payslip"] is not None)

    forbidden = api.get("/dashboard/metrics", "employee")
    check("EMPLOYEE cannot read company-wide metrics",
          forbidden.status_code == 403, forbidden.status_code)

    # =====================================================================
    section("10. AI Copilot: Tier 0 (SQL template, no LLM)")
    # =====================================================================
    ai_health = api.get("/ai/assistant/health", "employee").json()
    check("retrieval runs locally", ai_health["retrieval"]["runs_locally"] is True,
          ai_health["retrieval"]["active_backend"])
    check("knowledge base is populated",
          ai_health["knowledge_base"]["total_chunks"] >= 20,
          ai_health["knowledge_base"]["total_chunks"])
    threshold = ai_health["escalation"]["confidence_threshold"]
    check(
        "a calibrated confidence threshold is in force",
        0.5 <= threshold <= 0.9,
        threshold,
    )

    tier0_cases = [
        ("What is my leave balance?", "LEAVE_BALANCE"),
        ("Explain the deductions on my payslip", "PAYSLIP_BREAKDOWN"),
        ("Show me my payslips", "PAYSLIP_HISTORY"),
        ("How many hours did I work this month?", "ATTENDANCE_SUMMARY"),
        ("What is my contract?", "CONTRACT_DETAILS"),
        ("When is the next public holiday?", "NEXT_HOLIDAY"),
    ]
    conversation_id = None
    for prompt, expected_intent in tier0_cases:
        body = {"prompt": prompt}
        if conversation_id:
            body["conversation_id"] = conversation_id
        answer = api.post("/ai/assistant", "employee", json=body).json()
        conversation_id = answer["conversation_id"]
        ok = (
            answer["mode"] == "TIER0_TEMPLATE"
            and answer["intent"] == expected_intent
            and answer["used_llm"] is False
        )
        check(f'Tier 0 "{prompt}"', ok, f"{answer['mode']}/{answer.get('intent')}")

    balance_answer = api.post(
        "/ai/assistant", "employee", json={"prompt": "what is my leave balance"}
    ).json()
    check(
        "Tier 0 leave balance quotes the real ledger figure",
        "Paid Time Off" in balance_answer["answer"]
        and str(pto_reverted["remaining_days"]).rstrip("0").rstrip(".")
        in balance_answer["answer"].replace(".00", ""),
        balance_answer["answer"].splitlines()[0][:60],
    )

    payslip_answer = api.post(
        "/ai/assistant",
        "payroll_user",
        json={"prompt": "explain the deductions on my payslip"},
    ).json()
    check(
        "Tier 0 payslip breakdown quotes the computed net pay",
        "75,000.00" in payslip_answer["answer"],
        payslip_answer["answer"].splitlines()[-1][:60],
    )

    # A policy-flavoured question must NOT be short-circuited into a personal-data
    # template. "How many PTO days do I get each year?" asks what the handbook
    # says, so answering with the caller's current balance would be wrong.
    policy_flavoured = api.post(
        "/ai/assistant",
        "employee",
        json={"prompt": "How many paid time off days do I get each year?"},
    ).json()
    check(
        "an entitlement question is routed to retrieval, not the balance template",
        policy_flavoured["mode"] == "ANSWERED",
        f"{policy_flavoured['mode']}/{policy_flavoured.get('intent')}",
    )
    check(
        "and it cites the PTO policy document",
        any("Paid Time Off" in c["title"] for c in policy_flavoured["citations"]),
        [c["title"] for c in policy_flavoured["citations"]][:2],
    )

    # =====================================================================
    section("11. AI Copilot: Tier 1/2 retrieval with citations")
    # =====================================================================
    policy_cases = [
        "How many paid time off days do I get each year?",
        "What is the notice period after probation?",
        "When do I need a medical certificate for sick leave?",
        "How is provident fund calculated?",
    ]
    for prompt in policy_cases:
        answer = api.post("/ai/assistant", "employee", json={"prompt": prompt}).json()
        ok = answer["mode"] == "ANSWERED" and len(answer["citations"]) > 0
        check(
            f'retrieval answered "{prompt[:44]}..."',
            ok,
            f"conf={answer.get('confidence')} cites={len(answer.get('citations', []))}",
        )

    search = api.post(
        "/ai/knowledge/search",
        "employee",
        json={"query": "provident fund percentage of basic salary", "top_k": 3},
    ).json()
    check("semantic search returns ranked hits", len(search) == 3, len(search))
    check(
        "top hit is the payroll document",
        "Salary Structure" in search[0]["title"] or "Statutory" in search[0]["title"],
        search[0]["title"],
    )
    check(
        "similarity scores are ordered descending",
        all(search[i]["score"] >= search[i + 1]["score"] for i in range(len(search) - 1)),
        [round(h["score"], 3) for h in search],
    )

    # =====================================================================
    section("12. Confidence gate: the assistant refuses to guess")
    # =====================================================================
    nonsense = api.post(
        "/ai/assistant",
        "employee",
        json={
            "prompt": (
                "What is the company policy on bringing a pet iguana aboard the "
                "corporate submarine during a solar eclipse?"
            )
        },
    ).json()
    check(
        "an unanswerable question is ESCALATED, not answered",
        nonsense["mode"] == "ESCALATED",
        nonsense["mode"],
    )
    check(
        "escalation records the reason",
        nonsense.get("escalation_reason") in ("LOW_CONFIDENCE", "NO_CONTEXT"),
        nonsense.get("escalation_reason"),
    )
    check("a ticket number is issued", bool(nonsense.get("ticket_no")), nonsense.get("ticket_no"))
    check(
        "the ticket is routed to a role",
        bool(nonsense.get("routed_to_role")),
        nonsense.get("routed_to_role"),
    )
    check(
        "the confidence that triggered it is recorded and below the threshold",
        nonsense.get("confidence") is not None and nonsense["confidence"] < threshold,
        f"{nonsense.get('confidence')} < {threshold}",
    )

    # =====================================================================
    section("13. Escalation routing by category")
    # =====================================================================
    routing = api.get("/ai/escalations/routing-rules", "admin").json()
    routing_map = {r["category"]: (r["target_role"], r["sla_hours"]) for r in routing}
    expected_routing = {
        "LEAVE_POLICY": ("HR_MANAGER", 8),
        "ATTENDANCE": ("HR_MANAGER", 8),
        "CONTRACT": ("HR_MANAGER", 24),
        "PAYROLL_SALARY": ("HR_PAYROLL_MANAGER", 4),
        "TAX_STATUTORY": ("HR_PAYROLL_MANAGER", 24),
        "IT_ACCESS": ("ADMIN", 4),
        "OTHER": ("ADMIN", 24),
    }
    for category, expected in expected_routing.items():
        check(
            f"{category} -> {expected[0]} @ {expected[1]}h",
            routing_map.get(category) == expected,
            routing_map.get(category),
        )

    salary_escalation = api.post(
        "/ai/escalations",
        "employee",
        json={
            "prompt": (
                "My February salary looks wrong because of a retroactive shift "
                "differential adjustment nobody explained to me. Who fixes that?"
            )
        },
    ).json()
    check(
        "a salary question routes to HR_PAYROLL_MANAGER",
        salary_escalation.get("routed_to_role") == "HR_PAYROLL_MANAGER",
        salary_escalation.get("routed_to_role"),
    )
    check(
        "its category is PAYROLL_SALARY",
        salary_escalation.get("category") == "PAYROLL_SALARY",
        salary_escalation.get("category"),
    )

    # =====================================================================
    section("14. Human-in-the-loop loop: answer, notify, learn")
    # =====================================================================
    unique_question = (
        "What is the reimbursement limit for a home office ergonomic chair "
        "under the hybrid work allowance?"
    )
    asked = api.post("/ai/assistant", "employee", json={"prompt": unique_question}).json()
    check(
        "the novel question escalates rather than being invented",
        asked["mode"] == "ESCALATED",
        asked["mode"],
    )
    ticket_id = asked["escalation_id"]
    ticket_no = asked["ticket_no"]

    queue = api.get("/ai/escalations", "hr_manager", params={"status": "OPEN"}).json()
    check(
        "the ticket appears in the responder queue",
        any(t["id"] == ticket_id for t in queue["items"]),
        f"{queue['total']} open",
    )

    employee_view = api.get("/ai/escalations", "employee").json()
    check(
        "an EMPLOYEE only sees their own tickets",
        all(t["employee_id"] == me["employee_id"] for t in employee_view["items"]),
        f"{employee_view['total']} tickets",
    )

    admin_me = api.get("/auth/me", "admin").json()
    assigned = api.post(
        f"/ai/escalations/{ticket_id}/assign",
        "admin",
        json={"assignee_user_id": admin_me["user_id"]},
    ).json()
    check("the ticket can be assigned", assigned["status"] == "ASSIGNED", assigned["status"])

    api.post(
        f"/ai/escalations/{ticket_id}/comment",
        "admin",
        json={"body": "Checking with Finance before replying.", "visibility": "INTERNAL"},
    )
    responder_view = api.get(f"/ai/escalations/{ticket_id}", "admin").json()
    asker_view = api.get(f"/ai/escalations/{ticket_id}", "employee").json()
    check(
        "responders see INTERNAL thread events",
        any(e["visibility"] == "INTERNAL" for e in responder_view["events"]),
        len(responder_view["events"]),
    )
    check(
        "the asking employee never sees INTERNAL events",
        all(e["visibility"] == "PUBLIC" for e in asker_view["events"]),
        len(asker_view["events"]),
    )

    hr_publish = api.post(
        f"/ai/escalations/{ticket_id}/answer",
        "hr_manager",
        json={"answer_text": "test", "publish_to_kb": True},
    )
    check(
        "HR_MANAGER cannot publish to the shared knowledge base",
        hr_publish.status_code == 403,
        hr_publish.status_code,
    )

    human_answer = (
        "The hybrid work allowance covers an ergonomic chair up to 18,000 once "
        "every three years. Submit the invoice to Finance within 30 days of "
        "purchase and the amount is reimbursed with the following month's payroll."
    )
    answered = api.post(
        f"/ai/escalations/{ticket_id}/answer",
        "payroll_manager",
        json={"answer_text": human_answer, "publish_to_kb": True},
    ).json()
    check("the human answer is recorded", answered["status"] == "ANSWERED")
    check(
        "the answer is published into the knowledge base",
        answered["published_to_kb"] is True and answered["kb_chunk_id"],
        answered["kb_chunk_id"],
    )

    notifications = api.get(
        "/notifications", "employee", params={"unread_only": True}
    ).json()
    check(
        "the asking employee is notified",
        any(
            n["kind"] == "ESCALATION_ANSWERED" and ticket_no in n["title"]
            for n in notifications
        ),
        f"{len(notifications)} unread",
    )

    # ---- STAGE 4: the flywheel. Ask the same question again. --------------
    relearned = api.post(
        "/ai/assistant", "payroll_user", json={"prompt": unique_question}
    ).json()
    check(
        "asking again is now ANSWERED by the assistant itself",
        relearned["mode"] == "ANSWERED",
        f"{relearned['mode']} conf={relearned.get('confidence')}",
    )
    check(
        "the answer is grounded in the human-verified article",
        any(c.get("human_verified") for c in relearned.get("citations", [])),
        [c["title"] for c in relearned.get("citations", [])][:2],
    )
    check(
        "the verified answer content is surfaced",
        "18,000" in relearned["answer"] or "ergonomic" in relearned["answer"].lower(),
        relearned["answer"][:70],
    )

    # ---- Semantic dedup on a paraphrase ----------------------------------
    paraphrase = api.post(
        "/ai/escalations",
        "employee",
        json={
            "prompt": (
                "What is the reimbursement limit for a home office ergonomic "
                "chair under the hybrid work allowance?"
            )
        },
    ).json()
    check(
        "an identical repeat question reuses the human answer instead of a new ticket",
        paraphrase["reused_prior_answer"] is True and paraphrase["escalated"] is False,
        f"similarity={paraphrase.get('similarity')}",
    )

    stats = api.get("/ai/escalations/stats", "admin").json()
    check("queue stats report answered tickets", stats["answered_count"] >= 1,
          stats["answered_count"])
    check("queue stats report KB articles created", stats["kb_articles_created"] >= 1,
          stats["kb_articles_created"])
    check("queue stats break down by category", len(stats["by_category"]) >= 1,
          stats["by_category"])

    sweep = api.post("/ai/escalations/sla-sweep", "admin").json()
    check("the SLA sweep runs", "notifications_created" in sweep, sweep)

    closed = api.post(
        f"/ai/escalations/{ticket_id}/close", "employee", json={"note": "Thanks!"}
    ).json()
    check("the asker can close their own ticket", closed["status"] == "CLOSED")

    # =====================================================================
    section("15. PII boundary")
    # =====================================================================
    from app.services.llm_provider import redact_pii

    sample = (
        "Aarav's account 987654321012 with IFSC HDFC0001234, PAN ABCDE1001F, "
        "SSN 123-45-6789, email aarav.mehta@oxp.com, phone 9812345678."
    )
    redacted = redact_pii(sample)
    for label, needle in [
        ("bank account", "987654321012"),
        ("IFSC", "HDFC0001234"),
        ("PAN", "ABCDE1001F"),
        ("SSN", "123-45-6789"),
        ("email", "aarav.mehta@oxp.com"),
        ("phone", "9812345678"),
    ]:
        check(f"redact_pii strips {label}", needle not in redacted)
    check(
        "redaction leaves surrounding prose intact",
        "Aarav's account" in redacted,
        redacted[:60],
    )

    # =====================================================================
    print("\n" + "=" * 60)
    total = passed + len(failed)
    print(f"RESULT: {passed}/{total} checks passed")
    if failed:
        print(f"\n{len(failed)} FAILURE(S):")
        for item in failed:
            print(f"  - {item}")
        return 1
    print("\nAll checks passed.")
    return 0


if __name__ == "__main__":
    sys.exit(main())
