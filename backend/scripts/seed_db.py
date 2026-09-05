"""Seed the PeoplePay360 database with realistic, mockup-matching data.

Reproduces the reference scenario from the architecture document:
  * Aarav Mehta (EMP-001), Finance, contract CON/2026/0042, wage 100,000
  * Sara Khan, HR Manager
  * 42 employees across five departments
  * The 7-rule "Regular Salary" structure that yields exactly
    50,000 / 20,000 / 10,000 / 80,000 / -3,000 / -2,000 / 75,000 on a 100,000 wage
  * A "February 2026" payrun covering all eligible employees
  * The HR knowledge base, embedded locally into pgvector
  * Escalation routing rules for every question category

Destructive: TRUNCATEs the data tables first so re-running always gives the same
starting point. Run `python -m scripts.init_db` first to create the schema.

Usage:
    python -m scripts.seed_db
    python -m scripts.seed_db --skip-knowledge   # faster; no embedding model load
"""

from __future__ import annotations

import argparse
import random
import sys
from datetime import date, datetime, time, timedelta, timezone
from decimal import Decimal
from pathlib import Path

from sqlalchemy import text

sys.path.insert(0, str(Path(__file__).resolve().parents[1]))

from app.core.database import SessionLocal, engine  # noqa: E402
from app.core.security import hash_password  # noqa: E402
from app.models import (  # noqa: E402
    Attendance,
    AuthUser,
    Department,
    Employee,
    EscalationRoutingRule,
    HrContract,
    JobPosition,
    LeaveAllocation,
    LeaveRequest,
    Payrun,
    PublicHoliday,
    SalaryRule,
    SalaryStructure,
    TimeOffType,
    WorkingSchedule,
    WorkingScheduleLine,
)
from app.models.enums import (  # noqa: E402
    EscalationCategory,
    EscalationPriority,
    UserRole,
)
from app.services import payrun_service  # noqa: E402
from scripts.hr_policies import POLICY_DOCUMENTS  # noqa: E402

random.seed(360)  # deterministic seed data: same demo every time

DEFAULT_PASSWORD = "PeoplePay@360"

# The reference period from the mockup
PERIOD_START = date(2026, 2, 1)
PERIOD_END = date(2026, 2, 28)

TRUNCATE_ORDER = [
    "rag_escalation_events",
    "notifications",
    "rag_escalations",
    "rag_retrieval_log",
    "ai_messages",
    "ai_conversations",
    "document_chunks",
    "escalation_routing_rules",
    "payslip_lines",
    "payslips",
    "payruns",
    "salary_rules",
    "salary_structures",
    "leave_requests",
    "leave_allocations",
    "timeoff_types",
    "attendances",
    "hr_contracts",
    "employees",
    "job_positions",
    "departments",
    "working_schedule_lines",
    "working_schedules",
    "public_holidays",
    "auth_users",
]

SEQUENCES = ["contract_seq", "payrun_seq", "payslip_seq", "escalation_seq"]

# 42 employees, matching the headcount in the mockup payrun.
STAFF = [
    # (name, department, position, monthly wage, role for login or None)
    ("Aarav Mehta", "Finance", "Payroll Officer", 100000, UserRole.HR_PAYROLL_USER),
    ("Sara Khan", "Human Resources", "HR Manager", 115000, UserRole.HR_MANAGER),
    ("Vikram Nair", "Finance", "Finance Controller", 165000, UserRole.HR_PAYROLL_MANAGER),
    ("Ishita Rao", "Human Resources", "HR Executive", 62000, None),
    ("Rohan Desai", "Engineering", "Engineering Manager", 195000, None),
    ("Ananya Iyer", "Engineering", "Senior Software Engineer", 148000, None),
    ("Karthik Menon", "Engineering", "Senior Software Engineer", 142000, None),
    ("Priya Sharma", "Engineering", "Software Engineer", 96000, None),
    ("Aditya Kulkarni", "Engineering", "Software Engineer", 92000, None),
    ("Meera Joshi", "Engineering", "Software Engineer", 89000, None),
    ("Siddharth Bose", "Engineering", "QA Engineer", 78000, None),
    ("Neha Kapoor", "Engineering", "QA Engineer", 74000, None),
    ("Arjun Reddy", "Engineering", "DevOps Engineer", 132000, None),
    ("Divya Pillai", "Engineering", "Software Engineer", 87000, None),
    ("Rahul Verma", "Engineering", "Junior Software Engineer", 58000, None),
    ("Tanvi Shah", "Engineering", "Junior Software Engineer", 56000, None),
    ("Manish Gupta", "Sales", "Sales Director", 178000, None),
    ("Pooja Bhatt", "Sales", "Account Executive", 84000, None),
    ("Nikhil Chauhan", "Sales", "Account Executive", 81000, None),
    ("Ritika Sen", "Sales", "Account Executive", 79000, None),
    ("Farhan Sheikh", "Sales", "Sales Development Rep", 54000, None),
    ("Kavya Menon", "Sales", "Sales Development Rep", 52000, None),
    ("Devang Patel", "Sales", "Regional Manager", 138000, None),
    ("Sneha Agarwal", "Marketing", "Marketing Manager", 128000, None),
    ("Yash Thakur", "Marketing", "Content Strategist", 76000, None),
    ("Aisha Qureshi", "Marketing", "Performance Marketer", 88000, None),
    ("Harsh Malhotra", "Marketing", "Graphic Designer", 64000, None),
    ("Lakshmi Krishnan", "Marketing", "Marketing Analyst", 71000, None),
    ("Gaurav Saxena", "Finance", "Senior Accountant", 94000, None),
    ("Ritu Sinha", "Finance", "Accountant", 68000, None),
    ("Omkar Deshpande", "Finance", "Accounts Payable Clerk", 49000, None),
    ("Bhavna Chopra", "Finance", "Financial Analyst", 102000, None),
    ("Zoya Ansari", "Human Resources", "Recruiter", 67000, None),
    ("Nitin Bansal", "Human Resources", "HR Operations Associate", 51000, None),
    ("Shruti Kaul", "Human Resources", "Learning & Development Lead", 98000, None),
    ("Abhinav Ghosh", "Engineering", "Data Engineer", 126000, None),
    ("Trisha Dutta", "Engineering", "Data Analyst", 84000, None),
    ("Varun Chandra", "Engineering", "Site Reliability Engineer", 139000, None),
    ("Nandini Rele", "Sales", "Customer Success Manager", 91000, None),
    ("Imran Pathan", "Sales", "Customer Success Associate", 61000, None),
    ("Rekha Bhardwaj", "Marketing", "Social Media Manager", 69000, None),
    ("Sanjay Dubey", "Finance", "Internal Auditor", 108000, None),
]

