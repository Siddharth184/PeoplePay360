"""Human-in-the-Loop Escalation Loop (architecture section 4.1).

The four stages:
  1. DETECT - the confidence gate in `copilot_service` refuses to answer.
  2. ROUTE  - semantic dedup first, then category -> owning role -> SLA clock.
  3. ANSWER - a human replies; the employee is notified.
  4. LEARN  - the verified answer is embedded into `document_chunks`, so the
              assistant answers the same question itself next time. No training.
"""

from __future__ import annotations

import uuid
from datetime import datetime, timedelta, timezone
from decimal import Decimal
from typing import Any, Dict, List, Optional, Sequence

from sqlalchemy import text
from sqlalchemy.orm import Session

from app.core.config import settings
from app.core.errors import ConflictError, ForbiddenError, NotFoundError, ValidationError
from app.services.embedding import embed_query
from app.services.rag_service import (
    _vector_literal,
    store_verified_answer,
)
from app.services.reference import next_escalation_reference

# Tuned on the golden question set. Below this, retrieval is not trustworthy.
CONFIDENCE_THRESHOLD = settings.rag_confidence_threshold
# Above this, two questions are semantically the same question.
DEDUP_THRESHOLD = settings.rag_dedup_threshold
# Anti-spam: an employee may not hold more than this many live tickets.
MAX_OPEN_TICKETS_PER_EMPLOYEE = settings.max_open_tickets_per_employee

LIVE_STATUSES = ("OPEN", "ASSIGNED")

# Safe fallback route so a question is never dropped on the floor.
DEFAULT_ROUTE = {"target_role": "ADMIN", "sla_hours": 24, "priority": "NORMAL"}


# ---------------------------------------------------------------------------
# STAGE 1/2: CLASSIFY
# ---------------------------------------------------------------------------
def classify_category(question: str) -> str:
    """Lightweight deterministic categoriser.

    Runs BEFORE any LLM call so routing still works when the model is offline.
    """
    q = (question or "").lower()
    if any(
        k in q
        for k in ("leave", "time off", "vacation", "holiday", "allocation", "pto", "sabbatical")
    ):
        return "LEAVE_POLICY"
    if any(
        k in q
        for k in ("salary", "payslip", "payroll", "wage", "deduction", "pf", "bonus", "net pay", "reimburse")
    ):
        return "PAYROLL_SALARY"
    if any(
        k in q
        for k in ("attendance", "check in", "check out", "overtime", "punch", "late", "shift")
    ):
        return "ATTENDANCE"
    if any(
        k in q for k in ("contract", "notice period", "probation", "appraisal", "resign")
    ):
        return "CONTRACT"
    if any(
        k in q
        for k in ("tax", "tds", "professional tax", "esic", "form 16", "statutory", "gratuity")
    ):
        return "TAX_STATUTORY"
    if any(
        k in q for k in ("login", "password", "access", "permission", "account locked", "2fa")
    ):
        return "IT_ACCESS"
    return "OTHER"


# ---------------------------------------------------------------------------
# STAGE 2: SEMANTIC DEDUP SHORT-CIRCUIT
# ---------------------------------------------------------------------------
def find_previously_answered(
    db: Session, question_embedding: Sequence[float]
) -> Optional[Dict[str, Any]]:
    """Before bothering a human, check whether one already answered this.

    Costs one index scan and eliminates most duplicate tickets.
    """
    row = db.execute(
        text(
            """
            SELECT e.id, e.ticket_no, e.answer_text, e.answered_at,
                   u.email AS answered_by_email,
                   (1 - (e.question_embedding <=> CAST(:emb AS vector))) AS similarity
            FROM rag_escalations e
            LEFT JOIN auth_users u ON u.id = e.answered_by_user_id
            WHERE e.status IN ('ANSWERED', 'CLOSED')
              AND e.answer_text IS NOT NULL
              AND e.question_embedding IS NOT NULL
            ORDER BY e.question_embedding <=> CAST(:emb AS vector)
            LIMIT 1
            """
        ),
        {"emb": _vector_literal(question_embedding)},
    ).fetchone()

    if row and float(row.similarity) >= DEDUP_THRESHOLD:
        return {
            "escalation_id": str(row.id),
            "ticket_no": row.ticket_no,
            "answer_text": row.answer_text,
            "answered_at": row.answered_at,
            "answered_by": row.answered_by_email,
            "similarity": float(row.similarity),
        }
    return None


