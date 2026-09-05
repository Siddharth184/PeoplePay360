"""End-to-end acceptance test for Time Off -> Payroll integration.

Implements the section-12 acceptance scenario directly against the service layer
and a real PostgreSQL database (the ledger relies on a GENERATED column and
FOR UPDATE row locks, so SQLite cannot stand in):

    Employee starts with allocation Total=20, Used=5, Remaining=15.
    Employee requests 3 days           -> pending; allocation UNCHANGED (15).
    HR approves                        -> Used=8, Remaining=12, status APPROVED.
    Duplicate approve                  -> rejected (no double deduction).
    Payroll runs for the period        -> the approved leave is detected.
    Paid vs unpaid treatment           -> follows TimeOffType.is_paid + the LOP
                                          salary rule (unpaid deducts, paid does not).
    Refuse / cancel an approved request-> credits the balance back exactly once.

Prerequisites:
    docker compose up -d db
    python -m scripts.init_db
    python -m scripts.seed_db          (optional; this script self-provisions)

Usage:
    python -m scripts.verify_leave_payroll

Exits non-zero on the first failed assertion, so it is CI-usable.
"""

from __future__ import annotations

import sys
import uuid
from datetime import date, datetime, timedelta, timezone
from decimal import Decimal
from pathlib import Path

sys.path.insert(0, str(Path(__file__).resolve().parents[1]))

from sqlalchemy import select, text  # noqa: E402

from app.core.database import SessionLocal  # noqa: E402
from app.models.attendance import Attendance  # noqa: E402
from app.models.contract import HrContract  # noqa: E402
from app.models.employee import Employee  # noqa: E402
from app.models.master import WorkingSchedule, WorkingScheduleLine  # noqa: E402
from app.models.salary import SalaryRule, SalaryStructure  # noqa: E402
from app.models.timeoff import LeaveAllocation, LeaveRequest, TimeOffType  # noqa: E402
from app.services import attendance_service, payrun_service, timeoff_service  # noqa: E402
from app.services.salary_engine import execute_salary_computation, to_decimal  # noqa: E402

passed = 0
failed: list[str] = []


def check(label: str, condition: bool, detail: str = "") -> None:
    global passed
    if condition:
        passed += 1
        print(f"  PASS  {label}")
    else:
        failed.append(f"{label} {('-> ' + detail) if detail else ''}")
        print(f"  FAIL  {label} {('-> ' + detail) if detail else ''}")


def approx(a, b, tol=Decimal("0.01")) -> bool:
    return abs(to_decimal(a) - to_decimal(b)) <= tol


