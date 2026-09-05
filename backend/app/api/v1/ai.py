"""AI Copilot, knowledge base and the human-in-the-loop escalation endpoints."""

from __future__ import annotations

import uuid
from typing import List, Optional

from fastapi import APIRouter, Depends, Query

from app.api.deps import DbSession, PageParams, User, require_linked_employee
from app.core.errors import ForbiddenError
from app.core.security import (
    CurrentUser,
    require_admin,
    require_escalation_responder,
    require_hr,
)
from app.schemas.ai import (
    CollectionStatsOut,
    ConversationDetailOut,
    ConversationSummaryOut,
    CopilotAnswerOut,
    CopilotAskRequest,
    CopilotHealthOut,
    DocumentIngestRequest,
    DocumentIngestResponse,
    EscalationAnswerRequest,
    EscalationAssignRequest,
    EscalationCommentRequest,
    EscalationCreateRequest,
    EscalationCreateResponse,
    EscalationDetailOut,
    EscalationNoteRequest,
    EscalationPage,
    EscalationStatsOut,
    RoutingRuleOut,
    RoutingRuleUpdate,
    SearchHitOut,
    SemanticSearchRequest,
    SlaSweepResponse,
    Tier0IntentOut,
)
from app.schemas.common import MessageResponse
from app.services import copilot_service, escalation_service, rag_service
from app.services.copilot_templates import tier0_catalogue

router = APIRouter(prefix="/ai", tags=["AI Copilot"])


# ===========================================================================
# THE ASSISTANT
# ===========================================================================
@router.post(
    "/assistant",
    response_model=CopilotAnswerOut,
    summary=(
        "Hybrid RAG endpoint. Returns mode=ANSWERED with citations, "
        "mode=TIER0_TEMPLATE for personal data, or mode=ESCALATED + ticket_no "
        "when retrieval confidence falls below the threshold."
    ),
)
def ask_assistant(
    payload: CopilotAskRequest, db: DbSession, user: User
) -> CopilotAnswerOut:
    result = copilot_service.ask_copilot(
        db,
        employee_id=user.employee_id,
        user_id=user.user_id,
        prompt=payload.prompt,
        conversation_id=str(payload.conversation_id) if payload.conversation_id else None,
        force_escalate=payload.force_escalate,
        payslip_id=str(payload.payslip_id) if payload.payslip_id else None,
    )
    return CopilotAnswerOut(**result)


@router.get(
    "/assistant/health",
    response_model=CopilotHealthOut,
    summary="Which AI runtime is actually live (retrieval backend, LLM provider)",
)
def assistant_health(db: DbSession, user: User) -> CopilotHealthOut:
    return CopilotHealthOut(**copilot_service.copilot_health(db))


@router.get(
    "/assistant/suggestions",
    response_model=List[Tier0IntentOut],
    summary="Questions the assistant can answer exactly from SQL, with no LLM",
)
def assistant_suggestions(user: User) -> List[Tier0IntentOut]:
    return [Tier0IntentOut(**item) for item in tier0_catalogue()]


@router.get(
    "/conversations",
    response_model=List[ConversationSummaryOut],
    summary="The caller's copilot threads",
)
def list_conversations(
    db: DbSession, user: User, limit: int = Query(default=20, ge=1, le=100)
) -> List[ConversationSummaryOut]:
    return [
        ConversationSummaryOut(**row)
        for row in copilot_service.list_conversations(db, user.user_id, limit)
    ]


@router.get(
    "/conversations/{conversation_id}",
    response_model=ConversationDetailOut,
    summary="Full transcript of one thread (owner only)",
)
def get_conversation(
    conversation_id: uuid.UUID, db: DbSession, user: User
) -> ConversationDetailOut:
    return ConversationDetailOut(
        **copilot_service.get_conversation(db, conversation_id, user.user_id)
    )


# ===========================================================================
# KNOWLEDGE BASE
# ===========================================================================
@router.post(
    "/knowledge/documents",
    response_model=DocumentIngestResponse,
    status_code=201,
    summary="Ingest an HR policy document: chunk it, embed locally, store in pgvector",
)
def ingest_document(
    payload: DocumentIngestRequest,
    db: DbSession,
    _: CurrentUser = Depends(require_hr),
) -> DocumentIngestResponse:
    result = rag_service.ingest_hr_policy_document(
        db,
        payload.collection,
        payload.title,
        payload.content,
        metadata=payload.metadata,
        replace_existing=payload.replace_existing,
    )
    return DocumentIngestResponse(**result)


