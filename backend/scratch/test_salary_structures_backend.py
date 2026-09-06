import uuid
import sys
import os

# Add backend directory to sys.path
sys.path.insert(0, r"d:\Downloads\OdooPb_02\PeoplePay360\backend")

from app.core.database import SessionLocal
from app.models.salary import SalaryStructure, SalaryRule
from app.services.salary_engine import execute_salary_computation, validate_python_rule
from app.schemas.payroll import SalaryRuleCreate, SalaryRuleUpdate, ComputationType, RuleCategory
from decimal import Decimal

def test_salary_structure_flow():
    db = SessionLocal()
    try:
        print("[TEST] 1. Creating test salary structure...")
        uid = uuid.uuid4().hex[:6].upper()
        struct = SalaryStructure(
            name=f"Test ERP Structure {uid}",
            code=f"TEST_{uid}",
            notes="Structure created for automated backend testing",
            is_active=True
        )
        db.add(struct)
        db.flush()

        print(f"[TEST] Created Structure ID: {struct.id}")

        # 2. Add Rules
        r1 = SalaryRule(
            salary_structure_id=struct.id,
            name="Basic Salary",
            code="BASIC",
            sequence=10,
            category="BASIC",
            computation_type="PERCENTAGE",
            percentage_base="WAGE",
            percentage_rate=Decimal("50.00"),
            is_active=True
        )
        r2 = SalaryRule(
            salary_structure_id=struct.id,
            name="House Rent Allowance",
            code="HRA",
            sequence=20,
            category="ALLOWANCE",
            computation_type="PERCENTAGE",
            percentage_base="BASIC",
            percentage_rate=Decimal("40.00"),
            is_active=True
        )
        r3 = SalaryRule(
            salary_structure_id=struct.id,
            name="Provident Fund",
            code="PF",
            sequence=30,
            category="DEDUCTION",
            computation_type="PERCENTAGE",
            percentage_base="BASIC",
            percentage_rate=Decimal("12.00"),
            is_active=True
        )
        db.add_all([r1, r2, r3])
        db.commit()

        # 3. Verify rules in structure
        rules = db.query(SalaryRule).filter_by(salary_structure_id=struct.id).order_by(SalaryRule.sequence).all()
        assert len(rules) == 3, f"Expected 3 rules, got {len(rules)}"
        print(f"[TEST] 3 rules verified in structure: {[r.code for r in rules]}")

        # 4. Test Python Rule Validation
        py_code = "result = categories['BASIC'] + categories['ALLOWANCE']"
        validate_python_rule(py_code)
        print("[TEST] Python rule AST validation passed successfully.")

        # 5. Run Salary Computation Engine Simulation
        class FakeContract:
            wage_monthly = Decimal("100000.00")
            reference_code = "CON/TEST/001"
            start_date = None
            end_date = None
            status = "RUNNING"

        res = execute_salary_computation(
            FakeContract(),
            Decimal("22"),
            rules,
            attendance={"expected_days": Decimal("22")}
        )

        print(f"[TEST] Engine Simulation Results:")
        print(f"       Basic:      {res['basic']}")
        print(f"       Allowances: {res['allowances']}")
        print(f"       Gross:      {res['gross']}")
        print(f"       Deductions: {res['deductions']}")
        print(f"       Net:        {res['net']}")

        assert res['basic'] == Decimal("50000.00"), f"Expected Basic 50000, got {res['basic']}"
        assert res['allowances'] == Decimal("20000.00"), f"Expected HRA 20000, got {res['allowances']}"
        assert res['gross'] == Decimal("70000.00"), f"Expected Gross 70000, got {res['gross']}"
        assert res['deductions'] == Decimal("6000.00"), f"Expected PF 6000, got {res['deductions']}"
        assert res['net'] == Decimal("64000.00"), f"Expected Net 64000, got {res['net']}"

        # Clean up test structure
        db.query(SalaryRule).filter_by(salary_structure_id=struct.id).delete()
        db.query(SalaryStructure).filter_by(id=struct.id).delete()
        db.commit()

        print("==================================================")
        print("ALL BACKEND SALARY STRUCTURE TESTS PASSED SUCCESSFULLY!")
        print("==================================================")

    except Exception as e:
        db.rollback()
        print(f"[ERROR] Test failed: {e}")
        raise e
    finally:
        db.close()

if __name__ == "__main__":
    test_salary_structure_flow()