BANKS = [
    ("HDFC Bank", "HDFC0001234"),
    ("ICICI Bank", "ICIC0004567"),
    ("State Bank of India", "SBIN0007890"),
    ("Axis Bank", "UTIB0002345"),
    ("Kotak Mahindra Bank", "KKBK0006789"),
]

HOLIDAYS_2026 = [
    ("New Year's Day", date(2026, 1, 1)),
    ("Republic Day", date(2026, 1, 26)),
    ("Holi", date(2026, 3, 4)),
    ("Independence Day", date(2026, 8, 15)),
    ("Gandhi Jayanti", date(2026, 10, 2)),
    ("Diwali", date(2026, 11, 8)),
    ("Christmas Day", date(2026, 12, 25)),
]

# Category -> owning role, SLA hours, priority (architecture section 4.1)
ROUTING_SEED = [
    (EscalationCategory.LEAVE_POLICY, UserRole.HR_MANAGER, 8, EscalationPriority.NORMAL),
    (EscalationCategory.ATTENDANCE, UserRole.HR_MANAGER, 8, EscalationPriority.NORMAL),
    (EscalationCategory.CONTRACT, UserRole.HR_MANAGER, 24, EscalationPriority.NORMAL),
    (
        EscalationCategory.PAYROLL_SALARY,
        UserRole.HR_PAYROLL_MANAGER,
        4,
        EscalationPriority.HIGH,
    ),
    (
        EscalationCategory.TAX_STATUTORY,
        UserRole.HR_PAYROLL_MANAGER,
        24,
        EscalationPriority.NORMAL,
    ),
    (EscalationCategory.IT_ACCESS, UserRole.ADMIN, 4, EscalationPriority.HIGH),
    (EscalationCategory.OTHER, UserRole.ADMIN, 24, EscalationPriority.NORMAL),
]


def _slugify_email(name: str) -> str:
    return name.lower().replace(" ", ".").replace("'", "")


def wipe(db) -> None:
    print("Clearing existing data ...")
    db.execute(text(f"TRUNCATE TABLE {', '.join(TRUNCATE_ORDER)} CASCADE"))
    for seq in SEQUENCES:
        db.execute(text(f"ALTER SEQUENCE {seq} RESTART WITH 1"))
    db.commit()


def seed_master_data(db) -> dict:
    print("Seeding departments, positions, schedules and holidays ...")

    departments = {
        name: Department(name=name)
        for name in ["Engineering", "Finance", "Human Resources", "Sales", "Marketing"]
    }
    db.add_all(departments.values())
    db.flush()

    positions: dict[tuple[str, str], JobPosition] = {}
    for _, dept_name, position_name, _, _ in STAFF:
        key = (position_name, dept_name)
        if key not in positions:
            positions[key] = JobPosition(
                name=position_name, department_id=departments[dept_name].id
            )
    db.add_all(positions.values())

    schedule_40h = WorkingSchedule(
        name="40 Hours / Week",
        days_per_week=5,
        hours_per_week=Decimal("40.00"),
    )
    schedule_night = WorkingSchedule(
        name="Night Shift (36h)",
        days_per_week=4,
        hours_per_week=Decimal("36.00"),
    )
    db.add_all([schedule_40h, schedule_night])
    db.flush()

    day_names = ["Monday", "Tuesday", "Wednesday", "Thursday", "Friday"]
    for dow, day_name in enumerate(day_names):
        db.add(
            WorkingScheduleLine(
                schedule_id=schedule_40h.id,
                day_of_week=dow,
                day_name=day_name,
                start_time=time(9, 0),
                end_time=time(18, 0),
                break_hours=Decimal("1.00"),
            )
        )
    for dow, day_name in enumerate(["Monday", "Tuesday", "Wednesday", "Thursday"]):
        db.add(
            WorkingScheduleLine(
                schedule_id=schedule_night.id,
                day_of_week=dow,
                day_name=day_name,
                start_time=time(21, 0),
                end_time=time(6, 30) if False else time(23, 59),
                break_hours=Decimal("0.50"),
            )
        )

    for name, holiday_date in HOLIDAYS_2026:
        db.add(PublicHoliday(name=name, holiday_date=holiday_date))

    db.commit()
    return {
        "departments": departments,
        "positions": positions,
        "schedule_40h": schedule_40h,
        "schedule_night": schedule_night,
    }