# ---------------------------------------------------------------------------
# Fixtures: self-provision an isolated employee, schedule, contract, structure,
# allocation. Everything is tagged with a unique suffix and torn down at the end.
# ---------------------------------------------------------------------------
def build_fixtures(db):
    tag = uuid.uuid4().hex[:8]
    print(f"Provisioning isolated fixtures (tag={tag}) ...")

    schedule = WorkingSchedule(
        name=f"ACCEPT {tag} Mon-Fri",
        company_name="OXP Pvt Ltd",
        days_per_week=5,
        hours_per_week=Decimal("40.00"),
        timezone="Asia/Kolkata",
    )
    db.add(schedule)
    db.flush()
    for dow in range(5):  # Monday..Friday
        db.add(
            WorkingScheduleLine(
                schedule_id=schedule.id,
                day_of_week=dow,
                day_name=["Monday", "Tuesday", "Wednesday", "Thursday", "Friday"][dow],
                start_time=datetime(2026, 1, 1, 9, 0).time(),
                end_time=datetime(2026, 1, 1, 18, 0).time(),
                break_hours=Decimal("1.00"),
            )
        )

    employee = Employee(
        badge_id=f"ACC-{tag[:6].upper()}",
        name=f"Acceptance Tester {tag}",
        work_email=f"accept.{tag}@oxp.example.com",
        working_schedule_id=schedule.id,
        status="ACTIVE",
        employee_type="PERMANENT",
        date_of_joining=date(2024, 1, 1),
    )
    db.add(employee)
    db.flush()

    # A self-contained structure: BASIC 100% of wage, GROSS, LOP (unpaid leave
    # loss of pay, configured rule), NET. Wage 60,000 to match the spec example.
    structure = SalaryStructure(
        name=f"ACCEPT {tag} Structure",
        code=f"ACC_{tag.upper()}",
        notes="Acceptance test structure.",
    )
    db.add(structure)
    db.flush()
    db.add_all(
        [
            SalaryRule(
                salary_structure_id=structure.id,
                name="Basic",
                code="BASIC",
                sequence=1,
                category="BASIC",
                computation_type="PERCENTAGE",
                percentage_base="WAGE",
                percentage_rate=Decimal("100.00"),
            ),
            SalaryRule(
                salary_structure_id=structure.id,
                name="Gross Salary",
                code="GROSS",
                sequence=60,
                category="GROSS",
                computation_type="PYTHON_CODE",
                python_code="result = categories['BASIC'] + categories['ALLOWANCE']",
            ),
            SalaryRule(
                salary_structure_id=structure.id,
                name="Loss of Pay (Unpaid Leave)",
                code="LOP",
                sequence=105,
                category="DEDUCTION",
                computation_type="PYTHON_CODE",
                python_code=(
                    "if unpaid_leave_days > 0 and expected_days > 0:\n"
                    "    daily_rate = categories['GROSS'] / expected_days\n"
                    "    result = round(daily_rate * unpaid_leave_days, 2)\n"
                    "else:\n"
                    "    result = 0"
                ),
            ),
            SalaryRule(
                salary_structure_id=structure.id,
                name="Net Salary",
                code="NET",
                sequence=110,
                category="NET",
                computation_type="PYTHON_CODE",
                python_code="result = categories['GROSS'] - categories['DEDUCTION']",
            ),
        ]
    )

    contract = HrContract(
        reference_code=f"CON/ACC/{tag.upper()}",
        employee_id=employee.id,
        working_schedule_id=schedule.id,
        salary_structure_id=structure.id,
        start_date=date(2024, 1, 1),
        wage_monthly=Decimal("60000.00"),
        status="RUNNING",
    )
    db.add(contract)

    paid_type = TimeOffType(
        name=f"ACCEPT {tag} Paid Leave",
        unit="DAYS",
        requires_allocation=True,
        approval_level="MANAGER",
        is_paid=True,
    )
    unpaid_type = TimeOffType(
        name=f"ACCEPT {tag} Unpaid Leave",
        unit="DAYS",
        requires_allocation=True,
        approval_level="MANAGER",
        is_paid=False,
    )
    db.add_all([paid_type, unpaid_type])
    db.flush()

    # Allocation: Total=20, Used=5 -> Remaining=15 (the spec starting point).
    allocation = LeaveAllocation(
        employee_id=employee.id,
        timeoff_type_id=paid_type.id,
        allocated_days=Decimal("20.00"),
        taken_days=Decimal("5.00"),
        validity_year=2026,
        status="APPROVED",
    )
    unpaid_allocation = LeaveAllocation(
        employee_id=employee.id,
        timeoff_type_id=unpaid_type.id,
        allocated_days=Decimal("20.00"),
        taken_days=Decimal("0.00"),
        validity_year=2026,
        status="APPROVED",
    )
    db.add_all([allocation, unpaid_allocation])
    db.flush()
    db.commit()

    return {
        "tag": tag,
        "employee": employee,
        "schedule": schedule,
        "structure": structure,
        "contract": contract,
        "paid_type": paid_type,
        "unpaid_type": unpaid_type,
        "allocation": allocation,
        "unpaid_allocation": unpaid_allocation,
    }


