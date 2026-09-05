"""AST-safe Python salary rule computation engine.

Odoo's most powerful payroll feature is dynamic Python evaluation for salary
rules. This module reproduces that flexibility without handing a remote-code
execution primitive to whoever can edit a salary rule.

Three independent layers of defence
-----------------------------------
1. **AST allowlist** - the parsed tree may only contain arithmetic, comparison
   and simple assignment nodes. `import`, `while`, `lambda`, comprehensions,
   `with`, `try` and every other construct is rejected before compilation.
2. **Attribute and call gating** - attribute access to any dunder / private name
   is refused (this is what blocks the classic
   ``().__class__.__bases__[0].__subclasses__()`` sandbox escape), and calls are
   restricted to a fixed set of numeric helpers.
3. **Empty builtins + proxied context** - execution gets `__builtins__ = {}` and
   only read-only field proxies, never live ORM objects.

Financial integrity: every amount is `Decimal`, quantised to 2 places with
ROUND_HALF_UP. Numeric literals in rule source are rewritten to `Decimal` so
``result = contract.wage * 0.50`` cannot silently become a float.
"""

from __future__ import annotations

import ast
from decimal import Decimal, InvalidOperation, ROUND_HALF_UP
from typing import Any, Dict, Iterable, List, Mapping

from app.core.errors import RuleExecutionError

TWO_PLACES = Decimal("0.01")
ZERO = Decimal("0.00")
MAX_RULE_SOURCE_LENGTH = 4000

# ---------------------------------------------------------------------------
# LAYER 1: node allowlist
# ---------------------------------------------------------------------------
ALLOWED_NODES: set[type[ast.AST]] = {
    ast.Module,
    ast.Expr,
    ast.Assign,
    ast.AugAssign,
    ast.Name,
    ast.Store,
    ast.Load,
    ast.Constant,
    ast.BinOp,
    ast.UnaryOp,
    ast.BoolOp,
    ast.Compare,
    ast.If,
    ast.IfExp,
    ast.Pass,
    # arithmetic
    ast.Add,
    ast.Sub,
    ast.Mult,
    ast.Div,
    ast.FloorDiv,
    ast.Mod,
    ast.Pow,
    ast.USub,
    ast.UAdd,
    # logic / comparison
    ast.And,
    ast.Or,
    ast.Not,
    ast.Eq,
    ast.NotEq,
    ast.Lt,
    ast.LtE,
    ast.Gt,
    ast.GtE,
    ast.In,
    ast.NotIn,
    # containers and lookups
    ast.Subscript,
    ast.Slice,
    ast.Tuple,
    ast.Dict,
    ast.List,
    # gated separately in SecurityVisitor
    ast.Attribute,
    ast.Call,
    ast.keyword,
}

# ast.Index was removed in Python 3.9+ but keep it if the runtime still has it.
if hasattr(ast, "Index"):  # pragma: no cover - version dependent
    ALLOWED_NODES.add(ast.Index)

# LAYER 2: only these callables are reachable from rule source.
SAFE_CALLABLE_NAMES = frozenset({"min", "max", "abs", "round", "Decimal"})


class SecurityVisitor(ast.NodeVisitor):
    """Rejects anything outside the allowlist, with precise error messages."""

    def generic_visit(self, node: ast.AST) -> None:
        if type(node) not in ALLOWED_NODES:
            raise RuleExecutionError(
                f"Disallowed Python construct in salary rule: {type(node).__name__}"
            )
        super().generic_visit(node)

    def visit_Attribute(self, node: ast.Attribute) -> None:
        # Blocks __class__, __globals__, __subclasses__, _private, ...
        if node.attr.startswith("_"):
            raise RuleExecutionError(
                f"Disallowed attribute access in salary rule: '{node.attr}'"
            )
        self.generic_visit(node)

    def visit_Call(self, node: ast.Call) -> None:
        if not isinstance(node.func, ast.Name):
            raise RuleExecutionError(
                "Salary rules may only call the built-in numeric helpers "
                f"{sorted(SAFE_CALLABLE_NAMES)} directly."
            )
        if node.func.id not in SAFE_CALLABLE_NAMES:
            raise RuleExecutionError(
                f"Disallowed function call in salary rule: '{node.func.id}'. "
                f"Allowed: {sorted(SAFE_CALLABLE_NAMES)}"
            )
        self.generic_visit(node)

    def visit_Name(self, node: ast.Name) -> None:
        if node.id.startswith("_"):
            raise RuleExecutionError(
                f"Disallowed identifier in salary rule: '{node.id}'"
            )
        self.generic_visit(node)