@router.get(
    "/knowledge/collections",
    response_model=List[CollectionStatsOut],
    summary="Knowledge base inventory by collection",
)
def list_collections(db: DbSession, user: User) -> List[CollectionStatsOut]:
    return [CollectionStatsOut(**row) for row in rag_service.list_collections(db)]


@router.post(
    "/knowledge/search",
    response_model=List[SearchHitOut],
    summary="Raw cosine similarity search (useful for tuning the threshold)",
)
def search_knowledge(
    payload: SemanticSearchRequest, db: DbSession, user: User
) -> List[SearchHitOut]:
    hits = rag_service.semantic_search_policies(
        db, payload.query, payload.top_k, collections=payload.collections
    )
    return [SearchHitOut(**hit) for hit in hits]


@router.delete(
    "/knowledge/documents",
    response_model=MessageResponse,
    summary="Delete every chunk of one document",
)
def delete_document(
    db: DbSession,
    collection: str = Query(...),
    title: str = Query(...),
    _: CurrentUser = Depends(require_hr),
) -> MessageResponse:
    removed = rag_service.delete_document(db, collection, title)
    return MessageResponse(detail=f"Deleted {removed} chunk(s).")


# ===========================================================================
# ESCALATIONS
# ===========================================================================
@router.post(
    "/escalations",
    response_model=EscalationCreateResponse,
    status_code=201,
    summary=(
        "Manual escalation - 'This didn't help, ask HR'. Semantic dedup may "
        "return a prior human answer instantly."
    ),
)
def create_escalation(
    payload: EscalationCreateRequest, db: DbSession, user: User
) -> EscalationCreateResponse:
    employee_id = require_linked_employee(user)
    result = escalation_service.create_escalation(
        db,
        employee_id,
        user.user_id,
        payload.prompt,
        reason="USER_REQUESTED",
        conversation_id=str(payload.conversation_id) if payload.conversation_id else None,
        source_message_id=(
            str(payload.source_message_id) if payload.source_message_id else None
        ),
    )
    return EscalationCreateResponse(**result)


@router.get(
    "/escalations",
    response_model=EscalationPage,
    summary="List tickets. EMPLOYEE callers are scoped to their own automatically.",
)
def list_escalations(
    db: DbSession,
    page: PageParams,
    user: User,
    status: Optional[str] = Query(default=None),
    category: Optional[str] = Query(default=None),
    priority: Optional[str] = Query(default=None),
    assignee_user_id: Optional[uuid.UUID] = Query(default=None),
    overdue: bool = Query(default=False),
) -> EscalationPage:
    # Row scoping: non-responders only ever see their own tickets.
    scope = None if user.is_escalation_responder or user.has_hr_scope else require_linked_employee(user)
    result = escalation_service.list_escalations(
        db,
        scope_employee_id=scope,
        status=status,
        category=category,
        priority=priority,
        assignee_user_id=assignee_user_id,
        overdue=overdue,
        limit=page.limit,
        offset=page.offset,
    )
    return EscalationPage(**result)


@router.get(
    "/escalations/stats",
    response_model=EscalationStatsOut,
    summary="Queue KPIs: open, overdue, median first response, KB articles created",
)
def escalation_stats(
    db: DbSession, _: CurrentUser = Depends(require_escalation_responder)
) -> EscalationStatsOut:
    return EscalationStatsOut(**escalation_service.escalation_stats(db))


@router.get(
    "/escalations/routing-rules",
    response_model=List[RoutingRuleOut],
    summary="Read the category -> role -> SLA routing configuration",
)
def list_routing_rules(
    db: DbSession, _: CurrentUser = Depends(require_admin)
) -> List[RoutingRuleOut]:
    return [RoutingRuleOut(**row) for row in escalation_service.list_routing_rules(db)]


@router.put(
    "/escalations/routing-rules/{rule_id}",
    response_model=RoutingRuleOut,
    summary="Update routing target or SLA hours for a category",
)
def update_routing_rule(
    rule_id: uuid.UUID,
    payload: RoutingRuleUpdate,
    db: DbSession,
    _: CurrentUser = Depends(require_admin),
) -> RoutingRuleOut:
    updated = escalation_service.update_routing_rule(
        db,
        rule_id,
        target_role=payload.target_role.value if payload.target_role else None,
        sla_hours=payload.sla_hours,
        priority=payload.priority.value if payload.priority else None,
        sequence=payload.sequence,
        is_active=payload.is_active,
    )
    return RoutingRuleOut(**updated)


