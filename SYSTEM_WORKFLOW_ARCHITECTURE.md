# 🔄 PeoplePay360: End-to-End System Workflow & Architecture Guide

> **Purpose**: A clear, comprehensive, and visual explanation of how the entire **PeoplePay360** HR & Payroll ecosystem works from Frontend to Backend, Database, AI Engine, and Async Workers.

---

## 📐 1. Master System Architecture Overview

```mermaid
graph TB
    subgraph Client_Layer ["📱 Client & Multi-Channel Layer"]
        FLUTTER["Flutter Mobile & Web App<br/>(Odoo 18 Glassmorphism UI)"]
        FIELD_BOT["WhatsApp / Telegram Bot<br/>(Deskless Field Workers)"]
    end

    subgraph Gateway_Layer ["🔐 API Gateway & Auth"]
        FASTAPI["FastAPI App Gateway<br/>(Python 3.12)"]
        JWT_AUTH["JWT & RBAC Middleware<br/>(Admin / Payroll / HR / Employee)"]
    end

    subgraph Business_Services ["⚙️ Core Business Micro-Services"]
        USER_SVC["User & Employee Service"]
        ATTEND_SVC["Geofenced Attendance Service"]
        LEAVE_SVC["Time Off & Accrual Engine"]
        PAYROLL_SVC["Payroll & Tax Calculation Engine"]
        AI_AUDIT["AI Payroll Audit Guard<br/>(Anomaly Detection)"]
        RAG_SVC["Self-Learning RAG AI Engine"]
    end

    subgraph Data_Layer ["🗄️ Database & Vector Store"]
        POSTGRES[("PostgreSQL 18 DB<br/>Relational Schema")]
        PGVECTOR[("pgvector 0.8+<br/>HNSW Vector Index (384-dim)")]
        REDIS[("Redis Cache & Task Queue")]
    end

    subgraph Background_Workers ["⚡ Async Workers & Notifications"]
        CELERY["Celery / ARQ Worker<br/>(PDF Generation & SLA Sweeper)"]
        NOTIF_SVC["In-App & WhatsApp Notification Dispatcher"]
    end

    %% Connections
    FLUTTER -->|HTTPS / WSS| FASTAPI
    FIELD_BOT -->|Webhook| FASTAPI

    FASTAPI --> JWT_AUTH
    JWT_AUTH --> USER_SVC
    JWT_AUTH --> ATTEND_SVC
    JWT_AUTH --> LEAVE_SVC
    JWT_AUTH --> PAYROLL_SVC
    JWT_AUTH --> RAG_SVC

    PAYROLL_SVC --> AI_AUDIT

    USER_SVC & ATTEND_SVC & LEAVE_SVC & PAYROLL_SVC --> POSTGRES
    RAG_SVC -->|Semantic Search| PGVECTOR
    RAG_SVC -->|Escalation Tickets| POSTGRES

    PAYROLL_SVC & RAG_SVC -->|Enqueues Tasks| REDIS
    REDIS --> CELERY
    CELERY --> NOTIF_SVC
    NOTIF_SVC -->|Push / Feed| FLUTTER
    NOTIF_SVC -->|WhatsApp API| FIELD_BOT
```

---

## 🛠️ 2. Core End-to-End Workflows

Below are the 4 fundamental workflows that drive the entire application.

---

### 🔑 Workflow A: User Onboarding, Login & Strict RBAC Access

This workflow governs how users enter the system and how security roles restrict features.

```mermaid
sequenceDiagram
    autonumber
    actor Admin as System Administrator
    actor Employee as Employee / User
    participant App as Flutter Client
    participant API as FastAPI Gateway
    participant DB as PostgreSQL DB

    Admin->>App: 1. Fill "Create User Form" (Email, Role, Link Employee)
    App->>API: 2. POST /api/v1/users (Payload + Admin JWT)
    API->>DB: 3. Create `auth_users` & link `employee_id`
    DB-->>API: 4. User Created successfully
    API-->>App: 5. Return success notification

    Employee->>App: 6. Open App & Enter Credentials
    App->>API: 7. POST /api/v1/auth/login
    API->>DB: 8. Verify Hashed Password & Active Status
    DB-->>API: 9. User profile & Role permissions
    API-->>App: 10. Issue Access Token + Refresh Token (JWT)
    App->>App: 11. Render Dashboard tailored to user role (e.g. Employee vs HR Portal)
```