class _DecimalizeLiterals(ast.NodeTransformer):
    """Rewrite numeric literals as Decimal so no float ever enters the maths.

    Runs AFTER SecurityVisitor, so the `_to_decimal` call nodes it inserts are
    never themselves subject to the call allowlist.
    """

    def visit_Constant(self, node: ast.Constant) -> ast.AST:
        if isinstance(node.value, bool) or not isinstance(node.value, (int, float)):
            return node
        return ast.copy_location(
            ast.Call(
                func=ast.Name(id="_to_decimal", ctx=ast.Load()),
                args=[ast.Constant(value=repr(node.value))],
                keywords=[],
            ),
            node,
        )


# ---------------------------------------------------------------------------
# LAYER 3: read-only field proxies instead of live ORM objects
# ---------------------------------------------------------------------------
class ReadOnlyProxy(Mapping):
    """Exposes a fixed, explicit set of fields. No relationship traversal."""

    __slots__ = ("_fields", "_label")

    def __init__(self, label: str, fields: Dict[str, Any]) -> None:
        object.__setattr__(self, "_fields", dict(fields))
        object.__setattr__(self, "_label", label)

    def __getattr__(self, item: str) -> Any:
        # object.__getattribute__ avoids infinite recursion if _fields is missing.
        fields = object.__getattribute__(self, "_fields")
        try:
            return fields[item]
        except KeyError:
            raise RuleExecutionError(
                f"'{self._label}' has no field '{item}' available to salary rules. "
                f"Available: {sorted(self._fields)}"
            ) from None

    def __setattr__(self, key: str, value: Any) -> None:
        raise RuleExecutionError("Salary rules may not mutate the context.")

    def __getitem__(self, key: str) -> Any:
        return self.__getattr__(key)

    def __iter__(self) -> Iterable[str]:
        return iter(self._fields)

    def __len__(self) -> int:
        return len(self._fields)


def to_decimal(value: Any) -> Decimal:
    """Coerce anything numeric to Decimal without ever routing through float."""
    if isinstance(value, Decimal):
        return value
    if value is None:
        return ZERO
    try:
        return Decimal(str(value))
    except (InvalidOperation, ValueError):
        raise RuleExecutionError(f"Value '{value!r}' is not a valid decimal amount.")


def money(value: Any) -> Decimal:
    """Quantise to 2 decimal places with ROUND_HALF_UP (accounting convention)."""
    return to_decimal(value).quantize(TWO_PLACES, rounding=ROUND_HALF_UP)


def _safe_round(value: Any, ndigits: int = 2) -> Decimal:
    exp = Decimal(1).scaleb(-int(ndigits))
    return to_decimal(value).quantize(exp, rounding=ROUND_HALF_UP)


def build_contract_proxy(contract: Any) -> ReadOnlyProxy:
    """Only payroll-relevant contract fields. Never banking or personal data."""
    wage = to_decimal(getattr(contract, "wage_monthly", 0))
    return ReadOnlyProxy(
        "contract",
        {
            "wage": wage,          # Odoo-compatible alias
            "wage_monthly": wage,
            "reference_code": getattr(contract, "reference_code", None),
            "start_date": getattr(contract, "start_date", None),
            "end_date": getattr(contract, "end_date", None),
            "status": getattr(contract, "status", None),
        },
    )


