-- ============================================================================
-- PeoplePay360 :: Enterprise Schema DDL
-- Source of truth: BACKEND_PRODUCTION_ARCHITECTURE.md section 2
-- Target: PostgreSQL 17/18 + pgvector 0.8+
-- Idempotent: safe to run repeatedly against the same database.
-- ============================================================================

-- Enable necessary extensions
CREATE EXTENSION IF NOT EXISTS "uuid-ossp";
CREATE EXTENSION IF NOT EXISTS "btree_gist"; -- overlapping date exclusion support
DO $$ BEGIN
    CREATE EXTENSION IF NOT EXISTS "vector";     -- RAG vector search
EXCEPTION WHEN OTHERS THEN NULL; END $$;

-- ============================================================================
-- 1. AUTHENTICATION & RBAC
-- ============================================================================
DO $$ BEGIN
    CREATE TYPE user_role_enum AS ENUM (
        'ADMIN',
        'HR_PAYROLL_MANAGER',
        'HR_PAYROLL_USER',
        'HR_MANAGER',
        'EMPLOYEE'
    );
EXCEPTION WHEN duplicate_object THEN NULL; END $$;

CREATE TABLE IF NOT EXISTS auth_users (
    id UUID PRIMARY KEY DEFAULT uuid_generate_v4(),
    email VARCHAR(255) UNIQUE NOT NULL,
    hashed_password VARCHAR(255) NOT NULL,
    role user_role_enum NOT NULL DEFAULT 'EMPLOYEE',
    is_active BOOLEAN NOT NULL DEFAULT TRUE,
    created_at TIMESTAMPTZ NOT NULL DEFAULT NOW(),
    updated_at TIMESTAMPTZ NOT NULL DEFAULT NOW()
);

-- Case-insensitive login without breaking the stored casing
CREATE UNIQUE INDEX IF NOT EXISTS idx_auth_users_email_lower ON auth_users (LOWER(email));

-- SESSION REVOCATION.
-- A JWT is self-contained, so without a server-side check a deactivated or demoted
-- user keeps full access until their token expires. Every issued token embeds the
-- `token_version` current at login; bumping this column invalidates every token
-- already issued, so deactivation, role changes and password changes take effect
-- on the very next request.
--
-- A counter rather than a timestamp: `iat` is whole seconds, so a timestamp cutoff
-- has an ambiguous window in which a token minted in the same second as the
-- revocation cannot be told apart from one minted just before it.
ALTER TABLE auth_users
    ADD COLUMN IF NOT EXISTS token_version INTEGER NOT NULL DEFAULT 1;
-- Audit only; enforcement uses token_version above.
ALTER TABLE auth_users
    ADD COLUMN IF NOT EXISTS credentials_changed_at TIMESTAMPTZ NOT NULL DEFAULT NOW();

-- ============================================================================
-- 2. MASTER DATA (Departments, Job Positions, Schedules)
-- ============================================================================
CREATE TABLE IF NOT EXISTS departments (
    id UUID PRIMARY KEY DEFAULT uuid_generate_v4(),
    name VARCHAR(100) NOT NULL UNIQUE,
    manager_employee_id UUID, -- circular FK added via ALTER TABLE below
    is_active BOOLEAN NOT NULL DEFAULT TRUE,
    created_at TIMESTAMPTZ NOT NULL DEFAULT NOW()
);

CREATE TABLE IF NOT EXISTS job_positions (
    id UUID PRIMARY KEY DEFAULT uuid_generate_v4(),
    name VARCHAR(100) NOT NULL,
    department_id UUID NOT NULL REFERENCES departments(id) ON DELETE RESTRICT,
    created_at TIMESTAMPTZ NOT NULL DEFAULT NOW(),
    UNIQUE (name, department_id)
);

CREATE TABLE IF NOT EXISTS working_schedules (
    id UUID PRIMARY KEY DEFAULT uuid_generate_v4(),
    name VARCHAR(100) NOT NULL UNIQUE, -- '40 Hours / Week', 'Night Shift'
    company_name VARCHAR(100) NOT NULL DEFAULT 'OXP Pvt Ltd',
    days_per_week INT NOT NULL DEFAULT 5,
    hours_per_week NUMERIC(5, 2) NOT NULL DEFAULT 40.00,
    timezone VARCHAR(50) NOT NULL DEFAULT 'Asia/Kolkata',
    is_active BOOLEAN NOT NULL DEFAULT TRUE,
    created_at TIMESTAMPTZ NOT NULL DEFAULT NOW()
);

CREATE TABLE IF NOT EXISTS working_schedule_lines (
    id UUID PRIMARY KEY DEFAULT uuid_generate_v4(),
    schedule_id UUID NOT NULL REFERENCES working_schedules(id) ON DELETE CASCADE,
    day_of_week INT NOT NULL CHECK (day_of_week BETWEEN 0 AND 6), -- 0=Mon, 6=Sun
    day_name VARCHAR(15) NOT NULL,
    start_time TIME NOT NULL,
    end_time TIME NOT NULL,
    break_hours NUMERIC(4, 2) NOT NULL DEFAULT 1.00,
    work_hours NUMERIC(4, 2) GENERATED ALWAYS AS (
        EXTRACT(EPOCH FROM (end_time - start_time)) / 3600 - break_hours
    ) STORED,
    CONSTRAINT chk_times CHECK (end_time > start_time),
    UNIQUE (schedule_id, day_of_week, start_time)
);

