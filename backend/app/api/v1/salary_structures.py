"""Salary structures, salary rules and the rule simulator."""

from __future__ import annotations

import uuid
from decimal import Decimal
from types import SimpleNamespace
from typing import List

from fastapi import APIRouter, Depends
from sqlalchemy import func, select
from sqlalchemy.orm import selectinload

from app.api.deps import DbSession
from app.core.errors import ConflictError, NotFoundError, RuleExecutionError
from app.core.security import CurrentUser, require_payroll, require_payroll_manager
from app.models.payrun import Payrun
from app.models.salary import SalaryRule, SalaryStructure
from app.schemas.common import MessageResponse
from app.schemas.payroll import (
    PythonRuleValidationRequest,
    PythonRuleValidationResponse,
    RuleSimulationLine,
    RuleSimulationRequest,
    RuleSimulationResponse,
    SalaryRuleCreate,
    SalaryRuleOut,
    SalaryRuleUpdate,
    SalaryStructureCreate,
    SalaryStructureOut,
    SalaryStructureUpdate,
)
from app.services.salary_engine import (
    execute_salary_computation,
    safe_execute_python_rule,
    validate_python_rule,
)

router = APIRouter(prefix="/salary-structures", tags=["Salary Structures & Rules"])


def _load(db, structure_id: uuid.UUID) -> SalaryStructure:
    structure = db.execute(
        select(SalaryStructure)
        .options(selectinload(SalaryStructure.rules))
        .where(SalaryStructure.id == structure_id)
    ).scalars().first()
    if not structure:
        raise NotFoundError(f"Salary structure {structure_id} not found.")
    return structure


@router.get(
    "",
    response_model=List[SalaryStructureOut],
    summary="List salary structures with rule counts and employees covered",
)
def list_structures(
    db: DbSession, _: CurrentUser = Depends(require_payroll)
) -> List[SalaryStructureOut]:
    structures = (
        db.execute(
            select(SalaryStructure)
            .options(selectinload(SalaryStructure.rules))
            .order_by(SalaryStructure.name)
        )
        .scalars()
        .all()
    )

    # The mockup's list shows "12 rules | 42 employees". Employees covered is
    # counted from contracts naming the structure, falling back to payslips already
    # produced under it, so a structure in active use never reads as zero.
    from app.models.contract import HrContract
    from app.models.payrun import Payslip

    by_contract = dict(
        db.execute(
            select(
                HrContract.salary_structure_id,
                func.count(func.distinct(HrContract.employee_id)),
            )
            .where(HrContract.salary_structure_id.is_not(None))
            .group_by(HrContract.salary_structure_id)
        ).all()
    )
    by_payslip = dict(
        db.execute(
            select(
                Payslip.salary_structure_id,
                func.count(func.distinct(Payslip.employee_id)),
            ).group_by(Payslip.salary_structure_id)
        ).all()
    )

    result: List[SalaryStructureOut] = []
    for structure in structures:
        out = SalaryStructureOut.model_validate(structure)
        out.rule_count = len(structure.rules)
        out.active_rule_count = sum(1 for r in structure.rules if r.is_active)
        out.employee_count = max(
            by_contract.get(structure.id, 0), by_payslip.get(structure.id, 0)
        )
        result.append(out)
    return result


@router.post(
    "",
    response_model=SalaryStructureOut,
    status_code=201,
    summary="Create a salary structure and its rules in one call",
)
def create_structure(
    payload: SalaryStructureCreate,
    db: DbSession,
    _: CurrentUser = Depends(require_payroll_manager),
) -> SalaryStructureOut:
    codes = [r.code for r in payload.rules]
    if len(codes) != len(set(codes)):
        raise ConflictError("Duplicate rule codes in this structure.")

    # Validate every Python rule BEFORE persisting: a structure that cannot
    # compute is worse than no structure at all.
    for rule in payload.rules:
        if rule.computation_type.value == "PYTHON_CODE":
            validate_python_rule(rule.python_code)

    structure = SalaryStructure(
        name=payload.name, code=payload.code, notes=payload.notes
    )
    db.add(structure)
    db.flush()

    for rule in payload.rules:
        db.add(
            SalaryRule(
                salary_structure_id=structure.id,
                name=rule.name,
                code=rule.code,
                sequence=rule.sequence,
                category=rule.category.value,
                computation_type=rule.computation_type.value,
                fixed_amount=rule.fixed_amount,
                percentage_base=rule.percentage_base,
                percentage_rate=rule.percentage_rate,
                python_code=rule.python_code,
                quantity=rule.quantity,
                is_active=rule.is_active,
            )
        )

    db.commit()
    return SalaryStructureOut.model_validate(_load(db, structure.id))