def safe_execute_python_rule(code_str: str, context: Dict[str, Any]) -> Decimal:
    """Parse, verify and execute a rule formula in a strictly sandboxed namespace."""
    if not code_str or not code_str.strip():
        raise RuleExecutionError("Salary rule python_code is empty.")
    if len(code_str) > MAX_RULE_SOURCE_LENGTH:
        raise RuleExecutionError(
            f"Salary rule source exceeds {MAX_RULE_SOURCE_LENGTH} characters."
        )

    try:
        tree = ast.parse(code_str, mode="exec")
    except SyntaxError as exc:
        raise RuleExecutionError(f"Salary rule has a syntax error: {exc.msg}") from exc

    SecurityVisitor().visit(tree)                     # layers 1 + 2
    tree = _DecimalizeLiterals().visit(tree)          # financial integrity
    ast.fix_missing_locations(tree)

    local_env: Dict[str, Any] = {
        "contract": context["contract"],
        "employee": context.get("employee"),
        "worked_days": to_decimal(context.get("worked_days", 0)),
        "expected_days": to_decimal(context.get("expected_days", 0)),
        "worked_hours": to_decimal(context.get("worked_hours", 0)),
        "overtime_hours": to_decimal(context.get("overtime_hours", 0)),
        "leave_days": to_decimal(context.get("leave_days", 0)),
        "paid_leave_days": to_decimal(context.get("paid_leave_days", 0)),
        "unpaid_leave_days": to_decimal(context.get("unpaid_leave_days", 0)),
        "categories": dict(context.get("categories", {})),
        "rules": dict(context.get("rules", {})),
        "result": ZERO,
        # helpers (layer 2 allowlist)
        "min": min,
        "max": max,
        "abs": abs,
        "round": _safe_round,
        "Decimal": to_decimal,
        "_to_decimal": to_decimal,
    }

    try:
        exec(  # noqa: S102 - executing verified, allowlisted AST by design
            compile(tree, filename="<salary_rule>", mode="exec"),
            {"__builtins__": {}},
            local_env,
        )
    except RuleExecutionError:
        raise
    except ZeroDivisionError:
        raise RuleExecutionError("Salary rule attempted a division by zero.")
    except Exception as exc:  # noqa: BLE001 - surfaced to the payroll operator
        raise RuleExecutionError(
            f"Salary rule failed during evaluation: {type(exc).__name__}: {exc}"
        ) from exc

    return money(local_env.get("result", ZERO))