# ---------------------------------------------------------------------------
# STAGE 2: ROUTING
# ---------------------------------------------------------------------------
def resolve_route(
    db: Session, category: str, department_id: Optional[str]
) -> Dict[str, Any]:
    """Who owns this category and what is the SLA?

    A department-specific rule wins over the global default.
    """
    row = db.execute(
        text(
            """
            SELECT target_role, sla_hours, priority
            FROM escalation_routing_rules
            WHERE category = CAST(:cat AS escalation_category_enum)
              AND is_active = TRUE
              AND (department_id = CAST(:dept AS uuid) OR department_id IS NULL)
            ORDER BY department_id NULLS LAST, sequence ASC
            LIMIT 1
            """
        ),
        {"cat": category, "dept": department_id},
    ).fetchone()

    if not row:
        return dict(DEFAULT_ROUTE)
    return {
        "target_role": str(row.target_role),
        "sla_hours": int(row.sla_hours),
        "priority": str(row.priority),
    }


def _record_event(
    db: Session,
    escalation_id: uuid.UUID | str,
    actor_user_id: uuid.UUID | str | None,
    event_type: str,
    body: str | None,
    visibility: str = "PUBLIC",
) -> None:
    db.execute(
        text(
            """
            INSERT INTO rag_escalation_events
                (escalation_id, actor_user_id, event_type, body, visibility)
            VALUES (:esc, :actor, :etype, :body, :vis)
            """
        ),
        {
            "esc": str(escalation_id),
            "actor": str(actor_user_id) if actor_user_id else None,
            "etype": event_type,
            "body": body,
            "vis": visibility,
        },
    )