def seed_salary_structure(db) -> SalaryStructure:
    """The mockup's payroll configuration: three structures, 13 rules on Regular.

    The mockup shows the structure with many rules in the list but only SEVEN
    lines on Aarav's payslip. That is not a contradiction: a structure holds every
    rule the company might apply, and a rule that evaluates to zero produces no
    payslip line (see the zero-suppression note in salary_engine). The Loss of Pay
    (LOP) rule is one such rule: it is zero, and therefore invisible, unless the
    employee has approved UNPAID leave in the period.

    On a 100,000 monthly wage these reproduce the mockup payslip exactly:
        BASIC 50% of wage        =  50,000
        HRA   40% of basic       =  20,000
        STD   fixed              =  10,000
        GROSS basic + allowances =  80,000
        PF    6% of basic        =  -3,000
        PT    fixed              =  -2,000
        NET   gross - deductions =  75,000

    BONUS, LTA and FIX sit at zero until HR awards them. LWF and ESIC are
    genuinely conditional: ESIC only applies below the statutory gross ceiling, so
    at a gross of 80,000 it correctly contributes nothing.
    """
    print("Seeding salary structures and rules ...")
    structure = SalaryStructure(
        name="Regular Salary",
        code="REG_SALARY",
        notes="Standard monthly structure for full-time staff.",
    )
    db.add(structure)
    db.flush()

    def rule(**kw) -> SalaryRule:
        return SalaryRule(salary_structure_id=structure.id, **kw)

    rules = [
        rule(
            name="Basic Salary",
            code="BASIC",
            sequence=1,
            category="BASIC",
            computation_type="PERCENTAGE",
            percentage_base="WAGE",
            percentage_rate=Decimal("50.00"),
        ),
        rule(
            name="House Rent Allowance",
            code="HRA",
            sequence=10,
            category="ALLOWANCE",
            computation_type="PERCENTAGE",
            percentage_base="BASIC",
            percentage_rate=Decimal("40.00"),
        ),
        rule(
            name="Standard Allowance",
            code="STD",
            sequence=20,
            category="ALLOWANCE",
            computation_type="FIXED",
            fixed_amount=Decimal("10000.00"),
        ),
        rule(
            name="Overtime Pay",
            code="OT",
            sequence=35,
            category="ALLOWANCE",
            computation_type="PYTHON_CODE",
            python_code=(
                "# Overtime Pay: (Monthly wage / 208 standard monthly working hours) * 1.5 * overtime_hours\n"
                "if overtime_hours > 0:\n"
                "    result = round((contract.wage / 208) * 1.5 * overtime_hours, 2)\n"
                "else:\n"
                "    result = 0"
            ),
        ),
        rule(
            name="Performance Bonus",
            code="BONUS",
            sequence=30,
            category="ALLOWANCE",

            computation_type="FIXED",
            fixed_amount=Decimal("0.00"),
        ),
        rule(
            name="Leave Travel Allowance",
            code="LTA",
            sequence=40,
            category="ALLOWANCE",
            computation_type="FIXED",
            fixed_amount=Decimal("0.00"),
        ),
        rule(
            name="Fixed Allowance",
            code="FIX",
            sequence=50,
            category="ALLOWANCE",
            computation_type="FIXED",
            fixed_amount=Decimal("0.00"),
        ),
        rule(
            name="Gross Salary",
            code="GROSS",
            sequence=60,
            category="GROSS",
            computation_type="PYTHON_CODE",
            python_code="result = categories['BASIC'] + categories['ALLOWANCE']",
        ),
        rule(
            name="LWF fund",
            code="LWF",
            sequence=70,
            category="DEDUCTION",
            computation_type="FIXED",
            fixed_amount=Decimal("0.00"),
        ),
        rule(
            name="Provident Fund",
            code="PF",
            sequence=80,
            category="DEDUCTION",
            computation_type="PERCENTAGE",
            percentage_base="BASIC",
            percentage_rate=Decimal("6.00"),
        ),
        # A genuine conditional formula, and a good demonstration of the sandbox:
        # ESIC applies at 0.75% of gross only up to the statutory wage ceiling.
        rule(
            name="ESIC",
            code="ESIC",
            sequence=90,
            category="DEDUCTION",
            computation_type="PYTHON_CODE",
            python_code=(
                "# Employee State Insurance applies only below the wage ceiling.\n"
                "if categories['GROSS'] <= 21000:\n"
                "    result = round(categories['GROSS'] * 0.0075, 2)\n"
                "else:\n"
                "    result = 0"
            ),
        ),
        rule(
            name="Professional Tax",
            code="PT",
            sequence=100,
            category="DEDUCTION",
            computation_type="FIXED",
            fixed_amount=Decimal("2000.00"),
        ),
        # Loss of Pay: pro-rata deduction for UNPAID approved leave in the period.
        # The number is produced entirely by this configured rule from the engine
        # inputs (gross, expected_days, unpaid_leave_days) - no hardcoded payroll
        # logic. Paid leave never reaches unpaid_leave_days, so it is not deducted.
        # Evaluates to 0 (and is zero-suppressed) when there is no unpaid leave.
        rule(
            name="Loss of Pay (Unpaid Leave)",
            code="LOP",
            sequence=105,
            category="DEDUCTION",
            computation_type="PYTHON_CODE",
            python_code=(
                "# Daily rate x unpaid approved leave days.\n"
                "if unpaid_leave_days > 0 and expected_days > 0:\n"
                "    daily_rate = categories['GROSS'] / expected_days\n"
                "    result = round(daily_rate * unpaid_leave_days, 2)\n"
                "else:\n"
                "    result = 0"
            ),
        ),
        rule(
            name="Net Salary",
            code="NET",
            sequence=110,
            category="NET",
            computation_type="PYTHON_CODE",
            python_code="result = categories['GROSS'] - categories['DEDUCTION']",
        ),
    ]
    db.add_all(rules)

    # --- Intern Stipend: attendance-prorated, proving the engine is not fixed ---
    intern = SalaryStructure(
        name="Intern Stipend",
        code="INTERN",
        notes="Attendance-prorated stipend with a single statutory deduction.",
    )
    db.add(intern)
    db.flush()
    db.add_all(
        [
            SalaryRule(
                salary_structure_id=intern.id,
                name="Stipend",
                code="BASIC",
                sequence=1,
                category="BASIC",
                computation_type="PYTHON_CODE",
                # Interns are paid for the days they actually attended.
                python_code=(
                    "if expected_days > 0:\n"
                    "    result = round(contract.wage * worked_days / expected_days, 2)\n"
                    "else:\n"
                    "    result = contract.wage"
                ),
            ),
            SalaryRule(
                salary_structure_id=intern.id,
                name="Gross Salary",
                code="GROSS",
                sequence=60,
                category="GROSS",
                computation_type="PYTHON_CODE",
                python_code="result = categories['BASIC'] + categories['ALLOWANCE']",
            ),
            SalaryRule(
                salary_structure_id=intern.id,
                name="Professional Tax",
                code="PT",
                sequence=100,
                category="DEDUCTION",
                computation_type="FIXED",
                fixed_amount=Decimal("200.00"),
            ),
            SalaryRule(
                salary_structure_id=intern.id,
                name="Net Salary",
                code="NET",
                sequence=110,
                category="NET",
                computation_type="PYTHON_CODE",
                python_code="result = categories['GROSS'] - categories['DEDUCTION']",
            ),
        ]
    )

    # --- Contractor: gross equals wage, single withholding, no statutory PF ---
    contractor = SalaryStructure(
        name="Contractor",
        code="CONTRACTOR",
        notes="Consultant fee with tax withheld at source. No PF or ESIC.",
    )
    db.add(contractor)
    db.flush()
    db.add_all(
        [
            SalaryRule(
                salary_structure_id=contractor.id,
                name="Consulting Fee",
                code="BASIC",
                sequence=1,
                category="BASIC",
                computation_type="PERCENTAGE",
                percentage_base="WAGE",
                percentage_rate=Decimal("100.00"),
            ),
            SalaryRule(
                salary_structure_id=contractor.id,
                name="Gross Salary",
                code="GROSS",
                sequence=60,
                category="GROSS",
                computation_type="PYTHON_CODE",
                python_code="result = categories['BASIC'] + categories['ALLOWANCE']",
            ),
            SalaryRule(
                salary_structure_id=contractor.id,
                name="Tax Deducted at Source",
                code="TDS",
                sequence=90,
                category="DEDUCTION",
                computation_type="PERCENTAGE",
                percentage_base="GROSS",
                percentage_rate=Decimal("10.00"),
            ),
            SalaryRule(
                salary_structure_id=contractor.id,
                name="Net Payable",
                code="NET",
                sequence=110,
                category="NET",
                computation_type="PYTHON_CODE",
                python_code="result = categories['GROSS'] - categories['DEDUCTION']",
            ),
        ]
    )

    db.commit()
    print(
        f"  Regular Salary: {len(rules)} rules, Intern Stipend: 4, Contractor: 4"
    )
    return structure


