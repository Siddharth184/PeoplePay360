"""Adversarial end-to-end audit of the PeoplePay360 API.

Where `verify_api.py` proves the happy paths and the documented guarantees, this
suite attacks the system: it tries to escalate privilege, corrupt the leave
ledger, rewrite paid payroll, break the payrun state machine, race two approvals
against one balance, and read other people's data.

Every check below exists because it maps to something that goes wrong in real
HR/payroll deployments. Run it against a freshly seeded database:

    python -m scripts.init_db
    python -m scripts.seed_db
    python -m uvicorn app.main:app --port 8100
    python -m scripts.verify_deep

It creates its own fixtures (a throwaway department, employee, contract and
login) so the demo data stays intact.
"""

from __future__ import annotations

import argparse
import concurrent.futures
import sys
import uuid
from datetime import date, datetime, timedelta, timezone
from decimal import Decimal
from pathlib import Path
from typing import Any, Dict, Optional

import httpx

sys.path.insert(0, str(Path(__file__).resolve().parents[1]))

PASSWORD = "PeoplePay@360"
ACCOUNTS = {
    "admin": "admin@oxp.com",
    "payroll_manager": "vikram.nair@oxp.com",
    "payroll_user": "aarav.mehta@oxp.com",
    "hr_manager": "sara.khan@oxp.com",
    "employee": "priya.sharma@oxp.com",
    "employee2": "ananya.iyer@oxp.com",
}

passed = 0
failed: list[str] = []
section_name = ""


def section(title: str) -> None:
    global section_name
    section_name = title
    print(f"\n{title}")
    print("-" * 74)


def check(label: str, condition: bool, detail: Any = "") -> bool:
    global passed
    if condition:
        passed += 1
        print(f"  PASS  {label}" + (f"  [{detail}]" if detail != "" else ""))
        return True
    failed.append(f"{section_name} :: {label}  {detail}")
    print(f"  FAIL  {label}  {detail}")
    return False


def status_of(response: httpx.Response) -> int:
    return response.status_code


class Api:
    def __init__(self, base_url: str) -> None:
        self.base = base_url.rstrip("/")
        self.api = f"{self.base}/api/v1"
        self.client = httpx.Client(timeout=120.0, follow_redirects=True)
        self.tokens: dict[str, str] = {}

    def login(self, alias: str, email: str | None = None, password: str = PASSWORD) -> dict:
        response = self.client.post(
            f"{self.api}/auth/login",
            json={"email": email or ACCOUNTS[alias], "password": password},
        )
        response.raise_for_status()
        payload = response.json()
        self.tokens[alias] = payload["access_token"]
        return payload

    def headers(self, alias: str | None) -> dict:
        if alias is None:
            return {}
        return {"Authorization": f"Bearer {self.tokens[alias]}"}

    def raw_headers(self, token: str) -> dict:
        return {"Authorization": f"Bearer {token}"}

    def req(self, method: str, path: str, alias: str | None = None, **kw) -> httpx.Response:
        headers = self.headers(alias)
        headers.update(kw.pop("headers", {}))
        return self.client.request(method, f"{self.api}{path}", headers=headers, **kw)

    def get(self, p, a=None, **kw):
        return self.req("GET", p, a, **kw)

    def post(self, p, a=None, **kw):
        return self.req("POST", p, a, **kw)

    def patch(self, p, a=None, **kw):
        return self.req("PATCH", p, a, **kw)

    def put(self, p, a=None, **kw):
        return self.req("PUT", p, a, **kw)

    def delete(self, p, a=None, **kw):
        return self.req("DELETE", p, a, **kw)