@router.post(
    "/escalations/sla-sweep",
    response_model=SlaSweepResponse,
    summary="Run the SLA breach sweep now (normally a 15-minute scheduled job)",
)
def sla_sweep(
    db: DbSession, _: CurrentUser = Depends(require_admin)
) -> SlaSweepResponse:
    return SlaSweepResponse(**escalation_service.sla_breach_sweep(db))


@router.get(
    "/escalations/{escalation_id}",
    response_model=EscalationDetailOut,
    summary="Ticket detail + thread. INTERNAL events are stripped for the asker.",
)
def get_escalation(
    escalation_id: uuid.UUID, db: DbSession, user: User
) -> EscalationDetailOut:
    is_responder = user.is_escalation_responder
    ticket = escalation_service.get_escalation(
        db,
        escalation_id,
        requester_employee_id=None if is_responder else require_linked_employee(user),
        include_internal=is_responder,
    )
    return EscalationDetailOut(**ticket)


@router.post(
    "/escalations/{escalation_id}/assign",
    summary="Claim or delegate a ticket; stamps first_response_at for SLA metrics",
)
def assign_escalation(
    escalation_id: uuid.UUID,
    payload: EscalationAssignRequest,
    db: DbSession,
    user: CurrentUser = Depends(require_escalation_responder),
) -> dict:
    return escalation_service.assign_escalation(
        db, escalation_id, payload.assignee_user_id, user.user_id
    )


@router.post(
    "/escalations/{escalation_id}/answer",
    summary=(
        "The core action. Notifies the employee and, when publish_to_kb is true, "
        "indexes the answer so the assistant handles it itself next time."
    ),
)
def answer_escalation(
    escalation_id: uuid.UUID,
    payload: EscalationAnswerRequest,
    db: DbSession,
    user: CurrentUser = Depends(require_escalation_responder),
) -> dict:
    # Growing the shared knowledge base is a separate, higher privilege than
    # simply replying to one employee.
    if payload.publish_to_kb and not user.has_permission("publish:knowledge_base"):
        raise ForbiddenError(
            "Your role may answer this ticket but not publish to the shared "
            "knowledge base. Resubmit with publish_to_kb=false."
        )
    return escalation_service.answer_escalation(
        db, escalation_id, user.user_id, payload.answer_text, payload.publish_to_kb
    )


@router.post(
    "/escalations/{escalation_id}/comment",
    summary="Add a note. INTERNAL notes are never visible to the asking employee.",
)
def comment_escalation(
    escalation_id: uuid.UUID,
    payload: EscalationCommentRequest,
    db: DbSession,
    user: CurrentUser = Depends(require_escalation_responder),
) -> dict:
    return escalation_service.comment_on_escalation(
        db, escalation_id, user.user_id, payload.body, payload.visibility
    )


@router.post(
    "/escalations/{escalation_id}/close",
    summary="Close the loop after the employee confirms",
)
def close_escalation(
    escalation_id: uuid.UUID,
    payload: EscalationNoteRequest,
    db: DbSession,
    user: User,
) -> dict:
    _assert_owner_or_responder(db, escalation_id, user)
    return escalation_service.close_escalation(
        db, escalation_id, user.user_id, payload.note or "Loop closed."
    )


@router.post(
    "/escalations/{escalation_id}/reopen",
    summary="Reopen when the answer was insufficient",
)
def reopen_escalation(
    escalation_id: uuid.UUID,
    payload: EscalationNoteRequest,
    db: DbSession,
    user: User,
) -> dict:
    _assert_owner_or_responder(db, escalation_id, user)
    return escalation_service.reopen_escalation(
        db, escalation_id, user.user_id, payload.note or "Answer was insufficient."
    )


@router.post(
    "/escalations/{escalation_id}/reject",
    summary="Mark out-of-scope / duplicate / spam (ADMIN only)",
)
def reject_escalation(
    escalation_id: uuid.UUID,
    payload: EscalationNoteRequest,
    db: DbSession,
    user: CurrentUser = Depends(require_admin),
) -> dict:
    return escalation_service.reject_escalation(
        db, escalation_id, user.user_id, payload.note or "Out of scope."
    )


def _assert_owner_or_responder(db, escalation_id: uuid.UUID, user: CurrentUser) -> None:
    """Close / reopen are available to the asker OR a responder, nobody else."""
    if user.is_escalation_responder:
        return
    escalation_service.get_escalation(
        db, escalation_id, requester_employee_id=require_linked_employee(user)
    )