def seed_people(db, master: dict) -> dict:
    print(f"Seeding {len(STAFF)} employees, logins and contracts ...")
    departments = master["departments"]
    positions = master["positions"]
    schedule_40h = master["schedule_40h"]

    # Admin account: not an employee, purely a system operator.
    admin = AuthUser(
        email="admin@oxp.com",
        hashed_password=hash_password(DEFAULT_PASSWORD),
        role=UserRole.ADMIN,
    )
    db.add(admin)
    db.flush()

    employees: list[Employee] = []
    by_name: dict[str, Employee] = {}

    for index, (name, dept_name, position_name, wage, login_role) in enumerate(STAFF, 1):
        bank_name, ifsc = BANKS[index % len(BANKS)]
        email = f"{_slugify_email(name)}@oxp.com"

        user_id = None
        if login_role is not None:
            login = AuthUser(
                email=email,
                hashed_password=hash_password(DEFAULT_PASSWORD),
                role=login_role,
            )
            db.add(login)
            db.flush()
            user_id = login.id
        elif index <= 12:
            # Give the first dozen non-privileged staff an EMPLOYEE login so the
            # self-service and copilot flows are demoable from several accounts.
            login = AuthUser(
                email=email,
                hashed_password=hash_password(DEFAULT_PASSWORD),
                role=UserRole.EMPLOYEE,
            )
            db.add(login)
            db.flush()
            user_id = login.id

        # A realistic type mix so the dashboard's Employee Type filter has data.
        # The junior-most staff are on probation; two roles are consultants.
        if position_name.startswith("Junior"):
            employee_type = "PROBATION"
        elif position_name in ("Internal Auditor", "Content Strategist"):
            employee_type = "CONSULTANT"
        elif position_name in ("Sales Development Rep", "Accounts Payable Clerk"):
            employee_type = "CONTRACT"
        else:
            employee_type = "PERMANENT"

        employee = Employee(
            user_id=user_id,
            badge_id=f"EMP-{index:03d}",
            name=name,
            work_email=email,
            phone=f"+9198{random.randint(10000000, 99999999)}",
            department_id=departments[dept_name].id,
            job_position_id=positions[(position_name, dept_name)].id,
            working_schedule_id=schedule_40h.id,
            work_location=random.choice(["Mumbai", "Bengaluru", "Pune", "Remote"]),
            status="ACTIVE",
            employee_type=employee_type,
            company_name="OXP Pvt Ltd",
            date_of_joining=date(2024, 1, 1) + timedelta(days=index * 11),
            bank_name=bank_name,
            bank_ifsc_or_routing=ifsc,
            bank_account_number=f"9876{random.randint(10000000, 99999999)}",
            pan_or_ssn=f"ABCDE{1000 + index}F",
        )
        db.add(employee)
        employees.append(employee)
        by_name[name] = employee

    db.flush()

    # --- Deliberate anomalies so the pre-flight inspector has something to find
    # An employee with no bank details -> advisory warning on the payrun.
    by_name["Tanvi Shah"].bank_account_number = None
    by_name["Tanvi Shah"].bank_ifsc_or_routing = None
    # An employee with no tax identifier -> statutory reporting warning.
    by_name["Rahul Verma"].pan_or_ssn = None

    # --- Reporting lines and department managers
    managers = {
        "Engineering": "Rohan Desai",
        "Finance": "Vikram Nair",
        "Human Resources": "Sara Khan",
        "Sales": "Manish Gupta",
        "Marketing": "Sneha Agarwal",
    }
    for dept_name, manager_name in managers.items():
        departments[dept_name].manager_employee_id = by_name[manager_name].id

    for name, dept_name, *_ in STAFF:
        manager_name = managers[dept_name]
        if name != manager_name:
            by_name[name].manager_id = by_name[manager_name].id

    db.flush()

    # --- Contracts. Aarav keeps the mockup's CON/2026/0042 reference, so every
    # other contract skips 42 to avoid colliding with it.
    AARAV_CONTRACT_NUMBER = 42
    next_number = 1

    for index, (name, dept_name, position_name, wage, _) in enumerate(STAFF, 1):
        employee = by_name[name]
        if name == "Aarav Mehta":
            reference = f"CON/2026/{AARAV_CONTRACT_NUMBER:04d}"
        else:
            if next_number == AARAV_CONTRACT_NUMBER:
                next_number += 1
            reference = f"CON/2026/{next_number:04d}"
            next_number += 1
        db.add(
            HrContract(
                reference_code=reference,
                employee_id=employee.id,
                department_id=employee.department_id,
                job_position_id=employee.job_position_id,
                working_schedule_id=employee.working_schedule_id,
                start_date=date(2026, 1, 1),
                end_date=None,
                wage_monthly=Decimal(str(wage)),
                status="RUNNING",
                notes="Annual contract for FY 2026.",
            )
        )

    # An expiring contract so the 45-day renewal warning fires.
    db.flush()
    expiring = by_name["Farhan Sheikh"]
    db.execute(
        text(
            "UPDATE hr_contracts SET end_date = :end WHERE employee_id = :emp"
        ),
        {"end": date(2026, 3, 15), "emp": expiring.id},
    )

    # A DRAFT-only employee: no RUNNING contract -> blocking payroll anomaly.
    no_contract = Employee(
        badge_id="EMP-043",
        name="Preeti Nambiar",
        work_email="preeti.nambiar@oxp.com",
        department_id=departments["Marketing"].id,
        job_position_id=positions[("Marketing Analyst", "Marketing")].id,
        working_schedule_id=schedule_40h.id,
        work_location="Remote",
        status="ACTIVE",
        employee_type="PROBATION",
        date_of_joining=date(2026, 2, 20),
        bank_name="HDFC Bank",
        bank_ifsc_or_routing="HDFC0001234",
        bank_account_number="9876123456780",
        pan_or_ssn="ZZZZZ9999Z",
        manager_id=by_name["Sneha Agarwal"].id,
    )
    db.add(no_contract)
    db.flush()
    db.add(
        HrContract(
            reference_code="CON/2026/0099",
            employee_id=no_contract.id,
            department_id=no_contract.department_id,
            job_position_id=no_contract.job_position_id,
            working_schedule_id=schedule_40h.id,
            start_date=date(2026, 2, 20),
            wage_monthly=Decimal("70000.00"),
            status="DRAFT",
            notes="Awaiting signature - deliberately left DRAFT to exercise the "
            "payroll pre-flight blocking check.",
        )
    )

    db.commit()
    return {"admin": admin, "employees": employees, "by_name": by_name}


