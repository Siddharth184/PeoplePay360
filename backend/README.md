# PeoplePay360 Backend

Enterprise HR & Payroll API with a local-first AI copilot. FastAPI + PostgreSQL 17
with `pgvector`, SQLAlchemy 2.0, and a pluggable LLM provider that defaults to
running entirely offline.

Implements [BACKEND_PRODUCTION_ARCHITECTURE.md](../BACKEND_PRODUCTION_ARCHITECTURE.md).

## Quick start

```bash
cd backend

python -m venv .venv
.venv\Scripts\activate            # PowerShell: .\.venv\Scripts\Activate.ps1
pip install -r requirements.txt

copy .env.example .env            # cp on macOS/Linux

docker compose up -d db           # PostgreSQL 17 + pgvector on host port 5433
python -m scripts.init_db         # apply db/schema.sql
python -m scripts.seed_db         # 43 employees, Feb 2026 payrun, HR knowledge base

python -m uvicorn app.main:app --reload --port 8000
```

Interactive docs: <http://127.0.0.1:8000/docs>. Dependency health, including which
AI runtime is actually live: <http://127.0.0.1:8000/health>.

Verify the whole system end to end (164 assertions covering RBAC, integrity
constraints, the salary sandbox, the payrun workflow, PDF generation, and the full
escalation learning loop):

```bash
python -m scripts.verify_api
```

## Seeded accounts

Password for every account: `PeoplePay@360`

| Role | Email | Can do |
| :--- | :--- | :--- |
| `ADMIN` | admin@oxp.com | Everything, plus users and escalation routing |
| `HR_PAYROLL_MANAGER` | vikram.nair@oxp.com | Payroll + salary structures + publish to KB |
| `HR_PAYROLL_USER` | aarav.mehta@oxp.com | Payroll runs, payslips, banking details |
| `HR_MANAGER` | sara.khan@oxp.com | Employees, contracts, attendance, approve leave |
| `EMPLOYEE` | priya.sharma@oxp.com | Own records only |

`aarav.mehta@oxp.com` is EMP-001 from the mockup: contract `CON/2026/0042` at a
100,000 monthly wage, producing a payslip of 50,000 basic / 80,000 gross /
75,000 net.

## Layout

```
backend/
  app/
    core/         config, database, security (RBAC matrix), error mapping
    models/       SQLAlchemy 2.0 ORM, one module per domain
    schemas/      Pydantic request/response models
    services/     all business logic; never imports FastAPI
    api/v1/       routers, one per resource group
    main.py       app factory, lifespan checks, /health
  db/schema.sql   the authoritative DDL (constraints, triggers, HNSW indexes)
  scripts/        init_db, seed_db, verify_api, calibrate_threshold
```

Services raise domain errors (`NotFoundError`, `ConflictError`, ...) and
`core/errors.py` maps them onto status codes, so business logic stays
transport-agnostic and directly unit-testable.

## Design decisions worth knowing

### Integrity lives in the database

Application-level checks are a courtesy; the guarantees are in `db/schema.sql`, so
they hold for bulk imports and manual SQL too.

| Guarantee | Mechanism |
| :--- | :--- |
| No overlapping RUNNING contracts per employee | `trg_check_contract_overlap` trigger using `daterange &&` |
| No duplicate payslip in a payrun | `UNIQUE (payrun_id, employee_id)` |
| No duplicate payslip across overlapping periods | pre-flight query in `payrun_service` |
| Leave can never go negative | `CHECK (taken_days <= allocated_days)` + `FOR UPDATE` row locks |
| Only one open attendance punch | partial unique index `WHERE check_out IS NULL` |
| An ANSWERED ticket always has answer, author and timestamp | `CHECK` constraint |
| Salary rule inputs match its computation type | `CHECK chk_rule_inputs` |

Financial columns are `NUMERIC(12,2)`; the engine uses `Decimal` with
`ROUND_HALF_UP` throughout and never touches a float.

### The salary sandbox

Odoo-style formulas (`result = contract.wage * 0.50`) run under three independent
layers: an AST node allowlist, attribute/call gating, and execution with empty
builtins against read-only field proxies rather than live ORM objects. Numeric
literals are rewritten to `Decimal` before compilation, so a float can never enter
the arithmetic.

`import`, `eval`, `open`, `lambda`, loops, comprehensions and the
`().__class__.__bases__` escape are all rejected. `POST
/api/v1/salary-structures/validate-python-rule` dry-runs a formula against a probe
contract before you save it.

### Two-step payrun

`POST /payruns/step1-validate` writes nothing. It resolves the contract valid for
the exact period per employee and reports blocking issues (no contract, conflicting
contracts, duplicate payslip, terminated employee) separately from advisory
warnings (missing bank details, missing PAN, expiring contract, zero attendance,
unexplained absences). `POST /payruns` then creates the batch for explicitly
selected employees, aborting if any is blocked unless `skip_blocked=true`.

