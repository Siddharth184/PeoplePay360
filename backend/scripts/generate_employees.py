"""Additively generate realistic dummy employees.

Unlike `scripts.seed_db` (which TRUNCATEs and rebuilds the exact mockup scenario),
this script *appends* new, distinct employees to whatever is already in the
database. It is safe to run repeatedly: badge IDs, work emails and contract
references always continue past the highest value already present, and generated
names are checked against existing rows so nothing collides.

Each new employee gets:
  * an EMPLOYEE login (email + default password)
  * a RUNNING contract on the "Regular Salary" structure, numbered through the
    real CON/YYYY/NNNN sequence generator
  * Paid Time Off and Sick Leave allocations for the current year

It reuses the master data seeded by `scripts.seed_db` (departments, positions,
working schedules, salary structure, time-off types). Run `python -m scripts.seed_db`
first if the database is empty.

Efficiency: every row of a given kind is built in memory and inserted with a
single `add_all` + one flush per phase, so 25 employees cost a handful of round
trips rather than hundreds.

Usage:
    python -m scripts.generate_employees               # 25 employees
    python -m scripts.generate_employees --count 50
    python -m scripts.generate_employees --no-login     # skip creating logins
"""

from __future__ import annotations

import argparse
import random
import sys
from datetime import date
from decimal import Decimal
from pathlib import Path

from sqlalchemy import func, select

sys.path.insert(0, str(Path(__file__).resolve().parents[1]))

from app.core.database import SessionLocal, engine  # noqa: E402
from app.core.security import hash_password  # noqa: E402
from app.models import (  # noqa: E402
    AuthUser,
    Department,
    Employee,
    HrContract,
    JobPosition,
    LeaveAllocation,
    SalaryStructure,
    TimeOffType,
    WorkingSchedule,
)
from app.models.enums import UserRole  # noqa: E402
from app.services.reference import next_contract_reference  # noqa: E402

DEFAULT_PASSWORD = "PeoplePay@360"
CURRENT_YEAR = date.today().year

# Distinct name pools. 20 x 20 = 400 unique combinations, far more than we need,
# and every one is de-duplicated against names already in the database.
FIRST_NAMES = [
    "Aarohi", "Kabir", "Myra", "Reyansh", "Anaya", "Vivaan", "Saanvi", "Aryan",
    "Diya", "Ayaan", "Riya", "Kiaan", "Navya", "Advait", "Kyra", "Shaurya",
    "Aadya", "Vihaan", "Ira", "Rudra", "Prisha", "Dhruv", "Anika", "Arnav",
    "Mahira", "Ishaan", "Sara", "Yuvraj", "Tara", "Neil",
]
LAST_NAMES = [
    "Aggarwal", "Bajaj", "Chandra", "Dhawan", "Grover", "Hegde", "Jain", "Kohli",
    "Luthra", "Mahajan", "Nanda", "Oberoi", "Puri", "Rana", "Sethi", "Talwar",
    "Uppal", "Vohra", "Wadhwa", "Zaveri",
]

# Positions we may create per department if they do not already exist, each with a
# realistic monthly-wage band. Keeps generated pay believable and department-appropriate.
POSITIONS_BY_DEPARTMENT = {
    "Engineering": [
        ("Software Engineer", 85000, 110000),
        ("Senior Software Engineer", 130000, 165000),
        ("QA Engineer", 68000, 92000),
        ("Platform Engineer", 120000, 150000),
    ],
    "Finance": [
        ("Accountant", 60000, 85000),
        ("Financial Analyst", 90000, 120000),
        ("Payroll Officer", 70000, 100000),
    ],
    "Human Resources": [
        ("Recruiter", 55000, 80000),
        ("HR Executive", 55000, 75000),
        ("HR Business Partner", 95000, 130000),
    ],
    "Sales": [
        ("Account Executive", 70000, 95000),
        ("Sales Development Rep", 48000, 62000),
        ("Customer Success Manager", 85000, 115000),
    ],
    "Marketing": [
        ("Content Strategist", 65000, 90000),
        ("Performance Marketer", 80000, 105000),
        ("Marketing Analyst", 62000, 85000),
    ],
}

EMPLOYEE_TYPES = ["PERMANENT", "PERMANENT", "PERMANENT", "PROBATION", "CONTRACT"]
WORK_LOCATIONS = ["Mumbai", "Bengaluru", "Pune", "Hyderabad", "Remote"]
BANKS = [
    ("HDFC Bank", "HDFC0001234"),
    ("ICICI Bank", "ICIC0004567"),
    ("State Bank of India", "SBIN0007890"),
    ("Axis Bank", "UTIB0002345"),
    ("Kotak Mahindra Bank", "KKBK0006789"),
]


def _slugify_email(name: str) -> str:
    return name.lower().replace(" ", ".").replace("'", "")