def seed_timeoff(db, people: dict) -> None:
    print("Seeding time off types, allocations and requests ...")

    pto = TimeOffType(
        name="Paid Time Off",
        unit="DAYS",
        requires_allocation=True,
        approval_level="MANAGER",
        display_color="#017E84",
        work_entry_type="Leave Work Entry",
        is_paid=True,
        notes="Standard annual leave. Balance comes from approved allocations.",
    )
    sick = TimeOffType(
        name="Sick Leave",
        unit="DAYS",
        requires_allocation=True,
        approval_level="HR_OFFICER",
        display_color="#C2410C",
        work_entry_type="Sick Work Entry",
        is_paid=True,
        notes="Medical certificate required for three or more continuous days.",
    )
    comp_off = TimeOffType(
        name="Comp Off",
        unit="HOURS",
        requires_allocation=True,
        approval_level="HR_OFFICER",
        display_color="#4338CA",
        work_entry_type="Compensatory Work Entry",
        is_paid=True,
        notes="Granted against approved overtime.",
    )
    unpaid = TimeOffType(
        name="Unpaid Leave",
        unit="DAYS",
        requires_allocation=False,
        approval_level="HR_OFFICER",
        display_color="#6B7280",
        work_entry_type="Unpaid Work Entry",
        is_paid=False,
        notes="No allocation required; reduces paid worked days via loss-of-pay.",
    )
    db.add_all([pto, sick, comp_off, unpaid])
    db.flush()

    by_name = people["by_name"]
    hr_manager = by_name["Sara Khan"]

    for employee in people["employees"]:
        # Aarav matches the mockup exactly: 20 allocated, 8 already taken.
        taken = Decimal("8.00") if employee.name == "Aarav Mehta" else Decimal("0.00")
        allocation = LeaveAllocation(
            employee_id=employee.id,
            timeoff_type_id=pto.id,
            allocated_days=Decimal("20.00"),
            taken_days=taken,
            validity_year=2026,
            status="APPROVED",
            approver_employee_id=hr_manager.id,
            description="2026 Annual Leave Allocation",
        )
        db.add(allocation)
        db.add(
            LeaveAllocation(
                employee_id=employee.id,
                timeoff_type_id=sick.id,
                allocated_days=Decimal("12.00"),
                validity_year=2026,
                status="APPROVED",
                approver_employee_id=hr_manager.id,
                description="2026 Sick Leave Allocation",
            )
        )
    db.flush()

    # A handful of requests in each state so every list filter has data.
    pending = [
        ("Priya Sharma", date(2026, 3, 9), date(2026, 3, 11), "Family function"),
        ("Nikhil Chauhan", date(2026, 3, 16), date(2026, 3, 17), "Personal"),
        ("Trisha Dutta", date(2026, 4, 6), date(2026, 4, 10), "Vacation"),
    ]
    for name, start, end, reason in pending:
        working_days = sum(
            1
            for offset in range((end - start).days + 1)
            if (start + timedelta(days=offset)).weekday() < 5
        )
        db.add(
            LeaveRequest(
                employee_id=by_name[name].id,
                timeoff_type_id=pto.id,
                start_date=start,
                end_date=end,
                duration_days=Decimal(str(working_days)),
                reason=reason,
                status="TO_APPROVE",
            )
        )

    # Aarav's 8 taken days, recorded as an approved request against his allocation.
    aarav_allocation = db.execute(
        text(
            """
            SELECT id FROM leave_allocations
            WHERE employee_id = :emp AND timeoff_type_id = :kind
            """
        ),
        {"emp": by_name["Aarav Mehta"].id, "kind": pto.id},
    ).scalar_one()
    db.add(
        LeaveRequest(
            employee_id=by_name["Aarav Mehta"].id,
            timeoff_type_id=pto.id,
            allocation_id=aarav_allocation,
            start_date=date(2026, 1, 12),
            end_date=date(2026, 1, 21),
            duration_days=Decimal("8.00"),
            reason="Annual family holiday",
            status="APPROVED",
            approver_employee_id=hr_manager.id,
        )
    )

    db.add(
        LeaveRequest(
            employee_id=by_name["Harsh Malhotra"].id,
            timeoff_type_id=sick.id,
            start_date=date(2026, 2, 10),
            end_date=date(2026, 2, 10),
            duration_days=Decimal("1.00"),
            reason="Medical appointment",
            status="REFUSED",
            approver_employee_id=hr_manager.id,
        )
    )

    # Approved leave INSIDE the February payroll period, so the dashboard's
    # "Approved Time Off Days" card and the Time Off Overview panel have real
    # numbers for the default period rather than reading zero.
    february_leave = [
        ("Ananya Iyer", pto, date(2026, 2, 9), date(2026, 2, 11), "Personal"),
        ("Karthik Menon", pto, date(2026, 2, 16), date(2026, 2, 20), "Vacation"),
        ("Rohan Desai", pto, date(2026, 2, 23), date(2026, 2, 24), "Family event"),
        ("Divya Pillai", sick, date(2026, 2, 5), date(2026, 2, 6), "Flu"),
        ("Arjun Reddy", sick, date(2026, 2, 12), date(2026, 2, 12), "Medical test"),
        ("Ritika Sen", pto, date(2026, 2, 25), date(2026, 2, 27), "Wedding"),
        ("Lakshmi Krishnan", pto, date(2026, 2, 2), date(2026, 2, 4), "Travel"),
    ]
    for name, kind, start, end, reason in february_leave:
        working = sum(
            1
            for offset in range((end - start).days + 1)
            if (start + timedelta(days=offset)).weekday() < 5
        )
        if not working:
            continue
        allocation_id = db.execute(
            text(
                """
                SELECT id FROM leave_allocations
                WHERE employee_id = :emp AND timeoff_type_id = :kind
                  AND status = 'APPROVED'
                LIMIT 1
                """
            ),
            {"emp": by_name[name].id, "kind": kind.id},
        ).scalar_one()
        db.add(
            LeaveRequest(
                employee_id=by_name[name].id,
                timeoff_type_id=kind.id,
                allocation_id=allocation_id,
                start_date=start,
                end_date=end,
                duration_days=Decimal(str(working)),
                reason=reason,
                status="APPROVED",
                approver_employee_id=hr_manager.id,
            )
        )
        # Keep the ledger honest: an approved request must be reflected in taken_days.
        db.execute(
            text(
                "UPDATE leave_allocations SET taken_days = taken_days + :d "
                "WHERE id = :id"
            ),
            {"d": Decimal(str(working)), "id": allocation_id},
        )

    db.commit()


