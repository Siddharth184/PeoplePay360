"""The single entry point for POST /api/v1/ai/assistant.

The four-tier degradation ladder, in order:

    TIER 0  Structured question  -> SQL + template        -> NO LLM. Exact. Local.
    TIER 1  Retrieval (ALWAYS)   -> local embed + pgvector -> CPU. Free.
    TIER 2  Phrasing             -> LLMProvider            -> hosted free tier.
    TIER 3  Provider unavailable -> ExtractiveProvider     -> verbatim + cited.

Combined with the escalation loop, there is no input for which this produces a
broken response: it either answers from SQL, answers from retrieval, quotes the
source verbatim, or routes to a human. It never guesses.
"""

from __future__ import annotations

import logging
import uuid
from decimal import Decimal
from typing import Any, Dict, List

from sqlalchemy import text
from sqlalchemy.orm import Session

from app.core.config import settings
from app.core.errors import ValidationError
from app.models.enums import CopilotMode
from app.services.copilot_templates import answer_tier0
from app.services.escalation_service import CONFIDENCE_THRESHOLD, create_escalation
from app.services.llm_provider import get_llm_provider, redact_pii
from app.services.rag_service import (
    build_grounded_prompt,
    log_retrieval,
    semantic_search_policies,
)

logger = logging.getLogger(__name__)


# ---------------------------------------------------------------------------
# CONVERSATION TRANSCRIPT
# ---------------------------------------------------------------------------
def ensure_conversation(
    db: Session,
    user_id: uuid.UUID | str,
    employee_id: uuid.UUID | str | None,
    conversation_id: str | None,
    first_prompt: str,
) -> uuid.UUID:
    if conversation_id:
        owner = db.execute(
            text("SELECT user_id FROM ai_conversations WHERE id = CAST(:cid AS uuid)"),
            {"cid": str(conversation_id)},
        ).fetchone()
        if owner and str(owner.user_id) == str(user_id):
            return uuid.UUID(str(conversation_id))
        # Unknown or someone else's thread: start a fresh one rather than leak.
        logger.info("Ignoring unusable conversation_id %s; opening a new thread.", conversation_id)

    title = (first_prompt or "New conversation").strip()[:157]
    return db.execute(
        text(
            """
            INSERT INTO ai_conversations (user_id, employee_id, title)
            VALUES (CAST(:u AS uuid), CAST(:e AS uuid), :title)
            RETURNING id
            """
        ),
        {
            "u": str(user_id),
            "e": str(employee_id) if employee_id else None,
            "title": title or "New conversation",
        },
    ).scalar_one()


def _add_message(
    db: Session,
    conversation_id: uuid.UUID,
    role: str,
    content: str,
    *,
    mode: str | None = None,
    confidence: float | None = None,
    citations: List[Dict[str, Any]] | None = None,
) -> uuid.UUID:
    import json

    return db.execute(
        text(
            """
            INSERT INTO ai_messages
                (conversation_id, role, content, mode, confidence, citations)
            VALUES (:cid, :role, :content, :mode, :conf, CAST(:cites AS jsonb))
            RETURNING id
            """
        ),
        {
            "cid": str(conversation_id),
            "role": role,
            "content": content,
            "mode": mode,
            "conf": Decimal(str(round(confidence, 3))) if confidence is not None else None,
            "cites": json.dumps(citations or []),
        },
    ).scalar_one()


def get_conversation(
    db: Session, conversation_id: uuid.UUID | str, user_id: uuid.UUID | str
) -> Dict[str, Any]:
    convo = db.execute(
        text(
            """
            SELECT id, title, created_at, updated_at, user_id
            FROM ai_conversations WHERE id = CAST(:cid AS uuid)
            """
        ),
        {"cid": str(conversation_id)},
    ).fetchone()
    if not convo or str(convo.user_id) != str(user_id):
        from app.core.errors import NotFoundError

        raise NotFoundError("Conversation not found.")

    messages = db.execute(
        text(
            """
            SELECT id, role, content, mode, confidence, citations, created_at
            FROM ai_messages WHERE conversation_id = CAST(:cid AS uuid)
            ORDER BY created_at ASC
            """
        ),
        {"cid": str(conversation_id)},
    ).fetchall()

    return {
        "id": str(convo.id),
        "title": convo.title,
        "created_at": convo.created_at,
        "updated_at": convo.updated_at,
        "messages": [
            {
                "id": str(m.id),
                "role": m.role,
                "content": m.content,
                "mode": m.mode,
                "confidence": float(m.confidence) if m.confidence is not None else None,
                "citations": m.citations or [],
                "created_at": m.created_at,
            }
            for m in messages
        ],
    }