# ---------------------------------------------------------------------------
# STAGE 1 + 2: CREATE
# ---------------------------------------------------------------------------
def create_escalation(
    db: Session,
    employee_id: uuid.UUID | str,
    asked_by_user_id: uuid.UUID | str,
    question_text: str,
    reason: str,
    retrieval_confidence: Optional[float] = None,
    ai_draft_answer: Optional[str] = None,
    conversation_id: Optional[str] = None,
    source_message_id: Optional[str] = None,
) -> Dict[str, Any]:
    """Create the ticket, auto-route it, start the SLA clock, notify responders.

    Semantically duplicate questions short-circuit and return the existing human
    answer instantly instead of opening a second ticket.
    """
    if not (question_text or "").strip():
        raise ValidationError("A question is required to open an escalation.")

    # --- Anti-spam guard ----------------------------------------------------
    open_count = db.execute(
        text(
            """
            SELECT COUNT(*) FROM rag_escalations
            WHERE employee_id = :emp AND status IN ('OPEN', 'ASSIGNED')
            """
        ),
        {"emp": str(employee_id)},
    ).scalar_one()

    if open_count >= MAX_OPEN_TICKETS_PER_EMPLOYEE:
        raise ConflictError(
            f"You already have {open_count} open questions with HR. "
            "Please wait for a reply before submitting another."
        )

    # Question-to-question comparison, so both sides use the query embedding
    # space. Mixing query and document embeddings would make the dedup
    # similarity meaningless.
    question_embedding = embed_query(question_text)

    # --- Stage 2 short-circuit: reuse an existing human answer --------------
    prior = find_previously_answered(db, question_embedding)
    if prior:
        return {
            "escalated": False,
            "reused_prior_answer": True,
            "answer": prior["answer_text"],
            "source": f"Previously answered by HR (ticket {prior['ticket_no']})",
            "similarity": round(prior["similarity"], 3),
            "ticket_no": prior["ticket_no"],
        }

    # --- Route + SLA -------------------------------------------------------
    category = classify_category(question_text)
    dept_id = db.execute(
        text("SELECT department_id FROM employees WHERE id = :id"),
        {"id": str(employee_id)},
    ).scalar()
    route = resolve_route(db, category, str(dept_id) if dept_id else None)

    ticket_no = next_escalation_reference(db)
    sla_due_at = datetime.now(timezone.utc) + timedelta(hours=route["sla_hours"])

    escalation_id = db.execute(
        text(
            """
            INSERT INTO rag_escalations (
                ticket_no, conversation_id, source_message_id, employee_id,
                asked_by_user_id, question_text, question_embedding, category,
                escalation_reason, retrieval_confidence, ai_draft_answer,
                status, priority, sla_due_at
            ) VALUES (
                :ticket_no, CAST(:conv AS uuid), CAST(:msg AS uuid), :emp,
                :user, :q, CAST(:emb AS vector),
                CAST(:cat AS escalation_category_enum),
                :reason, :conf, :draft,
                'OPEN', CAST(:prio AS escalation_priority_enum), :sla
            ) RETURNING id
            """
        ),
        {
            "ticket_no": ticket_no,
            "conv": conversation_id,
            "msg": source_message_id,
            "emp": str(employee_id),
            "user": str(asked_by_user_id),
            "q": question_text,
            "emb": _vector_literal(question_embedding),
            "cat": category,
            "reason": reason,
            "conf": Decimal(str(round(retrieval_confidence, 3)))
            if retrieval_confidence is not None
            else None,
            "draft": ai_draft_answer,
            "prio": route["priority"],
            "sla": sla_due_at,
        },
    ).scalar_one()

    # --- Audit trail -------------------------------------------------------
    _record_event(
        db,
        escalation_id,
        asked_by_user_id,
        "CREATED",
        f"Auto-escalated ({reason}); retrieval confidence "
        f"{round(retrieval_confidence, 3) if retrieval_confidence is not None else 'n/a'}",
    )

    # --- Notify every responder holding the owning role --------------------
    db.execute(
        text(
            """
            INSERT INTO notifications
                (recipient_user_id, kind, title, body, deep_link, escalation_id)
            SELECT u.id, 'ESCALATION_NEW', :title, :body, :link, :esc
            FROM auth_users u
            WHERE u.is_active = TRUE
              AND (u.role = CAST(:target_role AS user_role_enum)
                   OR u.role = 'ADMIN')
            """
        ),
        {
            "title": f"New HR question needs your answer ({ticket_no})",
            "body": question_text[:200],
            "link": f"/copilot/escalations/{escalation_id}",
            "esc": str(escalation_id),
            "target_role": route["target_role"],
        },
    )

    db.commit()

    return {
        "escalated": True,
        "reused_prior_answer": False,
        "escalation_id": str(escalation_id),
        "ticket_no": ticket_no,
        "category": category,
        "routed_to_role": route["target_role"],
        "sla_due_at": sla_due_at.isoformat(),
        "message": (
            f"I don't have a verified answer for that, so I've forwarded it to your "
            f"HR team as ticket {ticket_no}. You'll be notified as soon as they reply."
        ),
    }