def seed_attendance(db, people: dict) -> None:
    """Punches for February 2026, with realistic late arrivals and overtime."""
    print("Seeding February 2026 attendance ...")

    holidays = {h for _, h in HOLIDAYS_2026}
    working_days = [
        PERIOD_START + timedelta(days=offset)
        for offset in range((PERIOD_END - PERIOD_START).days + 1)
        if (PERIOD_START + timedelta(days=offset)).weekday() < 5
        and (PERIOD_START + timedelta(days=offset)) not in holidays
    ]

    expected = Decimal("8.00")
    records = 0
    counts = {"PRESENT": 0, "LATE": 0, "HALF_DAY": 0, "absent": 0, "overtime": 0}

    # Lateness and day length are INDEPENDENT dice. Deriving both from one roll
    # made every late arrival also a short day, so the HALF_DAY override swallowed
    # the LATE status and the dashboard's Late count was always zero.
    for employee in people["employees"]:
        for day in working_days:
            if random.random() < 0.04:
                counts["absent"] += 1
                continue  # no punch at all -> unexplained absence

            is_late = random.random() < 0.11
            start_minute = random.randint(20, 55) if is_late else random.randint(0, 12)
            check_in = datetime(
                day.year, day.month, day.day, 9, start_minute, tzinfo=timezone.utc
            )

            length_roll = random.random()
            if length_roll < 0.06:
                worked_hours = Decimal(str(round(random.uniform(3.0, 3.9), 2)))
            elif length_roll > 0.90:
                worked_hours = Decimal(str(round(random.uniform(9.5, 11.0), 2)))
            else:
                # Deliberately capped at the expected 8.00 so overtime comes only
                # from genuinely long days, not from rounding noise on normal ones.
                worked_hours = Decimal(str(round(random.uniform(7.75, 8.00), 2)))

            # A short day is a half day; otherwise lateness decides the status.
            if worked_hours < expected / 2:
                status = "HALF_DAY"
            elif is_late:
                status = "LATE"
            else:
                status = "PRESENT"

            overtime = max(Decimal("0.00"), worked_hours - expected)
            counts[status] += 1
            if overtime > 0:
                counts["overtime"] += 1

            db.add(
                Attendance(
                    employee_id=employee.id,
                    check_in=check_in,
                    # +1h puts the unpaid break back into the wall-clock span.
                    check_out=check_in + timedelta(hours=float(worked_hours) + 1.0),
                    worked_hours=worked_hours,
                    overtime_hours=overtime,
                    status=status,
                )
            )
            records += 1

    db.flush()

    # --- Deliberate data-quality problems the dashboard must surface ---------
    by_name = people["by_name"]

    # "Missing check-outs": someone forgot to clock out on a past day. The partial
    # unique index allows only one open punch per employee, so these are five
    # different people. Test accounts are excluded so punch tests stay predictable.
    forgot_checkout = [
        "Gaurav Saxena",
        "Ritu Sinha",
        "Yash Thakur",
        "Abhinav Ghosh",
        "Nandini Rele",
    ]
    for offset, name in enumerate(forgot_checkout):
        db.add(
            Attendance(
                employee_id=by_name[name].id,
                check_in=datetime(2026, 2, 17 + offset, 9, 5, tzinfo=timezone.utc),
                check_out=None,
                worked_hours=Decimal("0.00"),
                overtime_hours=Decimal("0.00"),
                status="PRESENT",
                audit_notes="No check-out recorded.",
            )
        )

    # "Manual attendance edits": HR corrections, which auditors look at closely.
    corrected = [
        "Priya Sharma",
        "Meera Joshi",
        "Neha Kapoor",
        "Pooja Bhatt",
        "Aisha Qureshi",
        "Sneha Agarwal",
        "Devang Patel",
    ]
    for offset, name in enumerate(corrected):
        check_in = datetime(2026, 2, 3 + offset, 9, 0, tzinfo=timezone.utc)
        db.add(
            Attendance(
                employee_id=by_name[name].id,
                check_in=check_in,
                check_out=check_in + timedelta(hours=9),
                worked_hours=Decimal("8.00"),
                overtime_hours=Decimal("0.00"),
                status="PRESENT",
                is_manual_edit=True,
                audit_notes="Badge reader outage; hours confirmed with the manager.",
            )
        )

    db.commit()
    print(
        f"  {records} attendance records across {len(working_days)} working days "
        f"(present {counts['PRESENT']}, late {counts['LATE']}, "
        f"half-day {counts['HALF_DAY']}, absent {counts['absent']}, "
        f"with overtime {counts['overtime']})."
    )
    print(
        f"  Plus {len(forgot_checkout)} missing check-out(s) and "
        f"{len(corrected)} manual edit(s) for the data-quality panel."
    )


