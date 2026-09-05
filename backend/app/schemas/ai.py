"""Copilot, knowledge base and escalation loop schemas."""

from __future__ import annotations

import uuid
from datetime import datetime
from typing import Any, Dict, List, Optional

from pydantic import BaseModel, Field

from app.models.enums import (
    EscalationCategory,
    EscalationPriority,
    EscalationStatus,
    UserRole,
)


# ===========================================================================
# COPILOT
# ===========================================================================
class CopilotAskRequest(BaseModel):
    prompt: str = Field(min_length=1, max_length=2000)
    conversation_id: Optional[uuid.UUID] = None
    force_escalate: bool = Field(
        default=False,
        description="Set when the employee taps 'This didn't help - Ask HR'.",
    )
    payslip_id: Optional[uuid.UUID] = Field(
        default=None,
        description="Scopes a payslip breakdown question to a specific payslip.",
    )


class CitationOut(BaseModel):
    title: str
    score: float
    collection: Optional[str] = None
    human_verified: bool = False


class CopilotAnswerOut(BaseModel):
    mode: str  # TIER0_TEMPLATE | ANSWERED | ESCALATED | REUSED
    answer: str
    conversation_id: Optional[str] = None
    message_id: Optional[str] = None
    confidence: Optional[float] = None
    citations: List[CitationOut] = Field(default_factory=list)
    intent: Optional[str] = None
    provider_used: Optional[str] = None
    used_llm: Optional[bool] = None
    escalation_available: bool = True

    # Present when the answer was escalated or a prior answer was reused
    escalated: Optional[bool] = None
    reused_prior_answer: Optional[bool] = None
    escalation_id: Optional[str] = None
    ticket_no: Optional[str] = None
    category: Optional[str] = None
    routed_to_role: Optional[str] = None
    sla_due_at: Optional[str] = None
    escalation_reason: Optional[str] = None
    similarity: Optional[float] = None
    source: Optional[str] = None
    message: Optional[str] = None


class ConversationSummaryOut(BaseModel):
    id: str
    title: str
    updated_at: datetime
    message_count: int


class ConversationMessageOut(BaseModel):
    id: str
    role: str
    content: str
    mode: Optional[str] = None
    confidence: Optional[float] = None
    citations: List[Dict[str, Any]] = Field(default_factory=list)
    created_at: datetime


class ConversationDetailOut(BaseModel):
    id: str
    title: str
    created_at: datetime
    updated_at: datetime
    messages: List[ConversationMessageOut]


class Tier0IntentOut(BaseModel):
    intent: str
    description: str
    example: str


# ===========================================================================
# KNOWLEDGE BASE
# ===========================================================================
class DocumentIngestRequest(BaseModel):
    collection: str = Field(default="hr_policies", min_length=1, max_length=50)
    title: str = Field(min_length=1, max_length=255)
    content: str = Field(min_length=1)
    metadata: Optional[Dict[str, Any]] = None
    replace_existing: bool = Field(
        default=False,
        description="Delete existing chunks with the same collection+title first.",
    )


class DocumentIngestResponse(BaseModel):
    collection: str
    title: str
    chunks_created: int
    chunk_ids: List[str]


class CollectionStatsOut(BaseModel):
    collection_name: str
    chunk_count: int
    document_count: int
    last_updated: Optional[datetime] = None


class SemanticSearchRequest(BaseModel):
    query: str = Field(min_length=1, max_length=1000)
    top_k: int = Field(default=3, ge=1, le=20)
    collections: Optional[List[str]] = None


class SearchHitOut(BaseModel):
    chunk_id: str
    collection: str
    title: str
    content: str
    score: float
    human_verified: bool
    metadata: Dict[str, Any] = Field(default_factory=dict)


# ===========================================================================
# ESCALATIONS
# ===========================================================================
class EscalationCreateRequest(BaseModel):
    prompt: str = Field(min_length=1, max_length=2000)
    conversation_id: Optional[uuid.UUID] = None
    source_message_id: Optional[uuid.UUID] = None