def _highest_badge_number(db) -> int:
    """Largest N across existing EMP-NNN badges, so we continue past it."""
    rows = db.execute(select(Employee.badge_id)).scalars().all()
    highest = 0
    for badge in rows:
        if badge and badge.startswith("EMP-"):
            tail = badge.split("-", 1)[1]
            if tail.isdigit():
                highest = max(highest, int(tail))
    return highest


def _load_master(db) -> dict:
    departments = {d.name: d for d in db.execute(select(Department)).scalars()}
    if not departments:
        raise SystemExit(
            "No departments found. Run `python -m scripts.seed_db` first to create "
            "the master data this generator builds on."
        )

    structure = db.execute(
        select(SalaryStructure).where(SalaryStructure.code == "REG_SALARY")
    ).scalar_one_or_none()
    if structure is None:
        structure = db.execute(select(SalaryStructure)).scalars().first()

    schedule = db.execute(select(WorkingSchedule)).scalars().first()
    if schedule is None:
        raise SystemExit("No working schedule found. Run `scripts.seed_db` first.")

    # Existing positions keyed by (name, department_id) so we reuse rather than duplicate.
    positions = {
        (p.name, p.department_id): p
        for p in db.execute(select(JobPosition)).scalars()
    }

    timeoff = {t.name: t for t in db.execute(select(TimeOffType)).scalars()}

    # Department manager (for reporting lines) and an HR approver for allocations.
    dept_managers = {
        d.id: getattr(d, "manager_employee_id", None) for d in departments.values()
    }
    hr_approver = db.execute(
        select(Employee.id)
        .join(Department, Department.id == Employee.department_id)
        .where(Department.name == "Human Resources")
        .limit(1)
    ).scalar_one_or_none()

    return {
        "departments": departments,
        "structure": structure,
        "schedule": schedule,
        "positions": positions,
        "timeoff": timeoff,
        "dept_managers": dept_managers,
        "hr_approver": hr_approver,
    }


def _ensure_positions(db, master: dict) -> None:
    """Create any position in POSITIONS_BY_DEPARTMENT missing for its department."""
    departments = master["departments"]
    positions = master["positions"]
    created = []
    for dept_name, specs in POSITIONS_BY_DEPARTMENT.items():
        dept = departments.get(dept_name)
        if dept is None:
            continue
        for position_name, _lo, _hi in specs:
            key = (position_name, dept.id)
            if key not in positions:
                position = JobPosition(name=position_name, department_id=dept.id)
                db.add(position)
                created.append(position)
                positions[key] = position
    if created:
        db.flush()