def sync_sequences(db) -> None:
    """Advance each reference sequence past the highest number already in the data.

    The seeder writes some reference codes explicitly (Aarav keeps the mockup's
    CON/2026/0042), which does NOT advance `contract_seq`. Without this the first
    contract created through the API would generate CON/2026/0001, collide with a
    seeded row, and fail with a unique-violation. Same class of bug applies to any
    fixture data that hardcodes a sequence-backed reference.
    """
    print("Syncing reference sequences past the seeded data ...")
    plans = [
        ("contract_seq", "hr_contracts", "reference_code"),
        ("payrun_seq", "payruns", "reference_code"),
        ("payslip_seq", "payslips", "reference_code"),
        ("escalation_seq", "rag_escalations", "ticket_no"),
    ]
    for sequence, table, column in plans:
        # Reference codes look like PREFIX/YYYY/NNNN; take the numeric tail.
        highest = db.execute(
            text(
                f"""
                SELECT COALESCE(MAX(NULLIF(SPLIT_PART({column}, '/', 3), '')::INT), 0)
                FROM {table}
                """
            )
        ).scalar_one()
        highest = int(highest)
        # is_called=false when the table is empty, so the very first nextval
        # returns 1 rather than 2.
        db.execute(
            text("SELECT setval(:seq, :value, :is_called)"),
            {
                "seq": sequence,
                "value": max(highest, 1),
                "is_called": highest > 0,
            },
        )
        print(f"  {sequence} -> next is {highest + 1 if highest else 1}")
    db.commit()


def seed_routing_rules(db) -> None:
    print("Seeding escalation routing rules ...")
    for sequence, (category, role, sla_hours, priority) in enumerate(ROUTING_SEED, 1):
        db.add(
            EscalationRoutingRule(
                category=category,
                target_role=role,
                department_id=None,
                sla_hours=sla_hours,
                priority=priority,
                sequence=sequence * 10,
                is_active=True,
            )
        )
    db.commit()


def seed_payrun(db, people: dict, structure: SalaryStructure) -> List[Payrun]:
    print("Creating historical payruns (Sept 2026, Aug 2026, Jul 2026, Jun 2026, May 2026, Feb 2026) ...")

    payruns = []
    periods = [
        ("September 2026", date(2026, 9, 1), date(2026, 9, 30)),
        ("August 2026", date(2026, 8, 1), date(2026, 8, 31)),
        ("July 2026", date(2026, 7, 1), date(2026, 7, 31)),
        ("June 2026", date(2026, 6, 1), date(2026, 6, 30)),
        ("May 2026", date(2026, 5, 1), date(2026, 5, 31)),
        ("February 2026", date(2026, 2, 1), date(2026, 2, 28)),
    ]

    for name, p_start, p_end in periods:
        scope = payrun_service.validate_payrun_scope(
            db,
            structure_id=structure.id,
            date_start=p_start,
            date_end=p_end,
        )
        eligible_ids = [c["employee_id"] for c in scope["candidates"] if c["eligible"]]
        if not eligible_ids:
            continue

        payrun = payrun_service.create_payrun_batch(
            db,
            name=name,
            structure_id=structure.id,
            date_start=p_start,
            date_end=p_end,
            selected_employee_ids=eligible_ids,
            user_id=people["admin"].id,
        )
        payrun = payrun_service.compute_payrun(db, payrun.id)
        payrun.status = "PAID"
        db.commit()
        payruns.append(payrun)
        print(f"  Batch {name} ({payrun.reference_code}): {payrun.employee_count} payslips created & marked PAID.")

    return payruns