def teardown(db, fx) -> None:
    print("Cleaning up fixtures ...")
    emp_id = fx["employee"].id
    db.execute(text("DELETE FROM leave_requests WHERE employee_id = :e"), {"e": str(emp_id)})
    db.execute(text("DELETE FROM leave_allocations WHERE employee_id = :e"), {"e": str(emp_id)})
    db.execute(text("DELETE FROM attendances WHERE employee_id = :e"), {"e": str(emp_id)})
    # payslips -> payslip_lines cascade; delete payruns created for this employee
    db.execute(
        text(
            "DELETE FROM payruns WHERE id IN ("
            "  SELECT payrun_id FROM payslips WHERE employee_id = :e)"
        ),
        {"e": str(emp_id)},
    )
    db.execute(text("DELETE FROM hr_contracts WHERE employee_id = :e"), {"e": str(emp_id)})
    db.execute(text("DELETE FROM employees WHERE id = :e"), {"e": str(emp_id)})
    db.execute(
        text("DELETE FROM salary_rules WHERE salary_structure_id = :s"),
        {"s": str(fx["structure"].id)},
    )
    db.execute(text("DELETE FROM salary_structures WHERE id = :s"), {"s": str(fx["structure"].id)})
    db.execute(
        text("DELETE FROM timeoff_types WHERE id IN (:a, :b)"),
        {"a": str(fx["paid_type"].id), "b": str(fx["unpaid_type"].id)},
    )
    db.execute(
        text("DELETE FROM working_schedule_lines WHERE schedule_id = :s"),
        {"s": str(fx["schedule"].id)},
    )
    db.execute(text("DELETE FROM working_schedules WHERE id = :s"), {"s": str(fx["schedule"].id)})
    db.commit()


def refresh_allocation(db, alloc_id) -> LeaveAllocation:
    db.expire_all()
    return db.get(LeaveAllocation, alloc_id)


