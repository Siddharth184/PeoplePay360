"""Calibrate RAG_CONFIDENCE_THRESHOLD against the seeded corpus.

The threshold decides when the assistant refuses to answer and escalates to a
human, so it has to be measured rather than guessed. Cosine similarity floors are
model-specific: `bge-small-en-v1.5` returns roughly 0.45-0.55 even for completely
unrelated English prose, so a threshold copied from a different model admits
nonsense.

This prints the score distribution for a golden set of questions that SHOULD be
answerable and a set that should NOT be, then reports the widest separating gap.

Usage:
    python -m scripts.calibrate_threshold
"""

from __future__ import annotations

import sys
from pathlib import Path

sys.path.insert(0, str(Path(__file__).resolve().parents[1]))

from app.core.config import settings  # noqa: E402
from app.core.database import SessionLocal, engine  # noqa: E402
from app.services.embedding import embedding_backend_info  # noqa: E402
from app.services.rag_service import semantic_search_policies  # noqa: E402

# Questions the seeded handbook genuinely answers.
SHOULD_ANSWER = [
    "How many paid time off days do I get each year?",
    "What is the notice period after probation?",
    "When do I need a medical certificate for sick leave?",
    "How is provident fund calculated?",
    "What time does the standard working day start?",
    "When is a check-in marked as late?",
    "How is House Rent Allowance calculated?",
    "Can I have two running contracts at the same time?",
    "Who approves my time off request?",
    "What is Professional Tax?",
    "How long is the probation period?",
    "Does unused PTO carry forward to next year?",
    "What happens if I work more than my expected hours?",
    "Who can see my bank account details?",
    "When are payslips emailed to employees?",
    "What is Form 16 and who issues it?",
    "What can an HR Manager do that an Employee cannot?",
    "How does the copilot decide to escalate to a human?",
    "How is a half day recorded?",
    "What is the professional tax deduction amount?",
]

# Questions the corpus genuinely does NOT answer. The assistant must refuse.
#
# The second group matters more than the absurd ones. Questions that share HR
# vocabulary ("allowance", "reimbursement", "limit") but are not actually covered
# score far higher than obvious nonsense, and they are what a real employee asks.
# Calibrating only against silly questions produces a threshold that looks fine
# and still hallucinates on the realistic cases.
SHOULD_REFUSE = [
    # Obvious nonsense: establishes the corpus floor.
    "What is the company policy on bringing a pet iguana aboard the corporate "
    "submarine during a solar eclipse?",
    "How do I request a helicopter for my commute?",
    "What is the recipe for the cafeteria's tiramisu?",
    "Which cryptocurrency does the company mine in the basement?",
    "How many moons does Jupiter have?",
    "What is the warranty period on the office espresso machine's grinder?",
    "Can I bring my alpaca to the annual offsite in Reykjavik?",
    "Who won the inter-departmental quidditch tournament last year?",
    "What is the airspeed velocity of an unladen swallow?",
    # Plausible near-misses: same vocabulary, genuinely undocumented.
    "What is the maximum depth for scuba certification reimbursement?",
    "What is the reimbursement limit for a home office ergonomic chair under the "
    "hybrid work allowance?",
    "What is the allowance for a standing desk?",
    "What is the limit for professional certification reimbursement?",
    "What is the relocation allowance for moving cities?",
    "How much is the annual health insurance premium contribution?",
    "What is the mobile phone bill reimbursement cap?",
]

# A top1-minus-top2 margin gate was measured as an additional signal and REJECTED:
# genuine answers had margins as low as 0.002 while unanswerable questions reached
# 0.075, so the two distributions overlap and every margin gate traded one false
# answer for several needless escalations. Top-1 score alone separates them.