@router.get(
    "/{structure_id}",
    response_model=SalaryStructureOut,
    summary="Salary structure detail",
)
def get_structure(
    structure_id: uuid.UUID, db: DbSession, _: CurrentUser = Depends(require_payroll)
) -> SalaryStructureOut:
    return SalaryStructureOut.model_validate(_load(db, structure_id))


@router.patch(
    "/{structure_id}",
    response_model=SalaryStructureOut,
    summary="Rename a structure or deactivate it",
)
def update_structure(
    structure_id: uuid.UUID,
    payload: SalaryStructureUpdate,
    db: DbSession,
    _: CurrentUser = Depends(require_payroll_manager),
) -> SalaryStructureOut:
    structure = _load(db, structure_id)
    updates = payload.model_dump(exclude_unset=True)

    # Deactivating a structure that a live payrun still depends on would make that
    # run uncomputable, so block it while one is open.
    if updates.get("is_active") is False:
        open_runs = db.execute(
            select(Payrun.reference_code).where(
                Payrun.salary_structure_id == structure.id,
                Payrun.status.in_(["DRAFT", "COMPUTED"]),
            )
        ).scalars().all()
        if open_runs:
            raise ConflictError(
                "This structure is used by payrun(s) that are not finalised yet: "
                f"{', '.join(open_runs)}. Finalise or delete them first.",
            )

    for field, value in updates.items():
        setattr(structure, field, value)

    db.commit()
    return SalaryStructureOut.model_validate(_load(db, structure_id))


@router.delete(
    "/{structure_id}",
    response_model=MessageResponse,
    summary="Delete a structure, or deactivate it when payroll history references it",
)
def delete_structure(
    structure_id: uuid.UUID,
    db: DbSession,
    _: CurrentUser = Depends(require_payroll_manager),
) -> MessageResponse:
    structure = _load(db, structure_id)

    runs = db.execute(
        select(func.count(Payrun.id)).where(Payrun.salary_structure_id == structure.id)
    ).scalar_one()
    if runs:
        structure.is_active = False
        db.commit()
        return MessageResponse(
            detail=(
                f"'{structure.name}' is referenced by {runs} payrun(s), so it was "
                "deactivated instead of deleted. Payroll history stays intact."
            )
        )

    db.delete(structure)
    db.commit()
    return MessageResponse(detail=f"Salary structure '{structure.name}' deleted.")


@router.post(
    "/{structure_id}/rules",
    response_model=SalaryRuleOut,
    status_code=201,
    summary="Add a rule to a structure",
)
def add_rule(
    structure_id: uuid.UUID,
    payload: SalaryRuleCreate,
    db: DbSession,
    _: CurrentUser = Depends(require_payroll_manager),
) -> SalaryRuleOut:
    structure = _load(db, structure_id)
    if any(r.code == payload.code for r in structure.rules):
        raise ConflictError(f"Rule code '{payload.code}' already exists in this structure.")

    if payload.computation_type.value == "PYTHON_CODE":
        validate_python_rule(payload.python_code)

    rule = SalaryRule(
        salary_structure_id=structure_id,
        name=payload.name,
        code=payload.code,
        sequence=payload.sequence,
        category=payload.category.value,
        computation_type=payload.computation_type.value,
        fixed_amount=payload.fixed_amount,
        percentage_base=payload.percentage_base,
        percentage_rate=payload.percentage_rate,
        python_code=payload.python_code,
        quantity=payload.quantity,
        is_active=payload.is_active,
    )
    db.add(rule)
    db.commit()
    db.refresh(rule)
    return SalaryRuleOut.model_validate(rule)


@router.patch(
    "/rules/{rule_id}",
    response_model=SalaryRuleOut,
    summary="Update a salary rule",
)
def update_rule(
    rule_id: uuid.UUID,
    payload: SalaryRuleUpdate,
    db: DbSession,
    _: CurrentUser = Depends(require_payroll_manager),
) -> SalaryRuleOut:
    rule = db.get(SalaryRule, rule_id)
    if not rule:
        raise NotFoundError(f"Salary rule {rule_id} not found.")

    updates = payload.model_dump(exclude_unset=True)
    if "code" in updates and updates["code"] != rule.code:
        structure = db.get(SalaryStructure, rule.salary_structure_id)
        if structure and any(r.code == updates["code"] and r.id != rule.id for r in structure.rules):
            raise ConflictError(f"Rule code '{updates['code']}' already exists in this structure.")

    for field, value in updates.items():
        setattr(rule, field, value.value if hasattr(value, "value") else value)

    if rule.computation_type == "FIXED" and rule.fixed_amount is None:
        raise ConflictError("fixed_amount is required for FIXED rules.")
    elif rule.computation_type == "PERCENTAGE" and (rule.percentage_base is None or rule.percentage_rate is None):
        raise ConflictError("percentage_base and percentage_rate are required for PERCENTAGE rules.")
    elif rule.computation_type == "PYTHON_CODE":
        if not (rule.python_code or "").strip():
            raise ConflictError("python_code is required for PYTHON_CODE rules.")
        validate_python_rule(rule.python_code)

    db.commit()
    db.refresh(rule)
    return SalaryRuleOut.model_validate(rule)