def list_conversations(
    db: Session, user_id: uuid.UUID | str, limit: int = 20
) -> List[Dict[str, Any]]:
    rows = db.execute(
        text(
            """
            SELECT c.id, c.title, c.updated_at,
                   (SELECT COUNT(*) FROM ai_messages m WHERE m.conversation_id = c.id)
                       AS message_count
            FROM ai_conversations c
            WHERE c.user_id = CAST(:u AS uuid)
            ORDER BY c.updated_at DESC
            LIMIT :limit
            """
        ),
        {"u": str(user_id), "limit": limit},
    ).fetchall()
    return [
        {
            "id": str(r.id),
            "title": r.title,
            "updated_at": r.updated_at,
            "message_count": r.message_count,
        }
        for r in rows
    ]


# ---------------------------------------------------------------------------
# THE CONFIDENCE GATE
# ---------------------------------------------------------------------------
def ask_copilot(
    db: Session,
    employee_id: uuid.UUID | str | None,
    user_id: uuid.UUID | str,
    prompt: str,
    conversation_id: str | None = None,
    force_escalate: bool = False,
    payslip_id: str | None = None,
) -> Dict[str, Any]:
    """Answer a question, or refuse and escalate. NEVER answers from weak retrieval."""
    if not (prompt or "").strip():
        raise ValidationError("A question is required.")

    convo_id = ensure_conversation(db, user_id, employee_id, conversation_id, prompt)
    user_message_id = _add_message(db, convo_id, "USER", prompt)
    db.commit()

    def finish(payload: Dict[str, Any], answer_text: str) -> Dict[str, Any]:
        _add_message(
            db,
            convo_id,
            "ASSISTANT",
            answer_text,
            mode=payload.get("mode"),
            confidence=payload.get("confidence"),
            citations=payload.get("citations"),
        )
        db.execute(
            text("UPDATE ai_conversations SET updated_at = NOW() WHERE id = :cid"),
            {"cid": str(convo_id)},
        )
        db.commit()
        payload["conversation_id"] = str(convo_id)
        payload["message_id"] = str(user_message_id)
        return payload

    # --- Employee explicitly pressed "This didn't help - Ask HR" ------------
    if force_escalate:
        if employee_id is None:
            raise ValidationError(
                "Your login is not linked to an employee record, so HR escalation "
                "is unavailable. Ask an administrator to link your account."
            )
        result = create_escalation(
            db,
            employee_id,
            user_id,
            prompt,
            reason="USER_REQUESTED",
            conversation_id=str(convo_id),
            source_message_id=str(user_message_id),
        )
        mode = (
            CopilotMode.REUSED.value
            if result.get("reused_prior_answer")
            else CopilotMode.ESCALATED.value
        )
        answer = result.get("answer") or result.get("message", "")
        log_retrieval(
            db,
            user_id=user_id,
            employee_id=employee_id,
            question=prompt,
            mode=mode,
            provider_used=None,
            top_score=None,
            chunk_ids=[],
        )
        return finish({"mode": mode, "answer": answer, **result}, answer)

    # --- TIER 0: exact, local, offline-safe, zero LLM -----------------------
    tier0 = answer_tier0(db, employee_id, prompt, payslip_id=payslip_id)
    if tier0:
        log_retrieval(
            db,
            user_id=user_id,
            employee_id=employee_id,
            question=prompt,
            mode=CopilotMode.TIER0_TEMPLATE.value,
            provider_used="none",
            top_score=None,
            chunk_ids=[],
        )
        return finish(
            {
                "mode": CopilotMode.TIER0_TEMPLATE.value,
                "answer": tier0["answer"],
                "intent": tier0["intent"],
                "confidence": 1.0,
                "citations": [{"title": tier0["source"], "score": 1.0}],
                "used_llm": False,
                "escalation_available": True,
            },
            tier0["answer"],
        )

    # --- TIER 1: retrieval, ALWAYS local -----------------------------------
    chunks = semantic_search_policies(db, prompt, top_k=settings.rag_top_k)

    # TRIGGER: nothing indexed / nothing relevant at all
    if not chunks:
        return finish(
            *_escalate(
                db,
                employee_id,
                user_id,
                prompt,
                convo_id,
                user_message_id,
                reason="NO_CONTEXT",
                confidence=0.0,
                draft=None,
            )
        )

    top_score = chunks[0]["score"]

    # TRIGGER: retrieval too weak to ground an answer -> refuse + escalate.
    # The low-confidence draft is stored as ai_draft_answer so the responder can
    # edit and approve it instead of typing from scratch.
    if top_score < CONFIDENCE_THRESHOLD:
        draft = get_llm_provider().generate(
            redact_pii(build_grounded_prompt(prompt, chunks)), chunks
        )
        return finish(
            *_escalate(
                db,
                employee_id,
                user_id,
                prompt,
                convo_id,
                user_message_id,
                reason="LOW_CONFIDENCE",
                confidence=top_score,
                draft=draft,
                chunks=chunks,
            )
        )

    # --- TIER 2/3: confident path. Phrase the retrieved facts. --------------
    provider = get_llm_provider()
    grounded_prompt = build_grounded_prompt(prompt, chunks)
    # PII BOUNDARY: nothing leaves the process without passing through redact_pii.
    answer = provider.generate(redact_pii(grounded_prompt), chunks)

    log_retrieval(
        db,
        user_id=user_id,
        employee_id=employee_id,
        question=prompt,
        mode=CopilotMode.ANSWERED.value,
        provider_used=provider.name,
        top_score=top_score,
        chunk_ids=[c["chunk_id"] for c in chunks],
    )

    citations = [
        {
            "title": c["title"],
            "score": round(c["score"], 3),
            "collection": c["collection"],
            "human_verified": c["human_verified"],
        }
        for c in chunks
    ]
    return finish(
        {
            "mode": CopilotMode.ANSWERED.value,
            "answer": answer,
            "confidence": round(top_score, 3),
            "citations": citations,
            "provider_used": provider.name,
            "used_llm": provider.name != "extractive",
            "escalation_available": True,  # employee can still ask a human
        },
        answer,
    )