def main() -> None:
    info = embedding_backend_info()
    print("RAG confidence threshold calibration")
    print("=" * 68)
    print(f"Embedding backend : {info['active_backend']} ({info['model']})")
    print(f"Dimensions        : {info['dimensions']}")
    print(f"Configured        : RAG_CONFIDENCE_THRESHOLD={settings.rag_confidence_threshold}")

    db = SessionLocal()
    try:
        # Load the model before reporting the backend, so the report is accurate.
        semantic_search_policies(db, "warmup", top_k=1)
        info = embedding_backend_info()
        print(f"Active backend    : {info['active_backend']}")

        answerable: list[tuple[float, str]] = []
        refusable: list[tuple[float, str]] = []

        for question in SHOULD_ANSWER:
            hits = semantic_search_policies(db, question, top_k=1)
            answerable.append((hits[0]["score"] if hits else 0.0, question))

        for question in SHOULD_REFUSE:
            hits = semantic_search_policies(db, question, top_k=1)
            refusable.append((hits[0]["score"] if hits else 0.0, question))
    finally:
        db.close()
        engine.dispose()

    answerable.sort()
    refusable.sort(reverse=True)

    print("\nSHOULD ANSWER (lowest scoring first)")
    print("-" * 68)
    for score, question in answerable:
        print(f"  {score:.3f}  {question[:60]}")

    print("\nSHOULD REFUSE (highest scoring first)")
    print("-" * 68)
    for score, question in refusable:
        print(f"  {score:.3f}  {question[:60]}")

    lowest_answerable = answerable[0][0]
    highest_refusable = refusable[0][0]
    gap = lowest_answerable - highest_refusable

    print("\nSeparation")
    print("-" * 68)
    print(f"  lowest score among answerable questions : {lowest_answerable:.3f}")
    print(f"  highest score among unanswerable ones   : {highest_refusable:.3f}")
    print(f"  margin                                  : {gap:+.3f}")

    if gap > 0:
        recommended = round(highest_refusable + gap / 2, 2)
        print("  The two sets separate cleanly.")
    else:
        # Overlapping sets are the normal case for a real corpus. Pick the gate
        # that admits ZERO wrong answers, because a confidently wrong HR answer is
        # far more damaging than an unnecessary escalation to a human.
        recommended = round(highest_refusable + 0.01, 2)
        print(
            "  The two sets OVERLAP: some genuinely answerable questions score\n"
            "  below the hardest near-miss. Preferring zero wrong answers over\n"
            "  zero escalations, the gate is set above the near-miss ceiling."
        )

    print(f"\n  Recommended RAG_CONFIDENCE_THRESHOLD = {recommended}")

    def score_gate(gate: float) -> tuple[int, int]:
        false_answers = sum(1 for s, _ in refusable if s >= gate)
        false_escalations = sum(1 for s, _ in answerable if s < gate)
        return false_answers, false_escalations

    current = settings.rag_confidence_threshold
    fp_cur, fn_cur = score_gate(current)
    fp_rec, fn_rec = score_gate(recommended)
    print(
        f"\n  At the configured {current}: {fp_cur} nonsense question(s) would be "
        f"ANSWERED, {fn_cur} good question(s) escalated."
    )
    print(
        f"  At the recommended {recommended}: {fp_rec} nonsense question(s) "
        f"answered, {fn_rec} good question(s) escalated."
    )

    print("\n  Sweep")
    print("  " + "-" * 50)
    for gate in [round(0.50 + i * 0.02, 2) for i in range(16)]:
        fp, fn = score_gate(gate)
        marker = "  <-- configured" if abs(gate - current) < 1e-9 else ""
        print(
            f"    {gate:.2f}  wrong answers={fp:<3} needless escalations={fn:<3}{marker}"
        )

    if fn_rec:
        print(
            "\n  The questions below the gate indicate thin corpus coverage rather\n"
            "  than a broken gate. They escalate to a human, which is correct, but\n"
            "  adding handbook coverage for them is the better fix."
        )
        for score, question in answerable:
            if score < recommended:
                print(f"    {score:.3f}  {question}")


if __name__ == "__main__":
    main()