CREATE INDEX IF NOT EXISTS idx_schedule_lines_schedule
    ON working_schedule_lines (schedule_id, day_of_week);

-- Company holidays: days that must not be counted as expected working days
CREATE TABLE IF NOT EXISTS public_holidays (
    id UUID PRIMARY KEY DEFAULT uuid_generate_v4(),
    name VARCHAR(100) NOT NULL,
    holiday_date DATE NOT NULL UNIQUE,
    created_at TIMESTAMPTZ NOT NULL DEFAULT NOW()
);

-- ============================================================================
-- 3. EMPLOYEES
-- ============================================================================
CREATE TABLE IF NOT EXISTS employees (
    id UUID PRIMARY KEY DEFAULT uuid_generate_v4(),
    user_id UUID UNIQUE REFERENCES auth_users(id) ON DELETE SET NULL,
    badge_id VARCHAR(20) UNIQUE NOT NULL,
    name VARCHAR(150) NOT NULL,
    work_email VARCHAR(255) UNIQUE NOT NULL,
    phone VARCHAR(25),
    department_id UUID REFERENCES departments(id) ON DELETE RESTRICT,
    job_position_id UUID REFERENCES job_positions(id) ON DELETE RESTRICT,
    manager_id UUID REFERENCES employees(id) ON DELETE SET NULL,
    working_schedule_id UUID REFERENCES working_schedules(id) ON DELETE RESTRICT,
    work_location VARCHAR(100) DEFAULT 'Mumbai',
    status VARCHAR(20) NOT NULL DEFAULT 'ACTIVE'
        CHECK (status IN ('ACTIVE', 'INACTIVE', 'TERMINATED')),

    -- Drives the dashboard's "Employee Type" and "Company" filters
    employee_type VARCHAR(20) NOT NULL DEFAULT 'PERMANENT'
        CHECK (employee_type IN ('PERMANENT', 'PROBATION', 'CONTRACT', 'INTERN', 'CONSULTANT')),
    company_name VARCHAR(100) NOT NULL DEFAULT 'OXP Pvt Ltd',

    -- Private Information (Restricted to Payroll / Admin)
    bank_account_number VARCHAR(50),
    bank_name VARCHAR(100),
    bank_ifsc_or_routing VARCHAR(30),
    pan_or_ssn VARCHAR(30),
    date_of_joining DATE NOT NULL DEFAULT CURRENT_DATE,

    created_at TIMESTAMPTZ NOT NULL DEFAULT NOW(),
    updated_at TIMESTAMPTZ NOT NULL DEFAULT NOW(),

    -- ZERO-LOOPHOLE: an employee may not be their own manager
    CONSTRAINT chk_not_self_manager CHECK (manager_id IS NULL OR manager_id <> id)
);

-- Upgrade path for databases created before these columns existed.
ALTER TABLE employees
    ADD COLUMN IF NOT EXISTS employee_type VARCHAR(20) NOT NULL DEFAULT 'PERMANENT';
ALTER TABLE employees
    ADD COLUMN IF NOT EXISTS company_name VARCHAR(100) NOT NULL DEFAULT 'OXP Pvt Ltd';
DO $$ BEGIN
    ALTER TABLE employees ADD CONSTRAINT chk_employee_type
        CHECK (employee_type IN ('PERMANENT', 'PROBATION', 'CONTRACT', 'INTERN', 'CONSULTANT'));
EXCEPTION WHEN duplicate_object THEN NULL; END $$;

CREATE INDEX IF NOT EXISTS idx_employees_department ON employees (department_id, status);
CREATE INDEX IF NOT EXISTS idx_employees_manager ON employees (manager_id);
CREATE INDEX IF NOT EXISTS idx_employees_type ON employees (employee_type, status);

DO $$ BEGIN
    ALTER TABLE departments
    ADD CONSTRAINT fk_department_manager FOREIGN KEY (manager_employee_id)
    REFERENCES employees(id) ON DELETE SET NULL;
EXCEPTION WHEN duplicate_object THEN NULL; END $$;

-- ============================================================================
-- 4. CONTRACTS (With Overlapping Active Period Exclusion Guard)
-- ============================================================================
CREATE SEQUENCE IF NOT EXISTS contract_seq START 1;