def generate(db, count: int, make_login: bool) -> dict:
    master = _load_master(db)
    _ensure_positions(db, master)

    departments = master["departments"]
    positions = master["positions"]
    schedule = master["schedule"]
    structure = master["structure"]
    timeoff = master["timeoff"]
    dept_managers = master["dept_managers"]
    hr_approver = master["hr_approver"]

    existing_emails = set(
        db.execute(select(func.lower(Employee.work_email))).scalars().all()
    ) | set(db.execute(select(func.lower(AuthUser.email))).scalars().all())

    department_names = [
        name for name in POSITIONS_BY_DEPARTMENT if name in departments
    ]

    next_badge = _highest_badge_number(db) + 1

    # --- Phase 1: employees (and optional logins) --------------------------
    logins: list[AuthUser] = []
    employees: list[Employee] = []
    plans: list[dict] = []  # remember dept/position/wage for the contract phase

    used_names: set[str] = set()
    attempts = 0
    while len(plans) < count and attempts < count * 200:
        attempts += 1
        name = f"{random.choice(FIRST_NAMES)} {random.choice(LAST_NAMES)}"
        email = f"{_slugify_email(name)}@oxp.com"
        if name in used_names or email in existing_emails:
            continue
        used_names.add(name)
        existing_emails.add(email)

        dept_name = random.choice(department_names)
        dept = departments[dept_name]
        position_name, lo, hi = random.choice(POSITIONS_BY_DEPARTMENT[dept_name])
        position = positions[(position_name, dept.id)]
        wage = Decimal(str(random.randrange(lo, hi + 1, 1000)))

        badge = f"EMP-{next_badge:03d}"
        next_badge += 1
        bank_name, ifsc = random.choice(BANKS)

        login_id_holder = None
        if make_login:
            login = AuthUser(
                email=email,
                hashed_password=hash_password(DEFAULT_PASSWORD),
                role=UserRole.EMPLOYEE,
            )
            logins.append(login)
            login_id_holder = login

        employee = Employee(
            badge_id=badge,
            name=name,
            work_email=email,
            phone=f"+9198{random.randint(10000000, 99999999)}",
            department_id=dept.id,
            job_position_id=position.id,
            working_schedule_id=schedule.id,
            manager_id=dept_managers.get(dept.id),
            work_location=random.choice(WORK_LOCATIONS),
            status="ACTIVE",
            employee_type=random.choice(EMPLOYEE_TYPES),
            company_name="OXP Pvt Ltd",
            date_of_joining=date(CURRENT_YEAR, random.randint(1, 12), random.randint(1, 28)),
            bank_name=bank_name,
            bank_ifsc_or_routing=ifsc,
            bank_account_number=f"9876{random.randint(10000000, 99999999)}",
            pan_or_ssn=f"ABCDE{random.randint(1000, 9999)}{random.choice('FGHJK')}",
        )
        employees.append(employee)
        plans.append(
            {"employee": employee, "wage": wage, "login": login_id_holder}
        )

    if len(plans) < count:
        raise SystemExit(
            f"Could only generate {len(plans)} unique employees from the name pool; "
            "add more names to FIRST_NAMES / LAST_NAMES."
        )

    if logins:
        db.add_all(logins)
        db.flush()  # assigns login ids
    for plan in plans:
        if plan["login"] is not None:
            plan["employee"].user_id = plan["login"].id

    db.add_all(employees)
    db.flush()  # assigns employee ids used below

    # --- Phase 2: one RUNNING contract each --------------------------------
    contracts: list[HrContract] = []
    for plan in plans:
        employee = plan["employee"]
        contracts.append(
            HrContract(
                reference_code=next_contract_reference(db, date(CURRENT_YEAR, 1, 1)),
                employee_id=employee.id,
                department_id=employee.department_id,
                job_position_id=employee.job_position_id,
                working_schedule_id=employee.working_schedule_id,
                salary_structure_id=structure.id if structure else None,
                start_date=employee.date_of_joining,
                end_date=None,
                wage_monthly=plan["wage"],
                status="RUNNING",
                notes=f"Auto-generated contract for FY {CURRENT_YEAR}.",
            )
        )
    db.add_all(contracts)
    db.flush()

    # --- Phase 3: leave allocations ----------------------------------------
    allocations: list[LeaveAllocation] = []
    pto = timeoff.get("Paid Time Off")
    sick = timeoff.get("Sick Leave")
    for plan in plans:
        employee = plan["employee"]
        if pto is not None:
            allocations.append(
                LeaveAllocation(
                    employee_id=employee.id,
                    timeoff_type_id=pto.id,
                    allocated_days=Decimal("20.00"),
                    taken_days=Decimal("0.00"),
                    validity_year=CURRENT_YEAR,
                    status="APPROVED",
                    approver_employee_id=hr_approver,
                    description=f"{CURRENT_YEAR} Annual Leave Allocation",
                )
            )
        if sick is not None:
            allocations.append(
                LeaveAllocation(
                    employee_id=employee.id,
                    timeoff_type_id=sick.id,
                    allocated_days=Decimal("12.00"),
                    taken_days=Decimal("0.00"),
                    validity_year=CURRENT_YEAR,
                    status="APPROVED",
                    approver_employee_id=hr_approver,
                    description=f"{CURRENT_YEAR} Sick Leave Allocation",
                )
            )
    if allocations:
        db.add_all(allocations)

    db.commit()

    return {
        "employees": len(employees),
        "logins": len(logins),
        "contracts": len(contracts),
        "allocations": len(allocations),
        "first_badge": employees[0].badge_id,
        "last_badge": employees[-1].badge_id,
        "sample": [(e.badge_id, e.name, e.work_email) for e in employees[:5]],
    }


def main() -> None:
    parser = argparse.ArgumentParser(
        description="Additively generate realistic dummy employees."
    )
    parser.add_argument(
        "--count", type=int, default=25, help="How many employees to create (default 25)."
    )
    parser.add_argument(
        "--no-login",
        action="store_true",
        help="Do not create AuthUser logins for the generated employees.",
    )
    parser.add_argument(
        "--seed",
        type=int,
        default=None,
        help="Optional RNG seed for reproducible output.",
    )
    args = parser.parse_args()

    if args.count < 1:
        raise SystemExit("--count must be at least 1.")
    if args.seed is not None:
        random.seed(args.seed)

    print(f"Generating {args.count} employee(s) ...")
    db = SessionLocal()
    try:
        result = generate(db, args.count, make_login=not args.no_login)
    finally:
        db.close()
        engine.dispose()

    print("-" * 52)
    print(f"  employees created : {result['employees']}")
    print(f"  logins created    : {result['logins']}")
    print(f"  contracts created : {result['contracts']} (RUNNING, Regular Salary)")
    print(f"  allocations       : {result['allocations']}")
    print(f"  badge range       : {result['first_badge']} .. {result['last_badge']}")
    print("  sample:")
    for badge, name, email in result["sample"]:
        print(f"    {badge}  {name:<22} {email}")
    if result["logins"]:
        print(f"\n  Login password for every new account: {DEFAULT_PASSWORD}")
    print("\nDone with zero integrity errors.")


if __name__ == "__main__":
    main()