def validate_python_rule(code_str: str) -> None:
    """Dry-run a rule against a synthetic contract. Used on rule create/update."""
    probe_contract = ReadOnlyProxy(
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
    safe_execute_python_rule(
        code_str,
        {
            "contract": probe_contract,
            "worked_days": Decimal("22"),
            "expected_days": Decimal("22"),
            "worked_hours": Decimal("176"),
            "overtime_hours": Decimal("0"),
            "leave_days": Decimal("0"),
            "paid_leave_days": Decimal("0"),
            "unpaid_leave_days": Decimal("0"),
            "categories": {c: ZERO for c in ("BASIC", "ALLOWANCE", "GROSS", "DEDUCTION", "NET")},
            "rules": {},
        },
    )


# ---------------------------------------------------------------------------
# THE ORCHESTRATOR
# ---------------------------------------------------------------------------
def _percentage_base_amount(
    rule: Any, contract_wage: Decimal, categories: Dict[str, Decimal]
) -> Decimal:
    base_key = (rule.percentage_base or "").upper()
    if base_key == "WAGE":
        return contract_wage
    if base_key in categories:
        return categories[base_key]
    raise RuleExecutionError(
        f"Rule '{rule.code}' has an unknown percentage_base '{rule.percentage_base}'. "
        "Expected one of WAGE, BASIC, GROSS."
    )


def execute_salary_computation(
    contract: Any,
    worked_days_count: Any,
    ordered_rules: List[Any],
    *,
    attendance: Dict[str, Any] | None = None,
    employee: Any | None = None,
) -> Dict[str, Any]:
    """Execute salary rules in `sequence` order and build the category totals.

    Returns basic / gross / net / deductions plus one line per rule, in the exact
    shape `payrun_service` persists into `payslip_lines`.
    """
    attendance = attendance or {}
    contract_proxy = build_contract_proxy(contract)
    contract_wage = contract_proxy.wage

    employee_proxy = ReadOnlyProxy(
        "employee",
        {
            "badge_id": getattr(employee, "badge_id", None),
            "name": getattr(employee, "name", None),
            "work_location": getattr(employee, "work_location", None),
            "status": getattr(employee, "status", None),
            "date_of_joining": getattr(employee, "date_of_joining", None),
        },
    )

    categories: Dict[str, Decimal] = {
        "BASIC": ZERO,
        "ALLOWANCE": ZERO,
        "GROSS": ZERO,
        "DEDUCTION": ZERO,
        "NET": ZERO,
    }
    rule_values: Dict[str, Decimal] = {}
    lines: List[Dict[str, Any]] = []
    suppressed: List[str] = []
    net_rule_seen = False

    seen_codes: set[str] = set()
    for rule in ordered_rules:
        if rule.code in seen_codes:
            raise RuleExecutionError(
                f"Duplicate salary rule code '{rule.code}' in this structure."
            )
        seen_codes.add(rule.code)

        if rule.computation_type == "FIXED":
            amount = money(rule.fixed_amount)

        elif rule.computation_type == "PERCENTAGE":
            base = _percentage_base_amount(rule, contract_wage, categories)
            amount = money(
                (base * to_decimal(rule.percentage_rate)) / Decimal("100")
            )

        elif rule.computation_type == "PYTHON_CODE":
            amount = safe_execute_python_rule(
                rule.python_code,
                {
                    "contract": contract_proxy,
                    "employee": employee_proxy,
                    "worked_days": worked_days_count,
                    "expected_days": attendance.get("expected_days", 0),
                    "worked_hours": attendance.get("total_worked_hours", 0),
                    "overtime_hours": attendance.get("total_overtime_hours", 0),
                    "leave_days": attendance.get("leave_days", 0),
                    "paid_leave_days": attendance.get("paid_leave_days", 0),
                    "unpaid_leave_days": attendance.get("unpaid_leave_days", 0),
                    "categories": dict(categories),
                    "rules": dict(rule_values),
                },
            )
        else:
            raise RuleExecutionError(
                f"Rule '{rule.code}' has an unsupported computation_type "
                f"'{rule.computation_type}'."
            )

        # Odoo's rule "Quantity": a multiplier on the computed amount, so one rule
        # can express "3 days of leave encashment" without a bespoke formula.
        quantity = to_decimal(getattr(rule, "quantity", 1) or 0)
        if quantity != Decimal("1"):
            amount = money(amount * quantity)

        rule_values[rule.code] = amount

        # --- Accumulate category totals ------------------------------------
        if rule.category == "BASIC":
            categories["BASIC"] += amount
            categories["GROSS"] += amount
        elif rule.category == "ALLOWANCE":
            categories["ALLOWANCE"] += amount
            categories["GROSS"] += amount
        elif rule.category == "DEDUCTION":
            # Deductions are stored as positive magnitudes in `categories` and
            # rendered as negatives on the payslip line.
            categories["DEDUCTION"] += abs(amount)
        elif rule.category == "NET":
            categories["NET"] = amount
            net_rule_seen = True
        # category GROSS rules are subtotal display rows: they must NOT be added
        # again or the gross would be double counted.

        display_amount = -abs(amount) if rule.category == "DEDUCTION" else amount

        # ZERO SUPPRESSION.
        # A structure carries every rule the company might apply, but a payslip
        # should only list the ones that actually moved money. A Performance Bonus
        # of 0.00 or an ESIC contribution the employee is not eligible for is noise
        # on a document people read. Subtotal rows (GROSS, NET) always render even
        # at zero, because a payslip with no Net line is unreadable.
        #
        # The amount still lands in `rule_values`, so a later formula can reference
        # a suppressed rule by code.
        always_shown = rule.category in ("GROSS", "NET")
        if amount == ZERO and not always_shown:
            suppressed.append(rule.code)
            continue

        lines.append(
            {
                "salary_rule_id": rule.id,
                "rule_name": rule.name,
                "rule_code": rule.code,
                "category": rule.category,
                "sequence": rule.sequence,
                "amount": money(display_amount),
            }
        )

    # If NET was not an explicit rule, derive it: GROSS - DEDUCTION
    if not net_rule_seen:
        categories["NET"] = categories["GROSS"] - categories["DEDUCTION"]

    return {
        "basic": money(categories["BASIC"]),
        "allowances": money(categories["ALLOWANCE"]),
        "gross": money(categories["GROSS"]),
        "deductions": money(categories["DEDUCTION"]),
        "net": money(categories["NET"]),
        "rule_values": rule_values,
        "lines": lines,
        # Which configured rules produced no line, so the UI can explain the gap
        # between "12 rules in this structure" and "7 lines on this payslip".
        "suppressed_zero_rules": suppressed,
    }
