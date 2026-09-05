"""Gap-free-ish reference code generation (CON/YYYY/0001, PAY/YYYY/0001, ...).

PostgreSQL sequences are used rather than `MAX(id)+1`: sequences are concurrency
safe and never hand the same number to two simultaneous payroll operators.
"""

from __future__ import annotations

from datetime import date

from sqlalchemy import text
from sqlalchemy.orm import Session

CONTRACT_SEQ = "contract_seq"
PAYRUN_SEQ = "payrun_seq"
PAYSLIP_SEQ = "payslip_seq"
ESCALATION_SEQ = "escalation_seq"


MAX_REFERENCE_ATTEMPTS = 50

# Which table and column each sequence's references live in, so a generated code
# can be checked for collisions before it is handed out.
_REFERENCE_TARGETS = {
    CONTRACT_SEQ: ("hr_contracts", "reference_code"),
    PAYRUN_SEQ: ("payruns", "reference_code"),
    PAYSLIP_SEQ: ("payslips", "reference_code"),
    ESCALATION_SEQ: ("rag_escalations", "ticket_no"),
}


def next_sequence_value(db: Session, sequence_name: str) -> int:
    return int(db.execute(text(f"SELECT nextval('{sequence_name}')")).scalar_one())


def make_reference(db: Session, prefix: str, sequence_name: str, year: int) -> str:
    """Draw the next reference, skipping any value already taken.

    A sequence alone is not enough. Fixture data and migrations sometimes write
    reference codes explicitly, which does not advance the sequence, so the next
    generated value can collide with a row that already exists. Rather than
    surfacing a unique-violation to the user, roll forward to the first free number.
    """
    table, column = _REFERENCE_TARGETS.get(sequence_name, (None, None))

    for _ in range(MAX_REFERENCE_ATTEMPTS):
        candidate = f"{prefix}/{year}/{next_sequence_value(db, sequence_name):04d}"
        if table is None:
            return candidate
        taken = db.execute(
            text(f"SELECT 1 FROM {table} WHERE {column} = :code LIMIT 1"),
            {"code": candidate},
        ).first()
        if not taken:
            return candidate

    raise RuntimeError(
        f"Could not allocate a free {prefix} reference after "
        f"{MAX_REFERENCE_ATTEMPTS} attempts; {sequence_name} is badly out of sync."
    )


def next_contract_reference(db: Session, on: date | None = None) -> str:
    return make_reference(db, "CON", CONTRACT_SEQ, (on or date.today()).year)


def next_payrun_reference(db: Session, on: date | None = None) -> str:
    return make_reference(db, "PAY", PAYRUN_SEQ, (on or date.today()).year)


def next_payslip_reference(db: Session, on: date | None = None) -> str:
    return make_reference(db, "SLIP", PAYSLIP_SEQ, (on or date.today()).year)


def next_escalation_reference(db: Session, on: date | None = None) -> str:
    return make_reference(db, "ESC", ESCALATION_SEQ, (on or date.today()).year)