#### Key Rules:
- **Role Scoping**: `ADMIN` sees User Management & Global Configs; `PAYROLL_USER` sees Payruns; `EMPLOYEE` sees only self profile, own attendance, and own payslips.
- **Link Integrity**: Every user account MUST be linked to an `employee` record.

---

### ⏱️ Workflow B: Geofenced Punch-In & Automated Time Off Accrual

How employees record attendance and request time off.

```mermaid
sequenceDiagram
    autonumber
    actor Emp as Employee
    actor Manager as HR / Manager
    participant App as Flutter Mobile App
    participant API as FastAPI Backend
    participant DB as PostgreSQL DB
    participant WS as WebSocket Feed

    rect rgb(240, 248, 255)
        Note over Emp, DB: 📍 Geofenced Attendance Punch-In
        Emp->>App: 1. Tap "Punch In" (Biometric Auth)
        App->>App: 2. Fetch current GPS Coordinates (Lat, Long)
        App->>API: 3. POST /api/v1/attendance/punch-in (GPS + Timestamp)
        API->>API: 4. Check coordinates against Office Geofence Polygon
        alt Inside Geofence
            API->>DB: 5. INSERT into `attendance_records` (Status: PUNCHED_IN)
            API-->>App: 6. 200 OK + Start Dynamic Island Worked Timer
        else Outside Geofence
            API-->>App: 7. 400 Bad Request ("Outside office perimeter")
        end
    end

    rect rgb(255, 245, 240)
        Note over Emp, WS: 🏖️ Time Off Request & Approval
        Emp->>App: 8. Submit Time Off Request (3 days Paid Leave)
        App->>API: 9. POST /api/v1/time-off/requests
        API->>DB: 10. Check leave balance in `employee_leave_balances`
        API->>DB: 11. INSERT `time_off_requests` (Status: SUBMITTED)
        API->>WS: 12. Broadcast Notification to Manager's App
        WS-->>App: 13. Manager receives "New Leave Request" badge

        Manager->>App: 14. Tap "Approve Request"
        App->>API: 15. POST /api/v1/time-off/requests/{id}/approve
        API->>DB: 16. Update status = APPROVED & Deduct Leave Balance
        API-->>Emp: 17. Push Notification: "Leave Request Approved!"
    end
```

---

### 💰 Workflow C: Automated 1-Tap Payroll Batch & AI Audit Guard

How HR processes salary for hundreds of employees safely with zero errors.

```mermaid
sequenceDiagram
    autonumber
    actor HR as Payroll Manager
    participant App as HR Admin Portal
    participant API as FastAPI Backend
    participant Audit as AI Audit Guard
    participant Engine as Salary Calculation Engine
    participant DB as PostgreSQL DB
    participant Worker as Async PDF Worker

    HR->>App: 1. Click "Create Payrun Batch" (Month: August 2026)
    App->>API: 2. POST /api/v1/payruns (Draft State)
    API->>DB: 3. Fetch active Contracts, Attendance, & Approved Leaves

    API->>Audit: 4. Run AI Anomaly Scanner on draft data
    Audit-->>API: 5. Return Anomaly Report (e.g. "Rohan Patel overtime +140%")
    API-->>App: 6. Render Draft Payrun with Anomaly Warning Badges

    HR->>App: 7. Review & Click "Run Payroll Batch"
    App->>API: 8. POST /api/v1/payruns/{id}/compute

    loop For Every Employee Contract
        API->>Engine: 9. Execute Odoo Salary Rules (Basic + Allowances - Deductions - Tax)
        Engine->>DB: 10. Save `payslips` & `payslip_lines`
    end

    API->>Worker: 11. Enqueue PDF Generation Task (Redis Queue)
    Worker->>Worker: 12. Compile Encrypted PDF Payslips
    Worker->>DB: 13. Update `payslip.pdf_url` & Send Notifications

    API-->>App: 14. Payrun Status = DONE (Show Summary Analytics)
```