### The copilot answers in tiers and refuses to guess

```
TIER 0  personal data      -> SQL + template     no LLM, exact, offline-safe
TIER 1  retrieval (always) -> fastembed+pgvector local, CPU, ~130MB
TIER 2  phrasing           -> LLMProvider        hosted free tier, PII stripped
TIER 3  provider down      -> ExtractiveProvider verbatim quote with citation
```

Questions about an employee's own data never reach a language model: a hallucinated
salary figure is a defect, not a rough edge. A policy veto keeps entitlement
questions ("how many PTO days do I get each year?") out of the personal-data path,
because answering those with the caller's current balance would be confidently
wrong.

Below the confidence threshold the assistant escalates to the role that owns that
question category, and when a human answers with `publish_to_kb=true` the Q&A pair
is embedded into `document_chunks` so the assistant answers it directly from then
on. No model training. `scripts/verify_api.py` section 14 demonstrates the whole
loop, including re-asking and getting the learned answer back.

### The confidence threshold is measured, not guessed

`RAG_CONFIDENCE_THRESHOLD` defaults to **0.65**, not the 0.45 in the architecture
document. Cosine floors are model-specific: `bge-small-en-v1.5` scores unrelated
English prose at ~0.40-0.59, and plausible-but-undocumented questions ("what is the
standing desk allowance?") at ~0.62, so 0.45 admits most nonsense.

```bash
python -m scripts.calibrate_threshold
```

scores a golden set of answerable and unanswerable questions and reports the
operating point. At 0.65 the current corpus yields zero wrong answers and zero
needless escalations. Re-run it after changing `EMBEDDING_MODEL` or the corpus.

Two related notes:

* `bge` is an **asymmetric** model: queries need the instruction prefix
  `"Represent this sentence for searching relevant passages: "`, passages do not.
  `fastembed.query_embed()` is a passthrough for this ONNX build (verified), so
  `services/embedding.py` applies the prefix itself. Without it the score
  distributions overlap and no threshold separates them.
* A top1-minus-top2 margin gate was measured as an extra signal and **rejected**:
  genuine answers had margins as low as 0.002 while unanswerable questions reached
  0.075. Top-1 score alone separates them.

## Configuration

Everything is in `.env`; see `.env.example` for the annotated list.

```bash
LLM_PROVIDER=extractive         # groq | gemini | ollama | extractive
EMBEDDING_PROVIDER=fastembed    # fastembed | hash
RAG_CONFIDENCE_THRESHOLD=0.65
```

`extractive` is the default so a fresh clone runs with no API key and no network.
Set `LLM_PROVIDER=groq` plus `GROQ_API_KEY` for phrased answers; retrieval and all
personal-data answers stay local either way. If the `fastembed` wheel is
unavailable on your platform, `EMBEDDING_PROVIDER=hash` falls back to a built-in
lexical embedder and every endpoint keeps working, with weaker retrieval.

`SMTP_HOST` left blank puts payslip dispatch in dry-run mode: PDFs are rendered and
recipients resolved, but nothing is transmitted, and the response reports
`mode: dry_run` rather than pretending to have sent mail.

### Security notes

* Passwords are bcrypt with a SHA-256 pre-hash, so bcrypt's 72-byte ceiling never
  truncates a long passphrase.
* The app refuses to boot with `ENVIRONMENT=production` while `JWT_SECRET` is still
  the development default.
* Private employee fields (bank account, IFSC, PAN/SSN) are gated in one
  serialisation helper, so a new endpoint cannot leak them by omitting a filter.
* `redact_pii()` is a mandatory boundary on every outbound `generate()` call and
  strips account numbers, PAN, SSN, IFSC, emails and phone numbers.
* Row scoping for the `EMPLOYEE` role is enforced in the repository layer, never
  left to the client. `INTERNAL` escalation thread events are stripped for the
  asking employee.

## Scheduled jobs

Not wired to a scheduler; each is exposed as an endpoint and a service function so
you can drive them from cron, Celery beat, or a Kubernetes CronJob.

| Job | Endpoint | Suggested cadence |
| :--- | :--- | :--- |
| SLA breach sweep | `POST /api/v1/ai/escalations/sla-sweep` | every 15 minutes |
| Expire due contracts | `POST /api/v1/contracts/expire-due` | daily |

## Deliberate seed anomalies

The seeder plants realistic problems so the pre-flight inspector has something to
find, and so the demo is not a happy path:

* **Preeti Nambiar** (EMP-043) has only a DRAFT contract, so payroll blocks her.
* **Tanvi Shah** has no bank details, producing a warning and blocking mark-paid.
* **Rahul Verma** has no PAN, producing a statutory reporting warning.
* **Farhan Sheikh**'s contract expires 15 March 2026, triggering the 45-day
  renewal warning.
* ~4% of attendance days have no punch at all, producing unexplained absences.