def main() -> None:
    db = SessionLocal()
    fx = None
    try:
        fx = build_fixtures(db)
        emp = fx["employee"]
        alloc = fx["allocation"]

        # --- Starting balance ------------------------------------------------
        a = refresh_allocation(db, alloc.id)
        check("Start: allocated=20", approx(a.allocated_days, 20))
        check("Start: taken=5", approx(a.taken_days, 5))
        check("Start: remaining=15", approx(a.remaining_days, 15))

        # --- Employee requests 3 working days (paid) -------------------------
        # Pick a Mon-Wed window (March 9 - March 11) so public holidays like Holi (March 4) don't reduce working days.
        start = date(2026, 3, 9)  # Monday
        end = date(2026, 3, 11)   # Wednesday
        req = timeoff_service.create_leave_request(
            db,
            employee_id=emp.id,
            timeoff_type_id=fx["paid_type"].id,
            start_date=start,
            end_date=end,
            reason="Acceptance scenario",
        )
        check("Request duration computed as 3 working days", approx(req.duration_days, 3),
              detail=str(req.duration_days))
        check("Request status is TO_APPROVE (pending)", req.status == "TO_APPROVE",
              detail=req.status)

        a = refresh_allocation(db, alloc.id)
        check("Pending request does NOT change taken (still 5)", approx(a.taken_days, 5),
              detail=str(a.taken_days))
        check("Pending request does NOT change remaining (still 15)",
              approx(a.remaining_days, 15), detail=str(a.remaining_days))

        # --- HR approves -----------------------------------------------------
        approved = timeoff_service.process_leave_approval(db, req.id, approver_employee_id=None)
        check("After approval status APPROVED", approved.status == "APPROVED",
              detail=approved.status)
        a = refresh_allocation(db, alloc.id)
        check("After approval taken=8", approx(a.taken_days, 8), detail=str(a.taken_days))
        check("After approval remaining=12", approx(a.remaining_days, 12),
              detail=str(a.remaining_days))

        # --- Duplicate approval must be rejected (no double deduction) -------
        dup_rejected = False
        try:
            timeoff_service.process_leave_approval(db, req.id, approver_employee_id=None)
        except Exception:
            dup_rejected = True
            db.rollback()
        check("Duplicate approval is rejected", dup_rejected)
        a = refresh_allocation(db, alloc.id)
        check("Duplicate approval did not change taken (still 8)", approx(a.taken_days, 8),
              detail=str(a.taken_days))

        # --- Payroll detects the approved leave for the period ---------------
        att = attendance_service.compute_worked_days_and_hours(
            db, emp.id, start, end, emp.working_schedule_id
        )
        check("Payroll sees approved leave_days=3", approx(att["leave_days"], 3),
              detail=str(att["leave_days"]))
        check("Paid leave bucket=3 (this leave type is paid)",
              approx(att["paid_leave_days"], 3), detail=str(att["paid_leave_days"]))
        check("Unpaid leave bucket=0 for a paid leave type",
              approx(att["unpaid_leave_days"], 0), detail=str(att["unpaid_leave_days"]))

        # --- Salary computation: paid leave => NO LOP deduction --------------
        rules = payrun_service.get_active_rules(db, fx["structure"].id)
        comp_paid = execute_salary_computation(
            fx["contract"], att["worked_days"], rules, attendance=att, employee=emp
        )
        lop_paid = next((abs(l["amount"]) for l in comp_paid["lines"] if l["rule_code"] == "LOP"), Decimal("0"))
        check("Paid leave produces NO loss-of-pay deduction", approx(lop_paid, 0),
              detail=str(lop_paid))
        check("Paid-leave net equals gross (60,000)", approx(comp_paid["net"], 60000),
              detail=str(comp_paid["net"]))

        # --- Now an UNPAID leave request over a full 30-day month ------------
        # 2 unpaid days on a month whose expected working days drive the daily rate.
        u_start = date(2026, 4, 6)   # Monday
        u_end = date(2026, 4, 7)     # Tuesday -> 2 working days
        u_req = timeoff_service.create_leave_request(
            db,
            employee_id=emp.id,
            timeoff_type_id=fx["unpaid_type"].id,
            start_date=u_start,
            end_date=u_end,
            reason="Unpaid scenario",
        )
        timeoff_service.process_leave_approval(db, u_req.id, approver_employee_id=None)

        period_start = date(2026, 4, 1)
        period_end = date(2026, 4, 30)
        att_u = attendance_service.compute_worked_days_and_hours(
            db, emp.id, period_start, period_end, emp.working_schedule_id
        )
        check("Unpaid leave bucket=2", approx(att_u["unpaid_leave_days"], 2),
              detail=str(att_u["unpaid_leave_days"]))

        comp_unpaid = execute_salary_computation(
            fx["contract"], att_u["worked_days"], rules, attendance=att_u, employee=emp
        )
        lop_unpaid = next((abs(l["amount"]) for l in comp_unpaid["lines"] if l["rule_code"] == "LOP"), Decimal("0"))
        expected_daily = Decimal("60000") / to_decimal(att_u["expected_days"])
        expected_lop = (expected_daily * 2).quantize(Decimal("0.01"))
        check(
            "Unpaid leave produces a loss-of-pay deduction (daily_rate x 2)",
            approx(lop_unpaid, expected_lop, tol=Decimal("1.00")),
            detail=f"got {lop_unpaid}, expected ~{expected_lop}",
        )
        check(
            "Unpaid-leave net = gross - LOP",
            approx(comp_unpaid["net"], Decimal("60000") - lop_unpaid),
            detail=str(comp_unpaid["net"]),
        )

        # --- Refusal of the approved PAID request credits balance back once --
        timeoff_service.process_leave_refusal(db, req.id, approver_employee_id=None)
        a = refresh_allocation(db, alloc.id)
        check("Refusing the approved request restores taken to 5",
              approx(a.taken_days, 5), detail=str(a.taken_days))
        check("Refusing restores remaining to 15", approx(a.remaining_days, 15),
              detail=str(a.remaining_days))

        # Refuse again -> idempotent, no further credit (no negative/duplicate).
        timeoff_service.process_leave_refusal(db, req.id, approver_employee_id=None)
        a = refresh_allocation(db, alloc.id)
        check("Second refusal does not over-credit (taken still 5)",
              approx(a.taken_days, 5), detail=str(a.taken_days))

    finally:
        if fx is not None:
            try:
                teardown(db, fx)
            except Exception as exc:  # noqa: BLE001
                print(f"  (teardown warning: {exc})")
        db.close()

    print("\n" + "=" * 60)
    print(f"Acceptance results: {passed} passed, {len(failed)} failed")
    if failed:
        for f in failed:
            print(f"  - {f}")
        sys.exit(1)
    print("ALL ACCEPTANCE CHECKS PASSED")


if __name__ == "__main__":
    main()