# ---------------------------------------------------------------------------
# READ SIDE (with row scoping)
# ---------------------------------------------------------------------------
def _row_to_ticket(row: Any) -> Dict[str, Any]:
    return {
        "id": str(row.id),
        "ticket_no": row.ticket_no,
        "employee_id": str(row.employee_id),
        "employee_name": row.employee_name,
        "employee_badge": row.employee_badge,
        "question_text": row.question_text,
        "category": str(row.category),
        "escalation_reason": row.escalation_reason,
        "retrieval_confidence": (
            float(row.retrieval_confidence)
            if row.retrieval_confidence is not None
            else None
        ),
        "ai_draft_answer": row.ai_draft_answer,
        "status": str(row.status),
        "priority": str(row.priority),
        "assigned_to_user_id": str(row.assigned_to_user_id)
        if row.assigned_to_user_id
        else None,
        "assigned_to_email": row.assigned_to_email,
        "answer_text": row.answer_text,
        "answered_by_email": row.answered_by_email,
        "answered_at": row.answered_at,
        "sla_due_at": row.sla_due_at,
        "first_response_at": row.first_response_at,
        "is_overdue": bool(row.is_overdue),
        "publish_to_kb": row.publish_to_kb,
        "kb_chunk_id": str(row.kb_chunk_id) if row.kb_chunk_id else None,
        "conversation_id": str(row.conversation_id) if row.conversation_id else None,
        "created_at": row.created_at,
        "updated_at": row.updated_at,
    }


_TICKET_SELECT = """
    SELECT e.*, emp.name AS employee_name, emp.badge_id AS employee_badge,
           assignee.email AS assigned_to_email,
           responder.email AS answered_by_email,
           (e.status IN ('OPEN', 'ASSIGNED') AND e.sla_due_at < NOW()) AS is_overdue
    FROM rag_escalations e
    JOIN employees emp ON emp.id = e.employee_id
    LEFT JOIN auth_users assignee ON assignee.id = e.assigned_to_user_id
    LEFT JOIN auth_users responder ON responder.id = e.answered_by_user_id
"""


def list_escalations(
    db: Session,
    *,
    scope_employee_id: uuid.UUID | str | None = None,
    status: str | None = None,
    category: str | None = None,
    priority: str | None = None,
    assignee_user_id: uuid.UUID | str | None = None,
    overdue: bool = False,
    limit: int = 50,
    offset: int = 0,
) -> Dict[str, Any]:
    """`scope_employee_id` is the row-scoping lever for the EMPLOYEE role."""
    where: List[str] = ["TRUE"]
    params: Dict[str, Any] = {"limit": limit, "offset": offset}

    if scope_employee_id is not None:
        where.append("e.employee_id = CAST(:scope_emp AS uuid)")
        params["scope_emp"] = str(scope_employee_id)
    if status:
        where.append("e.status = CAST(:status AS escalation_status_enum)")
        params["status"] = status
    if category:
        where.append("e.category = CAST(:category AS escalation_category_enum)")
        params["category"] = category
    if priority:
        where.append("e.priority = CAST(:priority AS escalation_priority_enum)")
        params["priority"] = priority
    if assignee_user_id:
        where.append("e.assigned_to_user_id = CAST(:assignee AS uuid)")
        params["assignee"] = str(assignee_user_id)
    if overdue:
        where.append("e.status IN ('OPEN', 'ASSIGNED') AND e.sla_due_at < NOW()")

    clause = " AND ".join(where)
    total = db.execute(
        text(f"SELECT COUNT(*) FROM rag_escalations e WHERE {clause}"), params
    ).scalar_one()

    rows = db.execute(
        text(
            f"""
            {_TICKET_SELECT}
            WHERE {clause}
            ORDER BY e.priority DESC, e.created_at ASC
            LIMIT :limit OFFSET :offset
            """
        ),
        params,
    ).fetchall()

    return {
        "total": total,
        "limit": limit,
        "offset": offset,
        "items": [_row_to_ticket(r) for r in rows],
    }