---

### 🤖 Workflow D: Self-Learning AI Copilot & Human Escalation Loop

This is the **Unfair Advantage Feature**: How AI answers policy questions and automatically learns when stuck.

```mermaid
sequenceDiagram
    autonumber
    actor Emp as Employee
    actor HR as HR Admin
    participant App as Flutter Mobile
    participant API as FastAPI Copilot
    participant VecDB as pgvector (HNSW Index)
    participant DB as PostgreSQL DB

    Emp->>App: 1. Ask: "What is our paternity leave policy?"
    App->>API: 2. POST /api/v1/copilot/chat
    API->>API: 3. Convert question into 384-dim Vector Embedding
    API->>VecDB: 4. Cosine Similarity Search against `document_chunks`
    VecDB-->>API: 5. Top matches score = 0.89 (High Confidence > 0.70)
    API-->>App: 6. Return Verified AI Answer with Source Citation

    rect rgb(255, 235, 235)
        Note over Emp, HR: ⚠️ Low Confidence Fallback & Self-Learning Loop
        Emp->>App: 7. Ask: "Can I get reimbursement for home internet?"
        App->>API: 8. POST /api/v1/copilot/chat
        API->>VecDB: 9. Vector search top score = 0.42 (Low Confidence < 0.70)
        API->>DB: 10. Create Ticket in `rag_escalations` (Status: OPEN, Reason: LOW_CONFIDENCE)
        API-->>App: 11. "I'm not 100% sure. I've escalated this to HR (Ticket #ESC-1042)."

        HR->>App: 12. Opens HR Escalations Inbox & views Ticket #ESC-1042
        HR->>App: 13. Types Official Answer: "Yes, up to $50/mo with receipt."
        HR->>App: 14. Check "Publish to Knowledge Base" & click Submit
        App->>API: 15. POST /api/v1/escalations/{id}/answer (publish_to_kb = true)

        API->>VecDB: 16. Vectorize HR's answer & insert into `document_chunks`
        API->>DB: 17. Mark Escalation Ticket = ANSWERED
        API-->>Emp: 18. Push Notification: "HR answered your question #ESC-1042!"
    end
```

---

## 🏛️ 3. Layer-by-Layer Responsibilities

| Layer | Technologies | Responsibilities |
| :--- | :--- | :--- |
| **Frontend UI** | Flutter 3.24 (Dart) | Glassmorphic UI, Dynamic Island Header, Smart Button Stat Counters, Geofence Map, Interactive Payslip Dialog |
| **API Gateway** | FastAPI (Python 3.12) | Route handling, JWT verification, Pydantic request validation, Swagger docs |
| **Domain Services** | Python Business Modules | Attendance calculation, Salary rule evaluation, Accrual engine, Copilot Orchestration |
| **AI / RAG Engine** | `sentence-transformers` + `pgvector` | 384-dimensional embedding creation, HNSW cosine similarity search, Escalation routing |
| **Primary Database** | PostgreSQL 18 | Relational integrity, FK cascades, check constraints, indexed audit trail |
| **Async Task Worker**| Redis + Celery / ARQ | Background PDF compilation, SLA breach sweeper, Email/WhatsApp dispatches |

---

## 🎯 4. Why This Architecture Wins

1. **Zero Hallucination AI Guarantee**: Low confidence questions are never answered blindly—they are escalated to human HR.
2. **Self-Improving System**: Every answered escalation ticket feeds back into `pgvector` to make the bot smarter.
3. **Strict Audit Trail**: Every payrun step and escalation status change is immutably logged with timestamp and user ID.
4. **Resilient Field Access**: Field workers can interact via WhatsApp bot, while office workers use the high-performance Flutter app.