def main() -> int:  # noqa: C901 - a linear audit script reads better flat
    parser = argparse.ArgumentParser()
    parser.add_argument("--base-url", default="http://127.0.0.1:8100")
    args = parser.parse_args()

    api = Api(args.base_url)
    print("PeoplePay360 adversarial audit")
    print("=" * 74)
    print(f"Target: {api.base}")

    for alias in ACCOUNTS:
        api.login(alias)
    admin_me = api.get("/auth/me", "admin").json()
    hr_me = api.get("/auth/me", "hr_manager").json()
    employee_me = api.get("/auth/me", "employee").json()
    employee2_me = api.get("/auth/me", "employee2").json()

    # =====================================================================
    section("1. Session revocation (JWTs must not outlive their authority)")
    # =====================================================================
    victim = api.login("victim", ACCOUNTS["employee2"])
    victim_token = victim["access_token"]
    check(
        "a freshly issued token works",
        status_of(
            api.client.get(
                f"{api.api}/auth/me", headers=api.raw_headers(victim_token)
            )
        )
        == 200,
    )

    api.patch(
        f"/users/{victim['user_id']}", "admin", json={"is_active": False}
    )
    check(
        "deactivating the account kills its live token",
        status_of(
            api.client.get(
                f"{api.api}/auth/me", headers=api.raw_headers(victim_token)
            )
        )
        == 401,
    )
    api.patch(f"/users/{victim['user_id']}", "admin", json={"is_active": True})

    # Demotion must strip privilege immediately, not at token expiry.
    privileged = api.login("temp_mgr", ACCOUNTS["payroll_manager"])
    mgr_token = privileged["access_token"]
    check(
        "payroll manager can read structures",
        status_of(
            api.client.get(
                f"{api.api}/salary-structures", headers=api.raw_headers(mgr_token)
            )
        )
        == 200,
    )
    api.patch(
        f"/users/{privileged['user_id']}", "admin", json={"role": "EMPLOYEE"}
    )
    check(
        "demotion revokes the old privileged token",
        status_of(
            api.client.get(
                f"{api.api}/salary-structures", headers=api.raw_headers(mgr_token)
            )
        )
        == 401,
    )
    api.patch(
        f"/users/{privileged['user_id']}",
        "admin",
        json={"role": "HR_PAYROLL_MANAGER"},
    )
    api.login("payroll_manager")
    check(
        "re-login after restore works immediately",
        status_of(api.get("/salary-structures", "payroll_manager")) == 200,
    )

    # A tampered token must be rejected outright.
    forged = victim_token[:-6] + "AAAAAA"
    check(
        "a token with a broken signature is rejected",
        status_of(
            api.client.get(f"{api.api}/auth/me", headers=api.raw_headers(forged))
        )
        == 401,
    )
    check(
        "a garbage bearer token is rejected",
        status_of(
            api.client.get(
                f"{api.api}/auth/me", headers=api.raw_headers("not-a-jwt")
            )
        )
        == 401,
    )
    check(
        "no bearer token at all is rejected",
        status_of(api.client.get(f"{api.api}/auth/me")) == 403,
    )

    # =====================================================================
    section("2. Privilege escalation attempts")
    # =====================================================================
    escalations = [
        ("employee promotes themselves to ADMIN", "employee",
         "PATCH", f"/users/{employee_me['user_id']}", {"role": "ADMIN"}),
        ("HR manager promotes themselves", "hr_manager",
         "PATCH", f"/users/{hr_me['user_id']}", {"role": "ADMIN"}),
        ("employee creates an ADMIN account", "employee",
         "POST", "/users",
         {"email": "backdoor@oxp.com", "password": "Backdoor@123", "role": "ADMIN"}),
        ("payroll manager creates a user", "payroll_manager",
         "POST", "/users",
         {"email": "backdoor2@oxp.com", "password": "Backdoor@123", "role": "ADMIN"}),
        ("employee edits a salary rule", "employee",
         "PATCH", "/salary-structures/rules/" + str(uuid.uuid4()),
         {"percentage_rate": "99.00"}),
        ("HR manager changes escalation routing", "hr_manager",
         "PUT", f"/ai/escalations/routing-rules/{uuid.uuid4()}", {"sla_hours": 1}),
    ]
    for label, alias, method, path, body in escalations:
        response = api.req(method, path, alias, json=body)
        check(f"blocked: {label}", response.status_code == 403, response.status_code)

    # HR_MANAGER must not see banking data even on a single record.
    target_employee_id = employee_me["employee_id"]
    hr_view = api.get(f"/employees/{target_employee_id}", "hr_manager").json()
    check(
        "HR manager cannot read bank details on a profile",
        hr_view["bank_account_number"] is None,
    )
    hr_write = api.patch(
        f"/employees/{target_employee_id}",
        "hr_manager",
        json={"bank_account_number": "111122223333"},
    )
    check(
        "HR manager cannot write bank details",
        hr_write.status_code == 422,
        hr_write.status_code,
    )

    # =====================================================================
    section("3. Cross-employee data isolation")
    # =====================================================================
    other_employee_id = employee2_me["employee_id"]
    isolation = [
        ("read another employee's profile", f"/employees/{other_employee_id}"),
        ("read another employee's contracts", f"/contracts?employee_id={other_employee_id}"),
    ]
    response = api.get(f"/employees/{other_employee_id}", "employee")
    check(
        "employee cannot read another profile",
        response.status_code == 403,
        response.status_code,
    )

    # Filter injection: asking for someone else's rows must be ignored, not obeyed.
    leaked = api.get(
        f"/attendance?employee_id={other_employee_id}", "employee"
    ).json()
    check(
        "employee_id filter cannot be used to read another's attendance",
        all(r["employee_id"] == employee_me["employee_id"] for r in leaked),
        f"{len(leaked)} rows, all own: "
        f"{all(r['employee_id'] == employee_me['employee_id'] for r in leaked)}",
    )
    leaked_slips = api.get(
        f"/payslips?employee_id={other_employee_id}", "employee"
    ).json()
    check(
        "employee_id filter cannot be used to read another's payslips",
        all(r["employee_id"] == employee_me["employee_id"] for r in leaked_slips),
        f"{len(leaked_slips)} rows",
    )
    leaked_alloc = api.get(
        f"/timeoff/allocations?employee_id={other_employee_id}", "employee"
    ).json()
    check(
        "employee_id filter cannot be used to read another's allocations",
        all(r["employee_id"] == employee_me["employee_id"] for r in leaked_alloc),
        f"{len(leaked_alloc)} rows",
    )

    other_slips = api.get(
        f"/payslips?employee_id={other_employee_id}", "payroll_user"
    ).json()
    if other_slips:
        foreign_slip = other_slips[0]["id"]
        check(
            "employee cannot open another's payslip detail",
            api.get(f"/payslips/{foreign_slip}", "employee").status_code == 403,
        )
        check(
            "employee cannot download another's payslip PDF",
            api.get(f"/payslips/{foreign_slip}/pdf", "employee").status_code == 403,
        )

    # Punching in for somebody else.
    check(
        "employee cannot punch on another employee's behalf",
        api.post(
            "/attendance/punch", "employee", json={"employee_id": other_employee_id}
        ).status_code
        == 403,
    )
    check(
        "employee cannot file leave for another employee",
        api.post(
            "/timeoff/requests",
            "employee",
            json={
                "employee_id": other_employee_id,
                "timeoff_type_id": str(uuid.uuid4()),
                "start_date": "2026-08-03",
                "end_date": "2026-08-04",
            },
        ).status_code
        == 403,
    )

    # =====================================================================
    section("4. Fixtures for the mutation flows")
    # =====================================================================
    stamp = datetime.now(timezone.utc).strftime("%H%M%S")
    dept = api.post(
        "/departments", "admin", json={"name": f"Audit Dept {stamp}"}
    ).json()
    position = api.post(
        "/job-positions",
        "admin",
        json={"name": f"Audit Analyst {stamp}", "department_id": dept["id"]},
    ).json()
    schedules = api.get("/schedules", "admin").json()
    schedule_40h = next(s for s in schedules if s["name"] == "40 Hours / Week")

    subject = api.post(
        "/employees",
        "admin",
        json={
            "name": f"Audit Subject {stamp}",
            "work_email": f"audit.subject.{stamp}@oxp.com",
            "department_id": dept["id"],
            "job_position_id": position["id"],
            "working_schedule_id": schedule_40h["id"],
            "employee_type": "PERMANENT",
            "date_of_joining": "2026-01-01",
            "bank_account_number": "555566667777",
            "bank_name": "Audit Bank",
            "bank_ifsc_or_routing": "AUDT0001234",
            "pan_or_ssn": "AUDTX1234Z",
            "create_login": True,
            "login_password": "AuditSubject@123",
            "login_role": "EMPLOYEE",
        },
    )
    check("fixture employee created", subject.status_code == 201, subject.status_code)
    subject = subject.json()
    api.login("subject", subject["work_email"], "AuditSubject@123")

    contract = api.post(
        "/contracts",
        "payroll_manager",
        json={
            "employee_id": subject["id"],
            "start_date": "2026-01-01",
            "wage_monthly": "60000.00",
            "status": "RUNNING",
        },
    )
    check("fixture contract created RUNNING", contract.status_code == 201,
          contract.status_code)
    contract = contract.json()

    # =====================================================================
    section("5. Salary update: correction vs revision")
    # =====================================================================
    corrected = api.patch(
        f"/contracts/{contract['id']}",
        "payroll_manager",
        json={"wage_monthly": "65000.00", "notes": "Typo in the offer letter."},
    )
    check("wage correction allowed before payroll", corrected.status_code == 200,
          corrected.status_code)
    check(
        "corrected wage is persisted",
        Decimal(corrected.json()["contract"]["wage_monthly"]) == Decimal("65000.00"),
        corrected.json()["contract"]["wage_monthly"],
    )

    check(
        "negative wage rejected on update",
        api.patch(
            f"/contracts/{contract['id']}", "payroll_manager",
            json={"wage_monthly": "-500.00"},
        ).status_code
        == 422,
    )
    check(
        "end date before start date rejected on update",
        api.patch(
            f"/contracts/{contract['id']}", "payroll_manager",
            json={"end_date": "2025-06-01"},
        ).status_code
        == 422,
    )
    check(
        "an employee cannot edit their own contract",
        api.patch(
            f"/contracts/{contract['id']}", "subject",
            json={"wage_monthly": "999999.00"},
        ).status_code
        == 403,
    )

    # A raise effective mid-year must supersede, not overwrite.
    revision = api.post(
        f"/contracts/{contract['id']}/revise-wage",
        "payroll_manager",
        json={
            "new_wage": "80000.00",
            "effective_from": "2026-04-01",
            "reason": "Annual review increase.",
        },
    )
    check("wage revision accepted", revision.status_code == 200, revision.status_code)
    revision = revision.json()
    check(
        "previous contract is closed the day before the effective date",
        revision["previous_contract"]["end_date"] == "2026-03-31",
        revision["previous_contract"]["end_date"],
    )
    check(
        "previous contract is EXPIRED",
        revision["previous_contract"]["status"] == "EXPIRED",
        revision["previous_contract"]["status"],
    )
    check(
        "previous contract keeps the OLD wage on record",
        Decimal(revision["previous_contract"]["wage_monthly"]) == Decimal("65000.00"),
        revision["previous_contract"]["wage_monthly"],
    )
    check(
        "new contract is RUNNING at the new wage from the effective date",
        revision["new_contract"]["status"] == "RUNNING"
        and revision["new_contract"]["start_date"] == "2026-04-01"
        and Decimal(revision["new_contract"]["wage_monthly"]) == Decimal("80000.00"),
        f"{revision['new_contract']['start_date']} @ "
        f"{revision['new_contract']['wage_monthly']}",
    )
    new_contract_id = revision["new_contract"]["id"]

    check(
        "cannot revise a contract that is no longer RUNNING",
        api.post(
            f"/contracts/{contract['id']}/revise-wage", "payroll_manager",
            json={"new_wage": "90000.00", "effective_from": "2026-05-01"},
        ).status_code
        == 409,
    )
    check(
        "revision effective before the contract start is rejected",
        api.post(
            f"/contracts/{new_contract_id}/revise-wage", "payroll_manager",
            json={"new_wage": "90000.00", "effective_from": "2026-01-01"},
        ).status_code
        == 422,
    )
    check(
        "an HR manager cannot revise wages (payroll manager only)",
        api.post(
            f"/contracts/{new_contract_id}/revise-wage", "hr_manager",
            json={"new_wage": "90000.00", "effective_from": "2026-06-01"},
        ).status_code
        == 403,
    )

    # The overlap guard must still hold after a revision.
    check(
        "a second RUNNING contract overlapping the new one is refused",
        api.post(
            "/contracts",
            "payroll_manager",
            json={
                "employee_id": subject["id"],
                "start_date": "2026-05-01",
                "wage_monthly": "70000.00",
                "status": "RUNNING",
            },
        ).status_code
        == 409,
    )

    # =====================================================================
    section("6. Payroll picks the contract valid for the period")
    # =====================================================================
    structures = api.get("/salary-structures", "payroll_user").json()
    regular = next(s for s in structures if s["code"] == "REG_SALARY")
    check(
        "Regular Salary carries the mockup's 12 rules",
        regular["rule_count"] == 12,
        regular["rule_count"],
    )

    march = api.post(
        "/payruns/step1-validate",
        "payroll_user",
        json={
            "salary_structure_id": regular["id"],
            "date_start": "2026-03-01",
            "date_end": "2026-03-31",
            "employee_ids": [subject["id"]],
        },
    ).json()
    march_candidate = march["candidates"][0]
    check(
        "March resolves the OLD contract at 65000",
        Decimal(march_candidate["wage_monthly"]) == Decimal("65000.00"),
        march_candidate["wage_monthly"],
    )

    may = api.post(
        "/payruns/step1-validate",
        "payroll_user",
        json={
            "salary_structure_id": regular["id"],
            "date_start": "2026-05-01",
            "date_end": "2026-05-31",
            "employee_ids": [subject["id"]],
        },
    ).json()
    check(
        "May resolves the NEW contract at 80000",
        Decimal(may["candidates"][0]["wage_monthly"]) == Decimal("80000.00"),
        may["candidates"][0]["wage_monthly"],
    )

    # A period straddling the revision must BLOCK, not be silently overpaid at
    # either rate. One payslip cannot represent two wages.
    straddle = api.post(
        "/payruns/step1-validate",
        "payroll_user",
        json={
            "salary_structure_id": regular["id"],
            "date_start": "2026-03-15",
            "date_end": "2026-04-15",
            "employee_ids": [subject["id"]],
        },
    ).json()
    straddle_candidate = straddle["candidates"][0]
    check(
        "a period straddling the revision is BLOCKED, not silently overpaid",
        straddle_candidate["eligible"] is False,
        straddle_candidate["eligible"],
    )
    check(
        "the block explains that the wage changed and names both contracts",
        any(
            "wage changed inside this period" in issue
            for issue in straddle_candidate["blocking_issues"]
        ),
        [i[:90] for i in straddle_candidate["blocking_issues"]],
    )
    check(
        "creating that batch is refused outright",
        api.post(
            "/payruns",
            "payroll_user",
            json={
                "name": f"Audit straddle {stamp}",
                "salary_structure_id": regular["id"],
                "date_start": "2026-03-15",
                "date_end": "2026-04-15",
                "employee_ids": [subject["id"]],
            },
        ).status_code
        == 409,
    )

    # And a leaver's final payslip must still be computable after their contract
    # ends, which is the case the RUNNING-only filter used to make impossible.
    leaver_period = api.post(
        "/payruns/step1-validate",
        "payroll_user",
        json={
            "salary_structure_id": regular["id"],
            "date_start": "2026-02-01",
            "date_end": "2026-02-28",
            "employee_ids": [subject["id"]],
        },
    ).json()
    check(
        "an EXPIRED contract still pays the period it covered",
        leaver_period["candidates"][0]["eligible"] is True
        and Decimal(leaver_period["candidates"][0]["wage_monthly"])
        == Decimal("65000.00"),
        f"eligible={leaver_period['candidates'][0]['eligible']} "
        f"wage={leaver_period['candidates'][0]['wage_monthly']}",
    )

    # =====================================================================
    section("7. Paid payroll is immutable")
    # =====================================================================
    run = api.post(
        "/payruns",
        "payroll_user",
        json={
            "name": f"Audit May 2026 {stamp}",
            "salary_structure_id": regular["id"],
            "date_start": "2026-05-01",
            "date_end": "2026-05-31",
            "employee_ids": [subject["id"]],
        },
    )
    check("audit payrun created", run.status_code == 201, run.status_code)
    run = run.json()
    run_id = run["payrun"]["id"]
    slip = run["payslips"][0]
    check(
        "payslip basic is 50% of the new wage",
        Decimal(slip["basic_amount"]) == Decimal("40000.00"),
        slip["basic_amount"],
    )

    detail = api.get(f"/payslips/{slip['id']}", "payroll_user").json()
    check(
        "zero-value rules produce no payslip line (7 of 12)",
        len(detail["lines"]) == 7,
        f"{len(detail['lines'])} lines from {regular['rule_count']} rules",
    )
    line_codes = [l["rule_code"] for l in detail["lines"]]
    check(
        "suppressed rules are exactly the zero-valued ones",
        set(line_codes) == {"BASIC", "HRA", "STD", "GROSS", "PF", "PT", "NET"},
        line_codes,
    )
    check(
        "ESIC is correctly zero above the statutory ceiling",
        "ESIC" not in line_codes,
    )

    api.post(f"/payruns/{run_id}/compute", "payroll_user")
    api.post(f"/payruns/{run_id}/validate", "payroll_user")
    paid = api.post(f"/payruns/{run_id}/mark-paid", "payroll_user")
    check("audit payrun marked PAID", paid.status_code == 200, paid.status_code)

    frozen = api.patch(
        f"/contracts/{new_contract_id}",
        "payroll_manager",
        json={"wage_monthly": "120000.00"},
    )
    check(
        "wage cannot be edited once a PAID payslip exists",
        frozen.status_code == 409,
        frozen.status_code,
    )
    check(
        "the refusal names the blocking payslip",
        "blocking_payslips" in frozen.json().get("details", {}),
        list(frozen.json().get("details", {}).keys()),
    )
    check(
        "non-financial fields are still editable on a paid contract",
        api.patch(
            f"/contracts/{new_contract_id}", "payroll_manager",
            json={"notes": "Audited."},
        ).status_code
        == 200,
    )
    check(
        "cannot split a contract at a date already paid",
        api.post(
            f"/contracts/{new_contract_id}/revise-wage", "payroll_manager",
            json={"new_wage": "95000.00", "effective_from": "2026-05-15"},
        ).status_code
        == 409,
    )
    check(
        "a PAID payrun cannot be deleted",
        api.delete(f"/payruns/{run_id}", "payroll_user").status_code == 409,
    )
    check(
        "a PAID payrun cannot be recomputed",
        api.post(f"/payruns/{run_id}/compute", "payroll_user").status_code == 409,
    )

    # =====================================================================
    section("8. Payrun state machine cannot be skipped")
    # =====================================================================
    fresh = api.post(
        "/payruns",
        "payroll_user",
        json={
            "name": f"Audit Jun 2026 {stamp}",
            "salary_structure_id": regular["id"],
            "date_start": "2026-06-01",
            "date_end": "2026-06-30",
            "employee_ids": [subject["id"]],
        },
    ).json()
    fresh_id = fresh["payrun"]["id"]
    check(
        "DRAFT cannot jump straight to VALIDATED",
        api.post(f"/payruns/{fresh_id}/validate", "payroll_user").status_code == 409,
    )
    check(
        "DRAFT cannot jump straight to PAID",
        api.post(f"/payruns/{fresh_id}/mark-paid", "payroll_user").status_code == 409,
    )
    check(
        "payslips cannot be emailed from a DRAFT batch",
        api.post(f"/payruns/{fresh_id}/send-payslips", "payroll_user").status_code
        == 409,
    )
    api.post(f"/payruns/{fresh_id}/compute", "payroll_user")
    check(
        "COMPUTED cannot jump straight to PAID",
        api.post(f"/payruns/{fresh_id}/mark-paid", "payroll_user").status_code == 409,
    )
    check(
        "a DRAFT/COMPUTED batch can be deleted",
        api.delete(f"/payruns/{fresh_id}", "payroll_user").status_code == 200,
    )

    # Bank details are required before money moves.
    no_bank = api.post(
        "/employees",
        "admin",
        json={
            "name": f"No Bank {stamp}",
            "work_email": f"nobank.{stamp}@oxp.com",
            "working_schedule_id": schedule_40h["id"],
            "date_of_joining": "2026-01-01",
        },
    ).json()
    api.post(
        "/contracts",
        "payroll_manager",
        json={
            "employee_id": no_bank["id"],
            "start_date": "2026-01-01",
            "wage_monthly": "50000.00",
            "status": "RUNNING",
        },
    )
    nb_run = api.post(
        "/payruns",
        "payroll_user",
        json={
            "name": f"Audit NoBank {stamp}",
            "salary_structure_id": regular["id"],
            "date_start": "2026-07-01",
            "date_end": "2026-07-31",
            "employee_ids": [no_bank["id"]],
        },
    ).json()
    nb_id = nb_run["payrun"]["id"]
    check(
        "missing bank details surface as a payslip warning",
        nb_run["payslips"][0]["warning_notes"]
        and "Bank" in nb_run["payslips"][0]["warning_notes"],
        nb_run["payslips"][0]["warning_notes"],
    )
    api.post(f"/payruns/{nb_id}/compute", "payroll_user")
    api.post(f"/payruns/{nb_id}/validate", "payroll_user")
    check(
        "mark-paid is refused while bank details are missing",
        api.post(f"/payruns/{nb_id}/mark-paid", "payroll_user").status_code == 409,
    )

    # =====================================================================
    section("9. Payroll configuration changes flow through recompute")
    # =====================================================================
    cfg_run = api.post(
        "/payruns",
        "payroll_user",
        json={
            "name": f"Audit Aug 2026 {stamp}",
            "salary_structure_id": regular["id"],
            "date_start": "2026-08-01",
            "date_end": "2026-08-31",
            "employee_ids": [subject["id"]],
        },
    ).json()
    cfg_id = cfg_run["payrun"]["id"]
    before_net = Decimal(cfg_run["payslips"][0]["net_amount"])

    bonus_rule = next(r for r in regular["rules"] if r["code"] == "BONUS")
    api.patch(
        f"/salary-structures/rules/{bonus_rule['id']}",
        "payroll_manager",
        json={"fixed_amount": "5000.00"},
    )
    recomputed = api.post(f"/payruns/{cfg_id}/compute", "payroll_user").json()
    after_net = Decimal(recomputed["payslips"][0]["net_amount"])
    check(
        "awarding a bonus raises net pay on recompute",
        after_net == before_net + Decimal("5000.00"),
        f"{before_net} -> {after_net}",
    )
    after_detail = api.get(
        f"/payslips/{recomputed['payslips'][0]['id']}", "payroll_user"
    ).json()
    check(
        "the previously suppressed BONUS line now appears",
        "BONUS" in [l["rule_code"] for l in after_detail["lines"]],
        [l["rule_code"] for l in after_detail["lines"]],
    )

    api.patch(
        f"/salary-structures/rules/{bonus_rule['id']}",
        "payroll_manager",
        json={"fixed_amount": "0.00"},
    )
    reverted = api.post(f"/payruns/{cfg_id}/compute", "payroll_user").json()
    check(
        "reverting the rule restores the original net",
        Decimal(reverted["payslips"][0]["net_amount"]) == before_net,
        reverted["payslips"][0]["net_amount"],
    )

    check(
        "a rule with a broken formula is rejected on save",
        api.patch(
            f"/salary-structures/rules/{bonus_rule['id']}",
            "payroll_manager",
            json={"computation_type": "PYTHON_CODE", "python_code": "import os"},
        ).status_code
        == 422,
    )
    check(
        "a structure in use by an open payrun cannot be deactivated",
        api.patch(
            f"/salary-structures/{regular['id']}", "payroll_manager",
            json={"is_active": False},
        ).status_code
        == 409,
    )
    check(
        "a structure with payroll history is deactivated, not deleted",
        api.delete(f"/salary-structures/{regular['id']}", "payroll_manager").status_code
        == 200,
    )
    api.patch(
        f"/salary-structures/{regular['id']}", "payroll_manager", json={"is_active": True}
    )
    api.delete(f"/payruns/{cfg_id}", "payroll_user")

    # =====================================================================
    section("10. Leave ledger: modification and integrity")
    # =====================================================================
    types = api.get("/timeoff/types", "admin").json()
    pto = next(t for t in types if t["name"] == "Paid Time Off")

    allocation = api.post(
        "/timeoff/allocations",
        "hr_manager",
        json={
            "employee_id": subject["id"],
            "timeoff_type_id": pto["id"],
            "allocated_days": "10.00",
            "validity_year": 2026,
            "status": "APPROVED",
        },
    )
    check("allocation granted", allocation.status_code == 201, allocation.status_code)
    allocation = allocation.json()
    check(
        "validity label is auto-populated",
        allocation["validity_label"] == "2026 Annual Balance",
        allocation["validity_label"],
    )

    bumped = api.patch(
        f"/timeoff/allocations/{allocation['id']}",
        "hr_manager",
        json={"allocated_days": "12.00"},
    ).json()
    check(
        "allocation can be increased",
        Decimal(bumped["remaining_days"]) == Decimal("12.00"),
        bumped["remaining_days"],
    )

    leave = api.post(
        "/timeoff/requests",
        "subject",
        json={
            "timeoff_type_id": pto["id"],
            "start_date": "2026-09-07",
            "end_date": "2026-09-11",
            "reason": "Audit leave",
        },
    ).json()
    check(
        "5 working days derived from the schedule",
        Decimal(leave["duration_days"]) == Decimal("5.00"),
        leave["duration_days"],
    )

    amended = api.patch(
        f"/timeoff/requests/{leave['id']}",
        "subject",
        json={"start_date": "2026-09-07", "end_date": "2026-09-09"},
    ).json()
    check(
        "a pending request can be shortened and the duration recomputed",
        Decimal(amended["duration_days"]) == Decimal("3.00"),
        amended["duration_days"],
    )
    check(
        "an employee cannot amend someone else's request",
        api.patch(
            f"/timeoff/requests/{leave['id']}", "employee",
            json={"reason": "hijacked"},
        ).status_code
        == 403,
    )

    api.post(f"/timeoff/requests/{leave['id']}/approve", "hr_manager")
    after_approval = api.get(
        "/timeoff/allocations", "hr_manager",
        params={"employee_id": subject["id"]},
    ).json()
    alloc_row = next(a for a in after_approval if a["id"] == allocation["id"])
    check(
        "approval debits exactly the request duration",
        Decimal(alloc_row["taken_days"]) == Decimal("3.00"),
        alloc_row["taken_days"],
    )

    check(
        "an approved request can no longer be amended",
        api.patch(
            f"/timeoff/requests/{leave['id']}", "hr_manager",
            json={"end_date": "2026-09-18"},
        ).status_code
        == 409,
    )
    shrink = api.patch(
        f"/timeoff/allocations/{allocation['id']}",
        "hr_manager",
        json={"allocated_days": "2.00"},
    )
    check(
        "an allocation cannot be cut below days already taken",
        shrink.status_code == 409,
        shrink.status_code,
    )
    check(
        "the refusal names the floor",
        "3" in shrink.json()["detail"],
        shrink.json()["detail"][:80],
    )
    check(
        "an allocation with consumed days cannot be deleted",
        api.delete(
            f"/timeoff/allocations/{allocation['id']}", "hr_manager"
        ).status_code
        == 409,
    )

    cancelled = api.post(
        f"/timeoff/requests/{leave['id']}/cancel", "subject"
    ).json()
    check("employee can cancel their approved leave", cancelled["status"] == "REFUSED",
          cancelled["status"])
    restored = api.get(
        "/timeoff/allocations", "hr_manager", params={"employee_id": subject["id"]}
    ).json()
    alloc_row = next(a for a in restored if a["id"] == allocation["id"])
    check(
        "cancelling credits the days back to the ledger",
        Decimal(alloc_row["taken_days"]) == Decimal("0.00"),
        alloc_row["taken_days"],
    )

    over = api.post(
        "/timeoff/requests",
        "subject",
        json={
            "timeoff_type_id": pto["id"],
            "start_date": "2026-10-01",
            "end_date": "2026-12-31",
        },
    )
    check(
        "a request larger than the balance is refused",
        over.status_code in (409, 422),
        over.status_code,
    )
    weekend = api.post(
        "/timeoff/requests",
        "subject",
        json={
            "timeoff_type_id": pto["id"],
            "start_date": "2026-09-05",
            "end_date": "2026-09-06",
        },
    )
    check(
        "a weekend-only request is refused (zero working days)",
        weekend.status_code == 422,
        weekend.status_code,
    )
    check(
        "a self-approval attempt by the requester is refused",
        api.post(
            f"/timeoff/requests/{leave['id']}/approve", "subject"
        ).status_code
        == 403,
    )

    # =====================================================================
    section("11. Concurrency: two approvals racing one balance")
    # =====================================================================
    race_alloc = api.post(
        "/timeoff/allocations",
        "hr_manager",
        json={
            "employee_id": subject["id"],
            "timeoff_type_id": pto["id"],
            "allocated_days": "3.00",
            "validity_year": 2027,
            "status": "APPROVED",
        },
    ).json()
    # Two separate 3-day requests; the balance funds exactly one.
    req_a = api.post(
        "/timeoff/requests",
        "subject",
        json={
            "timeoff_type_id": pto["id"],
            "start_date": "2027-03-01",
            "end_date": "2027-03-03",
        },
    )
    req_b = api.post(
        "/timeoff/requests",
        "subject",
        json={
            "timeoff_type_id": pto["id"],
            "start_date": "2027-04-05",
            "end_date": "2027-04-07",
        },
    )
    if req_a.status_code == 201 and req_b.status_code == 201:
        ids = [req_a.json()["id"], req_b.json()["id"]]

        def approve(request_id: str) -> int:
            client = httpx.Client(timeout=60.0)
            try:
                return client.post(
                    f"{api.api}/timeoff/requests/{request_id}/approve",
                    headers=api.headers("hr_manager"),
                ).status_code
            finally:
                client.close()

        with concurrent.futures.ThreadPoolExecutor(max_workers=2) as pool:
            results = list(pool.map(approve, ids))

        successes = sum(1 for r in results if r == 200)
        check(
            "exactly one of two simultaneous approvals succeeds",
            successes == 1,
            f"statuses={results}",
        )
        final = api.get(
            "/timeoff/allocations", "hr_manager", params={"employee_id": subject["id"]}
        ).json()
        race_row = next(a for a in final if a["id"] == race_alloc["id"])
        check(
            "the ledger never goes negative under the race",
            Decimal(race_row["taken_days"]) <= Decimal(race_row["allocated_days"]),
            f"taken={race_row['taken_days']} of {race_row['allocated_days']}",
        )
    else:
        check(
            "concurrency fixture created",
            False,
            f"{req_a.status_code}/{req_b.status_code}",
        )

    # =====================================================================
    section("12. Master data: in-use guards")
    # =====================================================================
    check(
        "a department with employees is deactivated, not deleted",
        api.delete(f"/departments/{dept['id']}", "admin").status_code == 200,
    )
    dept_after = next(
        d for d in api.get("/departments", "admin").json() if d["id"] == dept["id"]
    )
    check("and it is now inactive", dept_after["is_active"] is False)
    api.patch(f"/departments/{dept['id']}", "admin", json={"is_active": True})

    check(
        "a job position held by an employee cannot be deleted",
        api.delete(f"/job-positions/{position['id']}", "admin").status_code == 409,
    )
    check(
        "a schedule assigned to employees is deactivated, not deleted",
        api.delete(f"/schedules/{schedule_40h['id']}", "admin").status_code == 200,
    )
    api.patch(f"/schedules/{schedule_40h['id']}", "admin", json={"is_active": True})

    check(
        "a time off type with history is deactivated, not deleted",
        api.delete(f"/timeoff/types/{pto['id']}", "admin").status_code == 200,
    )
    api.patch(f"/timeoff/types/{pto['id']}", "admin", json={"is_active": True})

    empty_dept = api.post(
        "/departments", "admin", json={"name": f"Empty Dept {stamp}"}
    ).json()
    check(
        "an unused department is genuinely deleted",
        api.delete(f"/departments/{empty_dept['id']}", "admin").status_code == 200,
    )
    check(
        "and it is gone from the list",
        all(
            d["id"] != empty_dept["id"]
            for d in api.get("/departments", "admin").json()
        ),
    )

    # Replacing a weekly pattern must change the derived expectations.
    new_sched = api.post(
        "/schedules",
        "admin",
        json={
            "name": f"Audit 4-day {stamp}",
            "days_per_week": 4,
            "hours_per_week": "32.00",
            "lines": [
                {
                    "day_of_week": d,
                    "start_time": "09:00:00",
                    "end_time": "18:00:00",
                    "break_hours": "1.00",
                }
                for d in range(4)
            ],
        },
    ).json()
    check(
        "schedule day lines compute work_hours in the database",
        all(Decimal(l["work_hours"]) == Decimal("8.00") for l in new_sched["lines"]),
        [l["work_hours"] for l in new_sched["lines"]],
    )
    replaced = api.patch(
        f"/schedules/{new_sched['id']}",
        "admin",
        json={
            "lines": [
                {
                    "day_of_week": 0,
                    "start_time": "10:00:00",
                    "end_time": "16:00:00",
                    "break_hours": "0.50",
                }
            ]
        },
    ).json()
    check(
        "supplying lines replaces the whole pattern",
        len(replaced["lines"]) == 1
        and Decimal(replaced["lines"][0]["work_hours"]) == Decimal("5.50"),
        f"{len(replaced['lines'])} line(s), "
        f"{replaced['lines'][0]['work_hours']}h",
    )

    # =====================================================================
    section("13. Attendance integrity")
    # =====================================================================
    api.post("/attendance/punch", "subject", json={})
    open_status = api.get("/attendance/status", "subject").json()
    check("subject is checked in", open_status["checked_in"] is True)
    second = api.post("/attendance/punch", "subject", json={})
    check(
        "a second punch checks out rather than opening a duplicate",
        second.json()["action"] == "CHECK_OUT",
        second.json()["action"],
    )
    after = api.get("/attendance/status", "subject").json()
    check("subject is checked out again", after["checked_in"] is False)

    check(
        "a manual record with check-out before check-in is refused",
        api.post(
            "/attendance/manual",
            "hr_manager",
            json={
                "employee_id": subject["id"],
                "check_in": "2026-02-10T18:00:00Z",
                "check_out": "2026-02-10T09:00:00Z",
            },
        ).status_code
        == 422,
    )
    manual = api.post(
        "/attendance/manual",
        "hr_manager",
        json={
            "employee_id": subject["id"],
            "check_in": "2026-02-11T09:00:00Z",
            "check_out": "2026-02-11T18:30:00Z",
            "audit_notes": "Reader outage.",
        },
    ).json()
    check("HR correction is stamped as a manual edit", manual["is_manual_edit"] is True)
    check(
        "worked hours are recomputed on a manual edit",
        Decimal(manual["worked_hours"]) == Decimal("9.50"),
        manual["worked_hours"],
    )
    check(
        "overtime is derived against the schedule",
        Decimal(manual["overtime_hours"]) == Decimal("1.50"),
        manual["overtime_hours"],
    )
    check(
        "an employee cannot create manual attendance records",
        api.post(
            "/attendance/manual",
            "subject",
            json={
                "employee_id": subject["id"],
                "check_in": "2026-02-12T09:00:00Z",
                "check_out": "2026-02-12T23:00:00Z",
            },
        ).status_code
        == 403,
    )

    # A terminated employee must not be able to record attendance.
    api.delete(f"/employees/{no_bank['id']}", "admin")
    terminated = api.get(f"/employees/{no_bank['id']}", "admin").json()
    check(
        "archiving an employee sets TERMINATED",
        terminated["status"] == "TERMINATED",
        terminated["status"],
    )
    check(
        "a terminated employee cannot be punched in",
        api.post(
            "/attendance/punch", "hr_manager", json={"employee_id": no_bank["id"]}
        ).status_code
        == 409,
    )

    # =====================================================================
    section("14. Dashboard filters actually filter")
    # =====================================================================
    options = api.get("/dashboard/filters", "payroll_user").json()
    check(
        "filter options expose departments, types, companies and periods",
        options["departments"]
        and options["employee_types"]
        and options["companies"]
        and options["periods"],
        f"{len(options['departments'])} depts, "
        f"{len(options['employee_types'])} types, "
        f"{len(options['periods'])} periods",
    )
    check(
        "employee types include the seeded mix",
        {"PERMANENT", "PROBATION"} <= set(options["employee_types"]),
        options["employee_types"],
    )

    february = next(p for p in options["periods"] if p["name"] == "February 2026")
    unfiltered = api.get(
        "/dashboard/metrics", "payroll_user",
        params={"payrun_id": february["payrun_id"]},
    ).json()
    check(
        "the February batch reports 42 payslips",
        unfiltered["kpi"]["payslips_generated"] == 42,
        unfiltered["kpi"]["payslips_generated"],
    )

    eng = next(d for d in options["departments"] if d["name"] == "Engineering")
    dept_filtered = api.get(
        "/dashboard/metrics",
        "payroll_user",
        params={"payrun_id": february["payrun_id"], "department_id": eng["id"]},
    ).json()
    check(
        "a department filter reduces the payslip count",
        0 < dept_filtered["kpi"]["payslips_generated"]
        < unfiltered["kpi"]["payslips_generated"],
        f"{dept_filtered['kpi']['payslips_generated']} of "
        f"{unfiltered['kpi']['payslips_generated']}",
    )
    check(
        "a department filter leaves exactly one department in the cost split",
        len(dept_filtered["department_costs"]) == 1
        and dept_filtered["department_costs"][0]["department"] == "Engineering",
        [d["department"] for d in dept_filtered["department_costs"]],
    )
    type_filtered = api.get(
        "/dashboard/metrics",
        "payroll_user",
        params={"payrun_id": february["payrun_id"], "employee_type": "PROBATION"},
    ).json()
    check(
        "an employee-type filter narrows the cohort",
        type_filtered["kpi"]["payslips_generated"]
        < unfiltered["kpi"]["payslips_generated"],
        type_filtered["kpi"]["payslips_generated"],
    )

    kpi = unfiltered["kpi"]
    dept_net = sum(Decimal(str(d["total_net"])) for d in unfiltered["department_costs"])
    check(
        "department net totals reconcile with the KPI total",
        dept_net == Decimal(str(kpi["total_net_salary_paid"])),
        f"{dept_net} vs {kpi['total_net_salary_paid']}",
    )
    check(
        "avg salary per employee equals net divided by employees paid",
        abs(
            Decimal(str(kpi["avg_salary_per_employee"]))
            - Decimal(str(kpi["total_net_salary_paid"])) / kpi["employees_paid"]
        )
        < Decimal("0.01"),
        kpi["avg_salary_per_employee"],
    )
    check(
        "paid + pending equals payslips generated",
        kpi["payslips_paid"] + kpi["payslips_pending"] == kpi["payslips_generated"],
        f"{kpi['payslips_paid']}+{kpi['payslips_pending']}",
    )
    status_split = unfiltered["payslip_status"]
    check(
        "the status split sums to the total",
        status_split["paid"] + status_split["done"] + status_split["draft"]
        == status_split["total"],
        status_split,
    )
    ao = unfiltered["attendance_overview"]
    check(
        "attendance overview surfaces late arrivals",
        ao["late"] > 0,
        ao["late"],
    )
    check(
        "attendance overview surfaces missing check-outs",
        ao["missing_check_outs"] == 5,
        ao["missing_check_outs"],
    )
    check(
        "attendance overview surfaces manual edits",
        ao["manual_attendance_edits"] >= 7,
        ao["manual_attendance_edits"],
    )
    check(
        "attendance health is a sane percentage",
        0 < ao["coverage_pct"] <= 100,
        f"{ao['coverage_pct']}%",
    )
    check(
        "approved time off days are non-zero for the period",
        Decimal(str(kpi["approved_timeoff_days"])) > 0,
        kpi["approved_timeoff_days"],
    )
    unpaid_row = next(
        t for t in unfiltered["timeoff_overview"] if t["timeoff_type"] == "Unpaid Leave"
    )
    check(
        "a type needing no allocation reports no balance (N/A, not zero)",
        unpaid_row["remaining_balance"] is None
        and unpaid_row["tracks_balance"] is False,
        unpaid_row["remaining_balance"],
    )
    check(
        "payroll alerts are produced from live data",
        len(unfiltered["alerts"]) > 0,
        [a["kind"] for a in unfiltered["alerts"]],
    )
    check(
        "employees cannot read the company dashboard",
        api.get("/dashboard/metrics", "employee").status_code == 403,
    )

    # =====================================================================
    section("15. Input validation and boundaries")
    # =====================================================================
    boundaries = [
        ("payrun end before start", "POST", "/payruns/step1-validate", "payroll_user",
         {"salary_structure_id": regular["id"], "date_start": "2026-05-31",
          "date_end": "2026-05-01"}, 422),
        ("payrun with an empty employee list", "POST", "/payruns", "payroll_user",
         {"name": "x", "salary_structure_id": regular["id"],
          "date_start": "2026-05-01", "date_end": "2026-05-31", "employee_ids": []},
         422),
        ("payrun for an unknown employee", "POST", "/payruns", "payroll_user",
         {"name": "x", "salary_structure_id": regular["id"],
          "date_start": "2026-11-01", "date_end": "2026-11-30",
          "employee_ids": [str(uuid.uuid4())]}, 404),
        ("payrun with an unknown structure", "POST", "/payruns/step1-validate",
         "payroll_user",
         {"salary_structure_id": str(uuid.uuid4()), "date_start": "2026-05-01",
          "date_end": "2026-05-31"}, 404),
        ("allocation with negative days", "POST", "/timeoff/allocations", "hr_manager",
         {"employee_id": subject["id"], "timeoff_type_id": pto["id"],
          "allocated_days": "-5.00"}, 422),
        ("employee with a malformed email", "POST", "/employees", "admin",
         {"name": "Bad Email", "work_email": "not-an-email"}, 422),
        ("rule with an out-of-range percentage", "POST",
         f"/salary-structures/{regular['id']}/rules", "payroll_manager",
         {"name": "Bad", "code": "BADPCT", "category": "ALLOWANCE",
          "computation_type": "PERCENTAGE", "percentage_base": "WAGE",
          "percentage_rate": "150000.00"}, 422),
        ("rule with a lowercase code", "POST",
         f"/salary-structures/{regular['id']}/rules", "payroll_manager",
         {"name": "Bad", "code": "lower", "category": "ALLOWANCE",
          "computation_type": "FIXED", "fixed_amount": "1.00"}, 422),
        ("percentage rule missing its base", "POST",
         f"/salary-structures/{regular['id']}/rules", "payroll_manager",
         {"name": "Bad", "code": "NOBASE", "category": "ALLOWANCE",
          "computation_type": "PERCENTAGE"}, 422),
        ("unknown employee id in a path", "GET",
         f"/employees/{uuid.uuid4()}", "admin", None, 404),
        ("non-uuid in a uuid path", "GET", "/employees/not-a-uuid", "admin", None, 422),
    ]
    for label, method, path, alias, body, expected in boundaries:
        response = api.req(method, path, alias, **({"json": body} if body else {}))
        check(
            f"rejected: {label}",
            response.status_code == expected,
            f"got {response.status_code}, expected {expected}",
        )

    duplicate_code = api.post(
        f"/salary-structures/{regular['id']}/rules",
        "payroll_manager",
        json={
            "name": "Duplicate Basic",
            "code": "BASIC",
            "category": "ALLOWANCE",
            "computation_type": "FIXED",
            "fixed_amount": "1.00",
        },
    )
    check(
        "a duplicate rule code in one structure is refused",
        duplicate_code.status_code == 409,
        duplicate_code.status_code,
    )

    dup_badge = api.post(
        "/employees",
        "admin",
        json={
            "name": "Clone",
            "work_email": f"clone.{stamp}@oxp.com",
            "badge_id": subject["badge_id"],
        },
    )
    check(
        "a duplicate badge ID is refused",
        dup_badge.status_code == 409,
        dup_badge.status_code,
    )
    dup_email = api.post(
        "/employees",
        "admin",
        json={"name": "Clone2", "work_email": subject["work_email"]},
    )
    check(
        "a duplicate work email is refused",
        dup_email.status_code == 409,
        dup_email.status_code,
    )
    self_manager = api.patch(
        f"/employees/{subject['id']}", "admin", json={"manager_id": subject["id"]}
    )
    check(
        "an employee cannot be their own manager",
        self_manager.status_code == 422,
        self_manager.status_code,
    )

    # =====================================================================
    section("16. Admin safety rails")
    # =====================================================================
    admins = [
        u for u in api.get("/users", "admin", params={"role": "ADMIN"}).json()
        if u["is_active"]
    ]
    if len(admins) == 1:
        check(
            "the only active admin cannot demote themselves",
            api.patch(
                f"/users/{admin_me['user_id']}", "admin", json={"role": "EMPLOYEE"}
            ).status_code
            == 409,
        )
        check(
            "the only active admin cannot deactivate themselves",
            api.patch(
                f"/users/{admin_me['user_id']}", "admin", json={"is_active": False}
            ).status_code
            == 409,
        )
    else:
        check("admin safety rail (skipped: more than one admin)", True, len(admins))

    check(
        "an employee with a running contract cannot be archived",
        api.delete(f"/employees/{subject['id']}", "admin").status_code == 409,
    )

    linked = api.post(
        f"/users/{victim['user_id']}/link-employee/{subject['id']}", "admin"
    )
    check(
        "a login already linked elsewhere cannot be relinked",
        linked.status_code == 409,
        linked.status_code,
    )

    # =====================================================================
    section("17. AI copilot boundaries")
    # =====================================================================
    check(
        "an employee cannot read the escalation queue stats",
        api.get("/ai/escalations/stats", "employee").status_code == 403,
    )
    check(
        "an employee cannot ingest knowledge base documents",
        api.post(
            "/ai/knowledge/documents",
            "employee",
            json={"collection": "hr_policies", "title": "Fake", "content": "Fake"},
        ).status_code
        == 403,
    )
    check(
        "an employee cannot read routing rules",
        api.get("/ai/escalations/routing-rules", "employee").status_code == 403,
    )
    check(
        "an employee cannot run the SLA sweep",
        api.post("/ai/escalations/sla-sweep", "employee").status_code == 403,
    )

    # Tier 0 must never leak another employee's figures.
    balance_answer = api.post(
        "/ai/assistant", "subject", json={"prompt": "what is my leave balance"}
    ).json()
    check(
        "Tier 0 answers from the caller's own ledger",
        balance_answer["mode"] == "TIER0_TEMPLATE",
        balance_answer["mode"],
    )
    check(
        "and it does not mention another employee",
        "Aarav" not in balance_answer["answer"]
        and "Priya" not in balance_answer["answer"],
    )

    spam_blocked = False
    for index in range(8):
        result = api.post(
            "/ai/escalations",
            "subject",
            json={"prompt": f"Audit spam probe number {index} about {uuid.uuid4()}"},
        )
        if result.status_code == 409:
            spam_blocked = True
            break
    check(
        "the open-ticket cap stops one employee flooding the queue",
        spam_blocked,
        "hit the cap" if spam_blocked else "never blocked",
    )

    # =====================================================================
    print("\n" + "=" * 74)
    total = passed + len(failed)
    print(f"RESULT: {passed}/{total} checks passed")
    if failed:
        print(f"\n{len(failed)} FAILURE(S):")
        for item in failed:
            print(f"  - {item}")
        return 1
    print("\nAll adversarial checks passed.")
    return 0


if __name__ == "__main__":
    sys.exit(main())