CREATE TABLE IF NOT EXISTS hr_contracts (
    id UUID PRIMARY KEY DEFAULT uuid_generate_v4(),
    reference_code VARCHAR(30) UNIQUE NOT NULL, -- CON/2026/0001
    employee_id UUID NOT NULL REFERENCES employees(id) ON DELETE CASCADE,
    department_id UUID REFERENCES departments(id) ON DELETE RESTRICT,
    job_position_id UUID REFERENCES job_positions(id) ON DELETE RESTRICT,
    working_schedule_id UUID REFERENCES working_schedules(id) ON DELETE RESTRICT,

    start_date DATE NOT NULL,
    end_date DATE, -- NULL means ongoing
    wage_monthly NUMERIC(12, 2) NOT NULL CHECK (wage_monthly >= 0),

    status VARCHAR(20) NOT NULL DEFAULT 'DRAFT'
        CHECK (status IN ('DRAFT', 'RUNNING', 'EXPIRED', 'CANCELLED')),
    notes TEXT,
    created_at TIMESTAMPTZ NOT NULL DEFAULT NOW(),
    updated_at TIMESTAMPTZ NOT NULL DEFAULT NOW(),

    CONSTRAINT chk_dates CHECK (end_date IS NULL OR end_date >= start_date)
);

-- NOTE: hr_contracts.salary_structure_id is added in section 7, once
-- salary_structures exists.

CREATE INDEX IF NOT EXISTS idx_contracts_employee_running
    ON hr_contracts (employee_id, status);
CREATE INDEX IF NOT EXISTS idx_contracts_period
    ON hr_contracts (start_date, end_date);

-- CRITICAL ZERO-LOOPHOLE CONSTRAINT:
-- An employee CANNOT have multiple RUNNING contracts with overlapping ranges.
CREATE OR REPLACE FUNCTION fn_check_contract_overlap()
RETURNS TRIGGER AS $$
BEGIN
    IF NEW.status = 'RUNNING' THEN
        IF EXISTS (
            SELECT 1 FROM hr_contracts
            WHERE employee_id = NEW.employee_id
              AND id <> NEW.id
              AND status = 'RUNNING'
              AND (
                daterange(start_date, COALESCE(end_date, '9999-12-31'::DATE), '[]') &&
                daterange(NEW.start_date, COALESCE(NEW.end_date, '9999-12-31'::DATE), '[]')
              )
        ) THEN
            RAISE EXCEPTION
                'Employee % already has an active RUNNING contract in this period.',
                NEW.employee_id;
        END IF;
    END IF;
    RETURN NEW;
END;
$$ LANGUAGE plpgsql;

DROP TRIGGER IF EXISTS trg_check_contract_overlap ON hr_contracts;
CREATE TRIGGER trg_check_contract_overlap
BEFORE INSERT OR UPDATE ON hr_contracts
FOR EACH ROW EXECUTE FUNCTION fn_check_contract_overlap();

-- ============================================================================
-- 5. ATTENDANCE SYSTEM
-- ============================================================================
CREATE TABLE IF NOT EXISTS attendances (
    id UUID PRIMARY KEY DEFAULT uuid_generate_v4(),
    employee_id UUID NOT NULL REFERENCES employees(id) ON DELETE CASCADE,
    check_in TIMESTAMPTZ NOT NULL,
    check_out TIMESTAMPTZ,
    worked_hours NUMERIC(5, 2) DEFAULT 0.00,
    overtime_hours NUMERIC(5, 2) DEFAULT 0.00,
    status VARCHAR(20) NOT NULL DEFAULT 'PRESENT'
        CHECK (status IN ('PRESENT', 'LATE', 'ABSENT', 'HALF_DAY')),
    is_manual_edit BOOLEAN NOT NULL DEFAULT FALSE,
    audit_notes TEXT,
    created_at TIMESTAMPTZ NOT NULL DEFAULT NOW(),

    CONSTRAINT chk_check_in_out CHECK (check_out IS NULL OR check_out >= check_in)
);

CREATE INDEX IF NOT EXISTS idx_attendance_emp_date ON attendances (employee_id, check_in);

-- ZERO-LOOPHOLE: an employee may only ever have ONE punch open at a time.
CREATE UNIQUE INDEX IF NOT EXISTS idx_attendance_single_open
    ON attendances (employee_id) WHERE check_out IS NULL;

-- ============================================================================
-- 6. TIME OFF (Types, Allocations & Requests)
-- ============================================================================
CREATE TABLE IF NOT EXISTS timeoff_types (
    id UUID PRIMARY KEY DEFAULT uuid_generate_v4(),
    name VARCHAR(50) NOT NULL UNIQUE,
    unit VARCHAR(10) NOT NULL DEFAULT 'DAYS' CHECK (unit IN ('DAYS', 'HOURS')),
    requires_allocation BOOLEAN NOT NULL DEFAULT TRUE,
    approval_level VARCHAR(20) NOT NULL DEFAULT 'MANAGER'
        CHECK (approval_level IN ('MANAGER', 'HR_OFFICER', 'NONE')),
    display_color VARCHAR(20) NOT NULL DEFAULT '#017E84',
    is_active BOOLEAN NOT NULL DEFAULT TRUE,
    created_at TIMESTAMPTZ NOT NULL DEFAULT NOW()
);

-- Mockup: the Time Off Type form carries a payroll work-entry mapping and notes.
ALTER TABLE timeoff_types ADD COLUMN IF NOT EXISTS work_entry_type VARCHAR(50);
ALTER TABLE timeoff_types ADD COLUMN IF NOT EXISTS notes TEXT;