def get_escalation(
    db: Session,
    escalation_id: uuid.UUID | str,
    *,
    requester_employee_id: uuid.UUID | str | None = None,
    include_internal: bool = False,
) -> Dict[str, Any]:
    """Ticket detail + threaded events.

    INTERNAL events are stripped for the asking employee - enforced here in the
    repository layer, never left to the client.
    """
    row = db.execute(
        text(f"{_TICKET_SELECT} WHERE e.id = CAST(:esc AS uuid)"),
        {"esc": str(escalation_id)},
    ).fetchone()
    if not row:
        raise NotFoundError("Escalation ticket not found.")

    if requester_employee_id is not None and str(row.employee_id) != str(
        requester_employee_id
    ):
        raise ForbiddenError("You may only view your own escalation tickets.")

    visibility_clause = "" if include_internal else "AND ev.visibility = 'PUBLIC'"
    events = db.execute(
        text(
            f"""
            SELECT ev.id, ev.event_type, ev.body, ev.visibility, ev.created_at,
                   u.email AS actor_email, u.role AS actor_role
            FROM rag_escalation_events ev
            LEFT JOIN auth_users u ON u.id = ev.actor_user_id
            WHERE ev.escalation_id = CAST(:esc AS uuid) {visibility_clause}
            ORDER BY ev.created_at ASC
            """
        ),
        {"esc": str(escalation_id)},
    ).fetchall()

    ticket = _row_to_ticket(row)
    ticket["events"] = [
        {
            "id": str(e.id),
            "event_type": e.event_type,
            "body": e.body,
            "visibility": e.visibility,
            "actor_email": e.actor_email,
            "actor_role": str(e.actor_role) if e.actor_role else None,
            "created_at": e.created_at,
        }
        for e in events
    ]
    return ticket


# ---------------------------------------------------------------------------
# STAGE 3: TRIAGE AND ANSWER
# ---------------------------------------------------------------------------
def assign_escalation(
    db: Session,
    escalation_id: uuid.UUID | str,
    assignee_user_id: uuid.UUID | str,
    actor_user_id: uuid.UUID | str,
) -> Dict[str, Any]:
    """Triage: claim or delegate a ticket. Records first_response_at for SLA."""
    current = db.execute(
        text("SELECT status, assigned_to_user_id FROM rag_escalations WHERE id = CAST(:esc AS uuid) FOR UPDATE"),
        {"esc": str(escalation_id)},
    ).fetchone()
    if not current:
        raise NotFoundError("Escalation ticket not found.")
    if str(current.status) not in LIVE_STATUSES:
        raise ConflictError(
            f"Cannot assign a ticket in status '{current.status}'."
        )
    if not db.execute(
        text("SELECT 1 FROM auth_users WHERE id = CAST(:u AS uuid) AND is_active"),
        {"u": str(assignee_user_id)},
    ).fetchone():
        raise NotFoundError("Assignee user not found or inactive.")

    reassignment = current.assigned_to_user_id is not None

    db.execute(
        text(
            """
            UPDATE rag_escalations
            SET status = 'ASSIGNED',
                assigned_to_user_id = CAST(:assignee AS uuid),
                assigned_at = NOW(),
                first_response_at = COALESCE(first_response_at, NOW()),
                updated_at = NOW()
            WHERE id = CAST(:esc AS uuid) AND status IN ('OPEN', 'ASSIGNED')
            """
        ),
        {"assignee": str(assignee_user_id), "esc": str(escalation_id)},
    )

    _record_event(
        db,
        escalation_id,
        actor_user_id,
        "REASSIGNED" if reassignment else "ASSIGNED",
        "Ticket assigned for response.",
        visibility="INTERNAL",
    )
    db.commit()
    return {"escalation_id": str(escalation_id), "status": "ASSIGNED"}