class EscalationCreateResponse(BaseModel):
    escalated: bool
    reused_prior_answer: bool
    escalation_id: Optional[str] = None
    ticket_no: Optional[str] = None
    category: Optional[str] = None
    routed_to_role: Optional[str] = None
    sla_due_at: Optional[str] = None
    message: Optional[str] = None
    answer: Optional[str] = None
    source: Optional[str] = None
    similarity: Optional[float] = None


class EscalationEventOut(BaseModel):
    id: str
    event_type: str
    body: Optional[str] = None
    visibility: str
    actor_email: Optional[str] = None
    actor_role: Optional[str] = None
    created_at: datetime


class EscalationOut(BaseModel):
    id: str
    ticket_no: str
    employee_id: str
    employee_name: str
    employee_badge: str
    question_text: str
    category: EscalationCategory
    escalation_reason: str
    retrieval_confidence: Optional[float] = None
    ai_draft_answer: Optional[str] = None
    status: EscalationStatus
    priority: EscalationPriority
    assigned_to_user_id: Optional[str] = None
    assigned_to_email: Optional[str] = None
    answer_text: Optional[str] = None
    answered_by_email: Optional[str] = None
    answered_at: Optional[datetime] = None
    sla_due_at: datetime
    first_response_at: Optional[datetime] = None
    is_overdue: bool
    publish_to_kb: bool
    kb_chunk_id: Optional[str] = None
    conversation_id: Optional[str] = None
    created_at: datetime
    updated_at: datetime


class EscalationDetailOut(EscalationOut):
    events: List[EscalationEventOut] = Field(default_factory=list)


class EscalationPage(BaseModel):
    total: int
    limit: int
    offset: int
    items: List[EscalationOut]


class EscalationAssignRequest(BaseModel):
    assignee_user_id: uuid.UUID


class EscalationAnswerRequest(BaseModel):
    answer_text: str = Field(min_length=1, max_length=8000)
    publish_to_kb: bool = Field(
        default=True,
        description=(
            "Stage 4 of the loop. When true the Q&A pair is embedded into the "
            "knowledge base so the assistant answers this itself next time. "
            "Leave false for person-specific answers."
        ),
    )


class EscalationCommentRequest(BaseModel):
    body: str = Field(min_length=1, max_length=4000)
    visibility: str = Field(default="INTERNAL", pattern="^(PUBLIC|INTERNAL)$")


class EscalationNoteRequest(BaseModel):
    note: Optional[str] = Field(default=None, max_length=1000)


class EscalationStatsOut(BaseModel):
    open_count: int
    assigned_count: int
    answered_count: int
    closed_count: int
    overdue_count: int
    kb_articles_created: int
    total_count: int
    median_first_response_minutes: Optional[float] = None
    by_category: Dict[str, int] = Field(default_factory=dict)
    by_reason: Dict[str, int] = Field(default_factory=dict)


class RoutingRuleOut(BaseModel):
    id: str
    category: EscalationCategory
    target_role: UserRole
    department_id: Optional[str] = None
    department_name: Optional[str] = None
    sla_hours: int
    priority: EscalationPriority
    sequence: int
    is_active: bool


class RoutingRuleUpdate(BaseModel):
    target_role: Optional[UserRole] = None
    sla_hours: Optional[int] = Field(default=None, ge=1, le=8760)
    priority: Optional[EscalationPriority] = None
    sequence: Optional[int] = Field(default=None, ge=0, le=1000)
    is_active: Optional[bool] = None


class SlaSweepResponse(BaseModel):
    notifications_created: int
    tickets_escalated_to_urgent: int


class CopilotHealthOut(BaseModel):
    retrieval: Dict[str, Any]
    generation: Dict[str, Any]
    knowledge_base: Dict[str, Any]
    escalation: Dict[str, Any]