-- Payroll policy: whether leave of this type is paid (no salary impact) or unpaid
-- (drives a loss-of-pay deduction in the salary engine). Defaults to TRUE so
-- existing rows keep their current, salary-neutral behaviour after an upgrade.
ALTER TABLE timeoff_types ADD COLUMN IF NOT EXISTS is_paid BOOLEAN NOT NULL DEFAULT TRUE;
-- Optional: the salary rule code that applies the unpaid-leave deduction. When
-- NULL the engine falls back to a standard pro-rata daily-rate deduction.
ALTER TABLE timeoff_types ADD COLUMN IF NOT EXISTS unpaid_deduction_rule_code VARCHAR(30);

CREATE TABLE IF NOT EXISTS leave_allocations (
    id UUID PRIMARY KEY DEFAULT uuid_generate_v4(),
    employee_id UUID NOT NULL REFERENCES employees(id) ON DELETE CASCADE,
    timeoff_type_id UUID NOT NULL REFERENCES timeoff_types(id) ON DELETE RESTRICT,
    allocated_days NUMERIC(5, 2) NOT NULL CHECK (allocated_days >= 0),
    taken_days NUMERIC(5, 2) NOT NULL DEFAULT 0.00 CHECK (taken_days >= 0),
    remaining_days NUMERIC(5, 2) GENERATED ALWAYS AS (allocated_days - taken_days) STORED,
    validity_year INT NOT NULL DEFAULT EXTRACT(YEAR FROM CURRENT_DATE),
    status VARCHAR(20) NOT NULL DEFAULT 'TO_APPROVE'
        CHECK (status IN ('TO_APPROVE', 'APPROVED', 'REFUSED')),
    approver_employee_id UUID REFERENCES employees(id) ON DELETE SET NULL,
    description TEXT,
    created_at TIMESTAMPTZ NOT NULL DEFAULT NOW(),

    CONSTRAINT chk_taken_le_alloc CHECK (taken_days <= allocated_days)
);

-- Mockup shows a human-readable validity such as "2026 Annual Balance".
ALTER TABLE leave_allocations ADD COLUMN IF NOT EXISTS validity_label VARCHAR(60);

CREATE INDEX IF NOT EXISTS idx_allocations_emp_type
    ON leave_allocations (employee_id, timeoff_type_id, status);

CREATE TABLE IF NOT EXISTS leave_requests (
    id UUID PRIMARY KEY DEFAULT uuid_generate_v4(),
    employee_id UUID NOT NULL REFERENCES employees(id) ON DELETE CASCADE,
    timeoff_type_id UUID NOT NULL REFERENCES timeoff_types(id) ON DELETE RESTRICT,
    allocation_id UUID REFERENCES leave_allocations(id) ON DELETE SET NULL,
    start_date DATE NOT NULL,
    end_date DATE NOT NULL,
    duration_days NUMERIC(4, 2) NOT NULL CHECK (duration_days > 0),
    reason TEXT,
    status VARCHAR(20) NOT NULL DEFAULT 'TO_APPROVE'
        CHECK (status IN ('TO_APPROVE', 'APPROVED', 'REFUSED')),
    approver_employee_id UUID REFERENCES employees(id) ON DELETE SET NULL,
    created_at TIMESTAMPTZ NOT NULL DEFAULT NOW(),

    CONSTRAINT chk_leave_dates CHECK (end_date >= start_date)
);

CREATE INDEX IF NOT EXISTS idx_leave_requests_emp ON leave_requests (employee_id, status);
CREATE INDEX IF NOT EXISTS idx_leave_requests_period ON leave_requests (start_date, end_date);

-- ============================================================================
-- 7. SALARY STRUCTURES & SALARY RULES (Python Expression Capable)
-- ============================================================================
CREATE TABLE IF NOT EXISTS salary_structures (
    id UUID PRIMARY KEY DEFAULT uuid_generate_v4(),
    name VARCHAR(100) NOT NULL UNIQUE,
    code VARCHAR(50) NOT NULL UNIQUE,
    is_active BOOLEAN NOT NULL DEFAULT TRUE,
    notes TEXT,
    created_at TIMESTAMPTZ NOT NULL DEFAULT NOW()
);

CREATE TABLE IF NOT EXISTS salary_rules (
    id UUID PRIMARY KEY DEFAULT uuid_generate_v4(),
    salary_structure_id UUID NOT NULL REFERENCES salary_structures(id) ON DELETE CASCADE,
    name VARCHAR(100) NOT NULL,
    code VARCHAR(30) NOT NULL, -- BASIC, HRA, STD, GROSS, PF, PT, NET
    sequence INT NOT NULL DEFAULT 10,
    category VARCHAR(30) NOT NULL
        CHECK (category IN ('BASIC', 'ALLOWANCE', 'GROSS', 'DEDUCTION', 'NET')),

    computation_type VARCHAR(20) NOT NULL
        CHECK (computation_type IN ('FIXED', 'PERCENTAGE', 'PYTHON_CODE')),
    fixed_amount NUMERIC(12, 2) DEFAULT 0.00,
    percentage_base VARCHAR(30),   -- 'WAGE', 'BASIC', 'GROSS'
    percentage_rate NUMERIC(5, 2), -- 50.00 == 50%
    python_code TEXT,

    is_active BOOLEAN NOT NULL DEFAULT TRUE,
    created_at TIMESTAMPTZ NOT NULL DEFAULT NOW(),

    UNIQUE (salary_structure_id, code),

    -- ZERO-LOOPHOLE: every computation_type must carry its own inputs
    CONSTRAINT chk_rule_inputs CHECK (
        (computation_type = 'FIXED' AND fixed_amount IS NOT NULL)
        OR (computation_type = 'PERCENTAGE'
            AND percentage_base IN ('WAGE', 'BASIC', 'GROSS')
            AND percentage_rate IS NOT NULL)
        OR (computation_type = 'PYTHON_CODE'
            AND python_code IS NOT NULL AND LENGTH(TRIM(python_code)) > 0)
    )
);