@router.delete(
    "/rules/{rule_id}",
    response_model=MessageResponse,
    summary="Delete a rule, or deactivate it when payslips already reference it",
)
def delete_rule(
    rule_id: uuid.UUID,
    db: DbSession,
    _: CurrentUser = Depends(require_payroll_manager),
) -> MessageResponse:
    rule = db.get(SalaryRule, rule_id)
    if not rule:
        raise NotFoundError(f"Salary rule {rule_id} not found.")

    # payslip_lines references salary_rules with ON DELETE RESTRICT, so a rule
    # that has already paid someone is deactivated rather than destroyed.
    from sqlalchemy import func
    from app.models.payrun import PayslipLine

    used = db.execute(
        select(func.count(PayslipLine.id)).where(PayslipLine.salary_rule_id == rule.id)
    ).scalar_one()

    if used:
        rule.is_active = False
        db.commit()
        return MessageResponse(
            detail=(
                f"Rule '{rule.code}' is referenced by {used} payslip line(s), so it "
                "was deactivated instead of deleted. Payroll history stays intact."
            )
        )

    db.delete(rule)
    db.commit()
    return MessageResponse(detail=f"Rule '{rule.code}' deleted.")


@router.post(
    "/validate-python-rule",
    response_model=PythonRuleValidationResponse,
    summary="Verify a Python formula against the AST sandbox before saving it",
)
def validate_rule_code(
    payload: PythonRuleValidationRequest,
    _: CurrentUser = Depends(require_payroll_manager),
) -> PythonRuleValidationResponse:
    try:
        from app.services.salary_engine import ReadOnlyProxy, ZERO

        probe = ReadOnlyProxy(
            "contract",
            {
                "wage": Decimal("100000.00"),
                "wage_monthly": Decimal("100000.00"),
                "reference_code": "CON/PROBE/0001",
                "start_date": None,
                "end_date": None,
                "status": "RUNNING",
            },
        )
        result = safe_execute_python_rule(
            payload.python_code,
            {
                "contract": probe,
                "worked_days": Decimal("22"),
                "expected_days": Decimal("22"),
                "categories": {
                    c: ZERO
                    for c in ("BASIC", "ALLOWANCE", "GROSS", "DEDUCTION", "NET")
                },
                "rules": {},
            },
        )
        return PythonRuleValidationResponse(
            valid=True,
            message=(
                "Rule is safe and evaluated successfully against a probe contract "
                "with a wage of 100000.00."
            ),
            probe_result=result,
        )
    except RuleExecutionError as exc:
        return PythonRuleValidationResponse(valid=False, message=exc.message)


@router.post(
    "/simulate",
    response_model=RuleSimulationResponse,
    summary="Dry-run a whole structure against a hypothetical wage",
)
def simulate(
    payload: RuleSimulationRequest,
    db: DbSession,
    _: CurrentUser = Depends(require_payroll),
) -> RuleSimulationResponse:
    structure = _load(db, payload.salary_structure_id)
    rules = [r for r in sorted(structure.rules, key=lambda r: r.sequence) if r.is_active]
    if not rules:
        raise NotFoundError("This structure has no active rules to simulate.")

    # A lightweight stand-in for a contract: the engine only reads wage fields.
    fake_contract = SimpleNamespace(
        wage_monthly=payload.wage_monthly,
        reference_code="CON/SIMULATION/0000",
        start_date=None,
        end_date=None,
        status="RUNNING",
    )
    result = execute_salary_computation(
        fake_contract,
        payload.worked_days,
        rules,
        attendance={"expected_days": payload.expected_days},
    )

    by_code = {r.code: r for r in rules}

    def explain(rule: SalaryRule) -> str:
        if rule.computation_type == "PERCENTAGE":
            return f"{rule.percentage_rate}% of {rule.percentage_base}"
        if rule.computation_type == "FIXED":
            return f"fixed {rule.fixed_amount}"
        return f"python: {(rule.python_code or '').strip()[:120]}"

    return RuleSimulationResponse(
        salary_structure_id=structure.id,
        salary_structure_name=structure.name,
        wage_monthly=payload.wage_monthly,
        basic=result["basic"],
        allowances=result["allowances"],
        gross=result["gross"],
        deductions=result["deductions"],
        net=result["net"],
        lines=[
            RuleSimulationLine(
                rule_name=line["rule_name"],
                rule_code=line["rule_code"],
                category=line["category"],
                sequence=line["sequence"],
                amount=line["amount"],
                computation_type=by_code[line["rule_code"]].computation_type,
                explanation=explain(by_code[line["rule_code"]]),
            )
            for line in result["lines"]
        ],
    )