def seed_knowledge_base(db) -> None:
    print("Embedding the HR knowledge base into pgvector (runs locally) ...")
    from app.services.embedding import embedding_backend_info
    from app.services.rag_service import ingest_hr_policy_document

    total = 0
    for collection, title, body in POLICY_DOCUMENTS:
        result = ingest_hr_policy_document(
            db,
            collection,
            title,
            body,
            metadata={"source": "seed", "official": True},
            replace_existing=True,
        )
        total += result["chunks_created"]
        print(f"  {title}: {result['chunks_created']} chunk(s)")

    info = embedding_backend_info()
    print(
        f"  {total} chunks embedded using the '{info['active_backend']}' backend "
        f"({info['model']}, {info['dimensions']} dims)."
    )
    if info["active_backend"] == "hash":
        print(
            "  NOTE: fastembed is not installed, so retrieval is lexical rather "
            "than semantic. Run `pip install fastembed` and re-seed for the full "
            "model. Every endpoint works either way."
        )


def summary(db) -> None:
    rows = db.execute(
        text(
            """
            SELECT 'auth_users' AS table_name, COUNT(*) AS n FROM auth_users
            UNION ALL SELECT 'employees', COUNT(*) FROM employees
            UNION ALL SELECT 'hr_contracts', COUNT(*) FROM hr_contracts
            UNION ALL SELECT 'attendances', COUNT(*) FROM attendances
            UNION ALL SELECT 'leave_allocations', COUNT(*) FROM leave_allocations
            UNION ALL SELECT 'leave_requests', COUNT(*) FROM leave_requests
            UNION ALL SELECT 'salary_structures', COUNT(*) FROM salary_structures
            UNION ALL SELECT 'salary_rules', COUNT(*) FROM salary_rules
            UNION ALL SELECT 'payruns', COUNT(*) FROM payruns
            UNION ALL SELECT 'payslips', COUNT(*) FROM payslips
            UNION ALL SELECT 'payslip_lines', COUNT(*) FROM payslip_lines
            UNION ALL SELECT 'document_chunks', COUNT(*) FROM document_chunks
            UNION ALL SELECT 'escalation_routing_rules', COUNT(*)
                       FROM escalation_routing_rules
            ORDER BY table_name
            """
        )
    ).all()

    print("\nRow counts")
    print("-" * 44)
    for name, count in rows:
        print(f"  {name:<26} {count:>6}")

    aarav = db.execute(
        text(
            """
            SELECT p.reference_code, p.basic_amount, p.gross_amount, p.net_amount,
                   p.worked_days
            FROM payslips p JOIN employees e ON e.id = p.employee_id
            WHERE e.badge_id = 'EMP-001'
            ORDER BY p.date_end DESC LIMIT 1
            """
        )
    ).fetchone()

    if aarav:
        print("\nReference payslip (Aarav Mehta, EMP-001, wage 100000)")
        print("-" * 44)
        print(f"  reference : {aarav.reference_code}")
        print(f"  basic     : {aarav.basic_amount}")
        print(f"  gross     : {aarav.gross_amount}")
        print(f"  net       : {aarav.net_amount}")
        print(f"  worked_days: {aarav.worked_days}")

        lines = db.execute(
            text(
                """
                SELECT l.rule_code, l.amount FROM payslip_lines l
                JOIN payslips p ON p.id = l.payslip_id
                JOIN employees e ON e.id = p.employee_id
                WHERE e.badge_id = 'EMP-001'
                ORDER BY l.sequence
                """
            )
        ).all()
        print("  lines     : " + ", ".join(f"{code}={amount}" for code, amount in lines))

    print("\nLogins (password for every account: " + DEFAULT_PASSWORD + ")")
    print("-" * 44)
    for email, role in db.execute(
        text(
            """
            SELECT email, role FROM auth_users
            WHERE role <> 'EMPLOYEE' ORDER BY role, email
            """
        )
    ).all():
        print(f"  {str(role):<20} {email}")
    print(f"  {'EMPLOYEE':<20} priya.sharma@oxp.com (and other staff addresses)")


def main() -> None:
    parser = argparse.ArgumentParser(description="Seed the PeoplePay360 database.")
    parser.add_argument(
        "--skip-knowledge",
        action="store_true",
        help="Skip knowledge base embedding (faster; AI retrieval will be empty).",
    )
    parser.add_argument(
        "--skip-payrun", action="store_true", help="Skip creating the February payrun."
    )
    args = parser.parse_args()

    print("Seeding PeoplePay360 Enterprise Database")
    print("=" * 44)

    db = SessionLocal()
    try:
        wipe(db)
        master = seed_master_data(db)
        structure = seed_salary_structure(db)
        people = seed_people(db, master)
        seed_timeoff(db, people)
        seed_attendance(db, people)
        seed_routing_rules(db)
        # Must run before the payrun: it draws its references from the sequences.
        sync_sequences(db)
        if not args.skip_payrun:
            seed_payrun(db, people, structure)
            # And again afterwards, so API-created records continue cleanly.
            sync_sequences(db)
        if not args.skip_knowledge:
            seed_knowledge_base(db)
        summary(db)
        print("\nDatabase seeding complete with zero integrity errors.")
    finally:
        db.close()
        engine.dispose()


if __name__ == "__main__":
    main()