-- Multiplier applied to the computed amount (Odoo's rule "Quantity"). Lets one
-- rule express "3 days of leave encashment" without a bespoke formula.
ALTER TABLE salary_rules
    ADD COLUMN IF NOT EXISTS quantity NUMERIC(8, 2) NOT NULL DEFAULT 1.00;
DO $$ BEGIN
    ALTER TABLE salary_rules ADD CONSTRAINT chk_rule_quantity CHECK (quantity >= 0);
EXCEPTION WHEN duplicate_object THEN NULL; END $$;

CREATE INDEX IF NOT EXISTS idx_salary_rules_order
    ON salary_rules (salary_structure_id, sequence ASC);

-- Deferred from section 4: the contract may name the structure it is paid under.
ALTER TABLE hr_contracts
    ADD COLUMN IF NOT EXISTS salary_structure_id UUID
    REFERENCES salary_structures(id) ON DELETE SET NULL;

-- ============================================================================
-- 8. PAYROLL RUNS & PAYSLIPS
-- ============================================================================
CREATE SEQUENCE IF NOT EXISTS payrun_seq START 1;
CREATE SEQUENCE IF NOT EXISTS payslip_seq START 1;

CREATE TABLE IF NOT EXISTS payruns (
    id UUID PRIMARY KEY DEFAULT uuid_generate_v4(),
    reference_code VARCHAR(30) UNIQUE NOT NULL, -- PAY/2026/0001
    name VARCHAR(100) NOT NULL,                 -- 'February 2026'
    salary_structure_id UUID NOT NULL REFERENCES salary_structures(id) ON DELETE RESTRICT,
    date_start DATE NOT NULL,
    date_end DATE NOT NULL,
    status VARCHAR(20) NOT NULL DEFAULT 'DRAFT'
        CHECK (status IN ('DRAFT', 'COMPUTED', 'VALIDATED', 'PAID')),

    total_basic NUMERIC(14, 2) DEFAULT 0.00,
    total_gross NUMERIC(14, 2) DEFAULT 0.00,
    total_net NUMERIC(14, 2) DEFAULT 0.00,
    employee_count INT DEFAULT 0,
    warnings_count INT DEFAULT 0,

    created_by_user_id UUID REFERENCES auth_users(id) ON DELETE SET NULL,
    created_at TIMESTAMPTZ NOT NULL DEFAULT NOW(),
    updated_at TIMESTAMPTZ NOT NULL DEFAULT NOW(),

    CONSTRAINT chk_payrun_dates CHECK (date_end >= date_start)
);

CREATE INDEX IF NOT EXISTS idx_payruns_period ON payruns (date_start, date_end);
CREATE INDEX IF NOT EXISTS idx_payruns_status ON payruns (status, created_at DESC);

CREATE TABLE IF NOT EXISTS payslips (
    id UUID PRIMARY KEY DEFAULT uuid_generate_v4(),
    reference_code VARCHAR(30) UNIQUE NOT NULL, -- SLIP/2026/0001
    payrun_id UUID NOT NULL REFERENCES payruns(id) ON DELETE CASCADE,
    employee_id UUID NOT NULL REFERENCES employees(id) ON DELETE RESTRICT,
    contract_id UUID NOT NULL REFERENCES hr_contracts(id) ON DELETE RESTRICT,
    salary_structure_id UUID NOT NULL REFERENCES salary_structures(id) ON DELETE RESTRICT,

    date_start DATE NOT NULL,
    date_end DATE NOT NULL,
    worked_days NUMERIC(4, 2) NOT NULL DEFAULT 0.00,

    basic_amount NUMERIC(12, 2) NOT NULL DEFAULT 0.00,
    gross_amount NUMERIC(12, 2) NOT NULL DEFAULT 0.00,
    net_amount NUMERIC(12, 2) NOT NULL DEFAULT 0.00,

    status VARCHAR(20) NOT NULL DEFAULT 'DRAFT'
        CHECK (status IN ('DRAFT', 'DONE', 'PAID')),
    warning_notes TEXT,
    pdf_url VARCHAR(500),
    emailed_at TIMESTAMPTZ,

    created_at TIMESTAMPTZ NOT NULL DEFAULT NOW(),

    -- ZERO-LOOPHOLE: no duplicate payslips for an employee inside one payrun
    UNIQUE (payrun_id, employee_id)
);

ALTER TABLE timeoff_types
    ADD COLUMN IF NOT EXISTS is_paid BOOLEAN NOT NULL DEFAULT TRUE;
ALTER TABLE payslips
    ADD COLUMN IF NOT EXISTS worked_hours NUMERIC(6, 2) NOT NULL DEFAULT 0.00;
ALTER TABLE payslips
    ADD COLUMN IF NOT EXISTS overtime_hours NUMERIC(6, 2) NOT NULL DEFAULT 0.00;

CREATE TABLE IF NOT EXISTS payslip_lines (
    id UUID PRIMARY KEY DEFAULT uuid_generate_v4(),
    payslip_id UUID NOT NULL REFERENCES payslips(id) ON DELETE CASCADE,
    salary_rule_id UUID NOT NULL REFERENCES salary_rules(id) ON DELETE RESTRICT,
    rule_name VARCHAR(100) NOT NULL,
    rule_code VARCHAR(30) NOT NULL,
    category VARCHAR(30) NOT NULL,
    sequence INT NOT NULL,
    amount NUMERIC(12, 2) NOT NULL,
    created_at TIMESTAMPTZ NOT NULL DEFAULT NOW(),

    UNIQUE (payslip_id, salary_rule_id)
);

CREATE INDEX IF NOT EXISTS idx_payslips_payrun ON payslips (payrun_id);
CREATE INDEX IF NOT EXISTS idx_payslips_employee ON payslips (employee_id);
CREATE INDEX IF NOT EXISTS idx_payslip_lines_slip ON payslip_lines (payslip_id, sequence ASC);

-- ============================================================================
-- 9. KNOWLEDGE VECTOR STORE (Local RAG for HR Policies & Rules)
-- ============================================================================
CREATE TABLE IF NOT EXISTS document_chunks (
    id UUID PRIMARY KEY DEFAULT uuid_generate_v4(),
    collection_name VARCHAR(50) NOT NULL, -- 'hr_policies', 'payroll_rules', 'handbook'
    title VARCHAR(255) NOT NULL,
    content TEXT NOT NULL,
    metadata JSONB NOT NULL DEFAULT '{}',
    created_at TIMESTAMPTZ NOT NULL DEFAULT NOW()
);

DO $$ BEGIN
    ALTER TABLE document_chunks ADD COLUMN IF NOT EXISTS embedding vector(384);
EXCEPTION WHEN OTHERS THEN
    ALTER TABLE document_chunks ADD COLUMN IF NOT EXISTS embedding FLOAT[];
END $$;

CREATE INDEX IF NOT EXISTS idx_document_chunks_collection
    ON document_chunks (collection_name);

-- Fast Approximate Nearest Neighbor Index (HNSW)
DO $$ BEGIN
    CREATE INDEX IF NOT EXISTS idx_document_chunks_embedding
    ON document_chunks USING hnsw (embedding vector_cosine_ops)
    WITH (m = 16, ef_construction = 64);
EXCEPTION WHEN OTHERS THEN NULL; END $$;

-- Auditability: which chunks were retrieved, and which provider answered
CREATE TABLE IF NOT EXISTS rag_retrieval_log (
    id UUID PRIMARY KEY DEFAULT uuid_generate_v4(),
    asked_by_user_id UUID REFERENCES auth_users(id) ON DELETE SET NULL,
    employee_id UUID REFERENCES employees(id) ON DELETE SET NULL,
    question_text TEXT NOT NULL,
    mode VARCHAR(20) NOT NULL, -- TIER0_TEMPLATE | ANSWERED | ESCALATED | REUSED
    provider_used VARCHAR(20),
    top_score NUMERIC(4, 3),
    retrieved_chunk_ids UUID[] NOT NULL DEFAULT '{}',
    created_at TIMESTAMPTZ NOT NULL DEFAULT NOW()
);

CREATE INDEX IF NOT EXISTS idx_rag_log_user
    ON rag_retrieval_log (asked_by_user_id, created_at DESC);

-- Copilot chat transcript. Gives conversation_id / source_message_id on
-- rag_escalations something concrete to point at.
CREATE TABLE IF NOT EXISTS ai_conversations (
    id UUID PRIMARY KEY DEFAULT uuid_generate_v4(),
    user_id UUID NOT NULL REFERENCES auth_users(id) ON DELETE CASCADE,
    employee_id UUID REFERENCES employees(id) ON DELETE SET NULL,
    title VARCHAR(160) NOT NULL DEFAULT 'New conversation',
    created_at TIMESTAMPTZ NOT NULL DEFAULT NOW(),
    updated_at TIMESTAMPTZ NOT NULL DEFAULT NOW()
);

CREATE TABLE IF NOT EXISTS ai_messages (
    id UUID PRIMARY KEY DEFAULT uuid_generate_v4(),
    conversation_id UUID NOT NULL REFERENCES ai_conversations(id) ON DELETE CASCADE,
    role VARCHAR(12) NOT NULL CHECK (role IN ('USER', 'ASSISTANT')),
    content TEXT NOT NULL,
    mode VARCHAR(20),          -- TIER0_TEMPLATE | ANSWERED | ESCALATED | REUSED
    confidence NUMERIC(4, 3),
    citations JSONB NOT NULL DEFAULT '[]',
    created_at TIMESTAMPTZ NOT NULL DEFAULT NOW()
);

CREATE INDEX IF NOT EXISTS idx_ai_messages_thread
    ON ai_messages (conversation_id, created_at ASC);
CREATE INDEX IF NOT EXISTS idx_ai_conversations_user
    ON ai_conversations (user_id, updated_at DESC);

-- ============================================================================
-- 10. AI ESCALATION LOOP (Human-in-the-Loop fallback when RAG cannot answer)
-- ============================================================================
DO $$ BEGIN
    CREATE TYPE escalation_status_enum AS ENUM (
        'OPEN', 'ASSIGNED', 'ANSWERED', 'CLOSED', 'REJECTED'
    );
EXCEPTION WHEN duplicate_object THEN NULL; END $$;

DO $$ BEGIN
    CREATE TYPE escalation_priority_enum AS ENUM ('LOW', 'NORMAL', 'HIGH', 'URGENT');
EXCEPTION WHEN duplicate_object THEN NULL; END $$;

DO $$ BEGIN
    CREATE TYPE escalation_category_enum AS ENUM (
        'LEAVE_POLICY', 'PAYROLL_SALARY', 'ATTENDANCE', 'CONTRACT',
        'TAX_STATUTORY', 'IT_ACCESS', 'OTHER'
    );
EXCEPTION WHEN duplicate_object THEN NULL; END $$;

CREATE SEQUENCE IF NOT EXISTS escalation_seq START 1;

CREATE TABLE IF NOT EXISTS rag_escalations (
    id UUID PRIMARY KEY DEFAULT uuid_generate_v4(),
    ticket_no VARCHAR(30) UNIQUE NOT NULL,              -- ESC/2026/0001

    -- ORIGIN: exactly which chat turn failed
    conversation_id UUID,
    source_message_id UUID,

    -- WHO ASKED
    employee_id UUID NOT NULL REFERENCES employees(id) ON DELETE RESTRICT,
    asked_by_user_id UUID NOT NULL REFERENCES auth_users(id) ON DELETE RESTRICT,

    -- WHAT WAS ASKED
    question_text TEXT NOT NULL,
    category escalation_category_enum NOT NULL DEFAULT 'OTHER',

    -- WHY IT ESCALATED (auditable evidence, never a black box)
    escalation_reason VARCHAR(40) NOT NULL
        CHECK (escalation_reason IN
            ('LOW_CONFIDENCE', 'NO_CONTEXT', 'NO_TOOL_MATCH', 'USER_REQUESTED')),
    retrieval_confidence NUMERIC(4, 3),
    ai_draft_answer TEXT,

    -- WORKFLOW
    status escalation_status_enum NOT NULL DEFAULT 'OPEN',
    priority escalation_priority_enum NOT NULL DEFAULT 'NORMAL',
    assigned_to_user_id UUID REFERENCES auth_users(id) ON DELETE SET NULL,
    assigned_at TIMESTAMPTZ,

    -- RESOLUTION (authored by a human -> zero hallucination risk)
    answer_text TEXT,
    answered_by_user_id UUID REFERENCES auth_users(id) ON DELETE SET NULL,
    answered_at TIMESTAMPTZ,

    -- SLA TRACKING
    sla_due_at TIMESTAMPTZ NOT NULL,
    first_response_at TIMESTAMPTZ,

    -- KNOWLEDGE FLYWHEEL
    publish_to_kb BOOLEAN NOT NULL DEFAULT FALSE,
    kb_chunk_id UUID REFERENCES document_chunks(id) ON DELETE SET NULL,
    duplicate_of_id UUID REFERENCES rag_escalations(id) ON DELETE SET NULL,

    created_at TIMESTAMPTZ NOT NULL DEFAULT NOW(),
    updated_at TIMESTAMPTZ NOT NULL DEFAULT NOW(),

    CONSTRAINT chk_answer_completeness CHECK (
        status <> 'ANSWERED' OR
        (answer_text IS NOT NULL AND answered_by_user_id IS NOT NULL
         AND answered_at IS NOT NULL)
    ),
    CONSTRAINT chk_assignment_completeness CHECK (
        status <> 'ASSIGNED' OR assigned_to_user_id IS NOT NULL
    ),
    CONSTRAINT chk_confidence_range CHECK (
        retrieval_confidence IS NULL
        OR (retrieval_confidence >= 0 AND retrieval_confidence <= 1)
    ),
    CONSTRAINT chk_not_own_duplicate CHECK (duplicate_of_id IS NULL OR duplicate_of_id <> id)
);

DO $$ BEGIN
    ALTER TABLE rag_escalations ADD COLUMN IF NOT EXISTS question_embedding vector(384);
EXCEPTION WHEN OTHERS THEN
    ALTER TABLE rag_escalations ADD COLUMN IF NOT EXISTS question_embedding FLOAT[];
END $$;

CREATE INDEX IF NOT EXISTS idx_escalations_queue
    ON rag_escalations (status, priority DESC, created_at ASC);
CREATE INDEX IF NOT EXISTS idx_escalations_assignee
    ON rag_escalations (assigned_to_user_id, status);
CREATE INDEX IF NOT EXISTS idx_escalations_employee
    ON rag_escalations (employee_id, created_at DESC);
CREATE INDEX IF NOT EXISTS idx_escalations_overdue
    ON rag_escalations (sla_due_at) WHERE status IN ('OPEN', 'ASSIGNED');
DO $$ BEGIN
    CREATE INDEX IF NOT EXISTS idx_escalations_embedding ON rag_escalations
    USING hnsw (question_embedding vector_cosine_ops) WITH (m = 16, ef_construction = 64);
EXCEPTION WHEN OTHERS THEN NULL; END $$;
CREATE INDEX IF NOT EXISTS idx_escalations_open_per_emp
    ON rag_escalations (employee_id) WHERE status IN ('OPEN', 'ASSIGNED');

-- Append-only thread + audit trail in one table (who did what, when)
CREATE TABLE IF NOT EXISTS rag_escalation_events (
    id UUID PRIMARY KEY DEFAULT uuid_generate_v4(),
    escalation_id UUID NOT NULL REFERENCES rag_escalations(id) ON DELETE CASCADE,
    actor_user_id UUID REFERENCES auth_users(id) ON DELETE SET NULL,
    event_type VARCHAR(30) NOT NULL CHECK (event_type IN (
        'CREATED', 'ASSIGNED', 'REASSIGNED', 'COMMENTED', 'ANSWERED',
        'ANSWER_EDITED', 'CLOSED', 'REOPENED', 'REJECTED', 'PUBLISHED_TO_KB'
    )),
    body TEXT,
    -- INTERNAL notes are visible to Admin/HR only, never to the asking employee
    visibility VARCHAR(10) NOT NULL DEFAULT 'PUBLIC'
        CHECK (visibility IN ('PUBLIC', 'INTERNAL')),
    created_at TIMESTAMPTZ NOT NULL DEFAULT NOW()
);

CREATE INDEX IF NOT EXISTS idx_escalation_events_thread
    ON rag_escalation_events (escalation_id, created_at ASC);

-- Configurable routing: which role owns which question category, and its SLA
CREATE TABLE IF NOT EXISTS escalation_routing_rules (
    id UUID PRIMARY KEY DEFAULT uuid_generate_v4(),
    category escalation_category_enum NOT NULL,
    target_role user_role_enum NOT NULL,
    department_id UUID REFERENCES departments(id) ON DELETE CASCADE, -- NULL = global
    sla_hours INT NOT NULL DEFAULT 24 CHECK (sla_hours > 0),
    priority escalation_priority_enum NOT NULL DEFAULT 'NORMAL',
    sequence INT NOT NULL DEFAULT 10,
    is_active BOOLEAN NOT NULL DEFAULT TRUE,
    UNIQUE (category, department_id)
);

-- Postgres does not enforce UNIQUE across NULLs, so the global default needs
-- its own partial unique index or duplicates could silently accumulate.
CREATE UNIQUE INDEX IF NOT EXISTS idx_routing_global_default
    ON escalation_routing_rules (category) WHERE department_id IS NULL;

-- In-app notification feed (drives the Flutter badge counters)
CREATE TABLE IF NOT EXISTS notifications (
    id UUID PRIMARY KEY DEFAULT uuid_generate_v4(),
    recipient_user_id UUID NOT NULL REFERENCES auth_users(id) ON DELETE CASCADE,
    kind VARCHAR(40) NOT NULL,
    title VARCHAR(160) NOT NULL,
    body TEXT,
    deep_link VARCHAR(200),
    escalation_id UUID REFERENCES rag_escalations(id) ON DELETE CASCADE,
    is_read BOOLEAN NOT NULL DEFAULT FALSE,
    created_at TIMESTAMPTZ NOT NULL DEFAULT NOW()
);

CREATE INDEX IF NOT EXISTS idx_notifications_unread
    ON notifications (recipient_user_id, is_read, created_at DESC);

-- ============================================================================
-- 11. updated_at MAINTENANCE
-- Keeping this in the database means no ORM path can forget to bump it.
-- ============================================================================
CREATE OR REPLACE FUNCTION fn_touch_updated_at()
RETURNS TRIGGER AS $$
BEGIN
    NEW.updated_at = NOW();
    RETURN NEW;
END;
$$ LANGUAGE plpgsql;

DO $$
DECLARE
    tbl TEXT;
BEGIN
    FOREACH tbl IN ARRAY ARRAY[
        'auth_users', 'employees', 'hr_contracts', 'payruns',
        'rag_escalations', 'ai_conversations'
    ] LOOP
        EXECUTE format('DROP TRIGGER IF EXISTS trg_touch_%1$s ON %1$s', tbl);
        EXECUTE format(
            'CREATE TRIGGER trg_touch_%1$s BEFORE UPDATE ON %1$s '
            'FOR EACH ROW EXECUTE FUNCTION fn_touch_updated_at()', tbl);
    END LOOP;
END $$;