def answer_escalation(
    db: Session,
    escalation_id: uuid.UUID | str,
    responder_user_id: uuid.UUID | str,
    answer_text: str,
    publish_to_kb: bool = True,
) -> Dict[str, Any]:
    """STAGE 3: a human replies directly to the employee.

    STAGE 4: if `publish_to_kb`, the Q&A pair is embedded into `document_chunks`
    so the Copilot answers this question itself from now on. No model training.
    """
    if not (answer_text or "").strip():
        raise ValidationError("An answer body is required.")

    row = db.execute(
        text(
            """
            SELECT ticket_no, question_text, asked_by_user_id, category, status
            FROM rag_escalations WHERE id = CAST(:esc AS uuid) FOR UPDATE
            """
        ),
        {"esc": str(escalation_id)},
    ).fetchone()

    if not row:
        raise NotFoundError("Escalation ticket not found.")
    if str(row.status) in ("CLOSED", "REJECTED"):
        raise ConflictError(f"Cannot answer a ticket in status '{row.status}'.")

    kb_chunk_id = None

    # ---- STAGE 4: KNOWLEDGE FLYWHEEL -------------------------------------
    if publish_to_kb:
        kb_chunk_id = store_verified_answer(
            db,
            question=row.question_text,
            answer=answer_text,
            title=f"HR Answer - {row.ticket_no}",
            metadata={
                "source": "escalation",
                "ticket_no": row.ticket_no,
                "category": str(row.category),
            },
        )

    db.execute(
        text(
            """
            UPDATE rag_escalations
            SET status = 'ANSWERED',
                answer_text = :ans,
                answered_by_user_id = CAST(:responder AS uuid),
                answered_at = NOW(),
                first_response_at = COALESCE(first_response_at, NOW()),
                publish_to_kb = :pub,
                kb_chunk_id = CAST(:chunk AS uuid),
                updated_at = NOW()
            WHERE id = CAST(:esc AS uuid)
            """
        ),
        {
            "ans": answer_text,
            "responder": str(responder_user_id),
            "pub": publish_to_kb,
            "chunk": str(kb_chunk_id) if kb_chunk_id else None,
            "esc": str(escalation_id),
        },
    )

    _record_event(db, escalation_id, responder_user_id, "ANSWERED", answer_text)

    if kb_chunk_id:
        _record_event(
            db,
            escalation_id,
            responder_user_id,
            "PUBLISHED_TO_KB",
            "Answer indexed into the knowledge base; the assistant can now answer "
            "this directly.",
            visibility="INTERNAL",
        )

    # ---- Notify the employee who asked -----------------------------------
    db.execute(
        text(
            """
            INSERT INTO notifications
                (recipient_user_id, kind, title, body, deep_link, escalation_id)
            VALUES (CAST(:user AS uuid), 'ESCALATION_ANSWERED', :title, :body,
                    :link, CAST(:esc AS uuid))
            """
        ),
        {
            "user": str(row.asked_by_user_id),
            "title": f"HR answered your question ({row.ticket_no})",
            "body": answer_text[:200],
            "link": f"/copilot/escalations/{escalation_id}",
            "esc": str(escalation_id),
        },
    )

    db.commit()

    return {
        "escalation_id": str(escalation_id),
        "ticket_no": row.ticket_no,
        "status": "ANSWERED",
        "published_to_kb": bool(kb_chunk_id),
        "kb_chunk_id": str(kb_chunk_id) if kb_chunk_id else None,
    }


def comment_on_escalation(
    db: Session,
    escalation_id: uuid.UUID | str,
    actor_user_id: uuid.UUID | str,
    body: str,
    visibility: str = "INTERNAL",
) -> Dict[str, Any]:
    if visibility not in ("PUBLIC", "INTERNAL"):
        raise ValidationError("visibility must be PUBLIC or INTERNAL.")
    if not db.execute(
        text("SELECT 1 FROM rag_escalations WHERE id = CAST(:esc AS uuid)"),
        {"esc": str(escalation_id)},
    ).fetchone():
        raise NotFoundError("Escalation ticket not found.")

    _record_event(db, escalation_id, actor_user_id, "COMMENTED", body, visibility)
    db.commit()
    return {"escalation_id": str(escalation_id), "visibility": visibility}