def _escalate(
    db: Session,
    employee_id: uuid.UUID | str | None,
    user_id: uuid.UUID | str,
    prompt: str,
    convo_id: uuid.UUID,
    message_id: uuid.UUID,
    *,
    reason: str,
    confidence: float | None,
    draft: str | None,
    chunks: List[Dict[str, Any]] | None = None,
) -> tuple[Dict[str, Any], str]:
    """Build the ESCALATED payload. Returns (payload, answer_text) for `finish`."""
    if employee_id is None:
        # No linked employee record: we cannot open a ticket, so be honest about
        # what we do have rather than inventing an answer.
        fallback = (
            "I don't have a verified answer for that, and your login isn't linked "
            "to an employee record so I can't open an HR ticket. Please contact "
            "your HR team directly."
        )
        return (
            {
                "mode": CopilotMode.ESCALATED.value,
                "answer": fallback,
                "escalated": False,
                "confidence": round(confidence, 3) if confidence is not None else None,
            },
            fallback,
        )

    result = create_escalation(
        db,
        employee_id,
        user_id,
        prompt,
        reason=reason,
        retrieval_confidence=confidence,
        ai_draft_answer=draft,
        conversation_id=str(convo_id),
        source_message_id=str(message_id),
    )

    mode = (
        CopilotMode.REUSED.value
        if result.get("reused_prior_answer")
        else CopilotMode.ESCALATED.value
    )
    answer = result.get("answer") or result.get("message", "")

    log_retrieval(
        db,
        user_id=user_id,
        employee_id=employee_id,
        question=prompt,
        mode=mode,
        provider_used=None,
        top_score=confidence,
        chunk_ids=[c["chunk_id"] for c in (chunks or [])],
    )

    payload: Dict[str, Any] = {
        "mode": mode,
        "answer": answer,
        "confidence": round(confidence, 3) if confidence is not None else None,
        "escalation_reason": reason,
        **result,
    }
    return payload, answer


def copilot_health(db: Session) -> Dict[str, Any]:
    """Exactly which AI runtime is live. Surfaced so a demo never has to guess."""
    from app.services.embedding import embedding_backend_info
    from app.services.rag_service import knowledge_base_stats

    provider = get_llm_provider()
    return {
        "retrieval": embedding_backend_info(),
        "generation": {
            "configured_provider": settings.llm_provider,
            "active_provider": provider.name,
            "healthy": provider.health(),
            "runs_locally": provider.name in ("extractive", "ollama"),
        },
        "knowledge_base": knowledge_base_stats(db),
        "escalation": {
            "confidence_threshold": CONFIDENCE_THRESHOLD,
            "dedup_threshold": settings.rag_dedup_threshold,
            "max_open_tickets_per_employee": settings.max_open_tickets_per_employee,
        },
    }