def _transition(
    db: Session,
    escalation_id: uuid.UUID | str,
    actor_user_id: uuid.UUID | str,
    new_status: str,
    event_type: str,
    note: str,
    *,
    allowed_from: Sequence[str],
) -> Dict[str, Any]:
    row = db.execute(
        text("SELECT status FROM rag_escalations WHERE id = CAST(:esc AS uuid) FOR UPDATE"),
        {"esc": str(escalation_id)},
    ).fetchone()
    if not row:
        raise NotFoundError("Escalation ticket not found.")
    if str(row.status) not in allowed_from:
        raise ConflictError(
            f"Cannot move a ticket from '{row.status}' to '{new_status}'."
        )

    db.execute(
        text(
            """
            UPDATE rag_escalations
            SET status = CAST(:status AS escalation_status_enum), updated_at = NOW()
            WHERE id = CAST(:esc AS uuid)
            """
        ),
        {"status": new_status, "esc": str(escalation_id)},
    )
    _record_event(db, escalation_id, actor_user_id, event_type, note)
    db.commit()
    return {"escalation_id": str(escalation_id), "status": new_status}


def close_escalation(db, escalation_id, actor_user_id, note="Loop closed."):
    return _transition(
        db,
        escalation_id,
        actor_user_id,
        "CLOSED",
        "CLOSED",
        note,
        allowed_from=("ANSWERED", "OPEN", "ASSIGNED"),
    )


def reopen_escalation(db, escalation_id, actor_user_id, note="Answer was insufficient."):
    return _transition(
        db,
        escalation_id,
        actor_user_id,
        "OPEN",
        "REOPENED",
        note,
        allowed_from=("ANSWERED", "CLOSED"),
    )


def reject_escalation(db, escalation_id, actor_user_id, note="Out of scope."):
    return _transition(
        db,
        escalation_id,
        actor_user_id,
        "REJECTED",
        "REJECTED",
        note,
        allowed_from=("OPEN", "ASSIGNED"),
    )


# ---------------------------------------------------------------------------
# SLA SWEEP + STATS
# ---------------------------------------------------------------------------
def sla_breach_sweep(db: Session) -> Dict[str, int]:
    """Scheduled job (cron / Celery beat, every 15 min).

    Escalates priority and pings admins about tickets past their SLA. Uses the
    partial index `idx_escalations_overdue`, and the NOT EXISTS guard makes it
    idempotent so repeated runs do not spam the same admin.
    """
    notified = db.execute(
        text(
            """
            INSERT INTO notifications
                (recipient_user_id, kind, title, body, deep_link, escalation_id)
            SELECT u.id, 'ESCALATION_OVERDUE',
                   'Overdue HR question: ' || e.ticket_no,
                   LEFT(e.question_text, 200),
                   '/copilot/escalations/' || e.id, e.id
            FROM rag_escalations e
            CROSS JOIN auth_users u
            WHERE e.status IN ('OPEN', 'ASSIGNED')
              AND e.sla_due_at < NOW()
              AND u.role = 'ADMIN' AND u.is_active = TRUE
              AND NOT EXISTS (
                  SELECT 1 FROM notifications n
                  WHERE n.escalation_id = e.id AND n.kind = 'ESCALATION_OVERDUE'
                    AND n.recipient_user_id = u.id
              )
            """
        )
    ).rowcount

    escalated = db.execute(
        text(
            """
            UPDATE rag_escalations SET priority = 'URGENT', updated_at = NOW()
            WHERE status IN ('OPEN', 'ASSIGNED')
              AND sla_due_at < NOW() AND priority <> 'URGENT'
            """
        )
    ).rowcount

    db.commit()
    return {
        "notifications_created": notified or 0,
        "tickets_escalated_to_urgent": escalated or 0,
    }


def escalation_stats(db: Session) -> Dict[str, Any]:
    row = db.execute(
        text(
            """
            SELECT
                COUNT(*) FILTER (WHERE status = 'OPEN') AS open_count,
                COUNT(*) FILTER (WHERE status = 'ASSIGNED') AS assigned_count,
                COUNT(*) FILTER (WHERE status = 'ANSWERED') AS answered_count,
                COUNT(*) FILTER (WHERE status = 'CLOSED') AS closed_count,
                COUNT(*) FILTER (
                    WHERE status IN ('OPEN', 'ASSIGNED') AND sla_due_at < NOW()
                ) AS overdue_count,
                COUNT(*) FILTER (WHERE kb_chunk_id IS NOT NULL) AS kb_articles_created,
                COUNT(*) AS total_count,
                PERCENTILE_CONT(0.5) WITHIN GROUP (
                    ORDER BY EXTRACT(EPOCH FROM (first_response_at - created_at)) / 60
                ) AS median_first_response_minutes
            FROM rag_escalations
            """
        )
    ).one()

    by_category = db.execute(
        text(
            """
            SELECT category, COUNT(*) AS count
            FROM rag_escalations GROUP BY category ORDER BY count DESC
            """
        )
    ).fetchall()

    by_reason = db.execute(
        text(
            """
            SELECT escalation_reason, COUNT(*) AS count
            FROM rag_escalations GROUP BY escalation_reason ORDER BY count DESC
            """
        )
    ).fetchall()

    return {
        "open_count": row.open_count,
        "assigned_count": row.assigned_count,
        "answered_count": row.answered_count,
        "closed_count": row.closed_count,
        "overdue_count": row.overdue_count,
        "kb_articles_created": row.kb_articles_created,
        "total_count": row.total_count,
        "median_first_response_minutes": (
            round(float(row.median_first_response_minutes), 1)
            if row.median_first_response_minutes is not None
            else None
        ),
        "by_category": {str(r.category): r.count for r in by_category},
        "by_reason": {r.escalation_reason: r.count for r in by_reason},
    }


# ---------------------------------------------------------------------------
# ROUTING RULE ADMINISTRATION
# ---------------------------------------------------------------------------
def list_routing_rules(db: Session) -> List[Dict[str, Any]]:
    rows = db.execute(
        text(
            """
            SELECT r.id, r.category, r.target_role, r.department_id, d.name AS department_name,
                   r.sla_hours, r.priority, r.sequence, r.is_active
            FROM escalation_routing_rules r
            LEFT JOIN departments d ON d.id = r.department_id
            ORDER BY r.category, r.sequence
            """
        )
    ).fetchall()
    return [
        {
            "id": str(r.id),
            "category": str(r.category),
            "target_role": str(r.target_role),
            "department_id": str(r.department_id) if r.department_id else None,
            "department_name": r.department_name,
            "sla_hours": r.sla_hours,
            "priority": str(r.priority),
            "sequence": r.sequence,
            "is_active": r.is_active,
        }
        for r in rows
    ]


def update_routing_rule(
    db: Session,
    rule_id: uuid.UUID | str,
    *,
    target_role: str | None = None,
    sla_hours: int | None = None,
    priority: str | None = None,
    sequence: int | None = None,
    is_active: bool | None = None,
) -> Dict[str, Any]:
    if sla_hours is not None and sla_hours <= 0:
        raise ValidationError("sla_hours must be greater than zero.")

    sets: List[str] = []
    params: Dict[str, Any] = {"id": str(rule_id)}
    if target_role is not None:
        sets.append("target_role = CAST(:role AS user_role_enum)")
        params["role"] = target_role
    if sla_hours is not None:
        sets.append("sla_hours = :sla")
        params["sla"] = sla_hours
    if priority is not None:
        sets.append("priority = CAST(:prio AS escalation_priority_enum)")
        params["prio"] = priority
    if sequence is not None:
        sets.append("sequence = :seq")
        params["seq"] = sequence
    if is_active is not None:
        sets.append("is_active = :active")
        params["active"] = is_active

    if not sets:
        raise ValidationError("No routing fields supplied to update.")

    updated = db.execute(
        text(
            f"UPDATE escalation_routing_rules SET {', '.join(sets)} "
            "WHERE id = CAST(:id AS uuid) RETURNING id"
        ),
        params,
    ).fetchone()
    if not updated:
        raise NotFoundError("Routing rule not found.")
    db.commit()

    rule = next(
        (r for r in list_routing_rules(db) if r["id"] == str(rule_id)), None
    )
    if rule is None:  # pragma: no cover - the row was just updated
        raise NotFoundError("Routing rule not found after update.")
    return rule
