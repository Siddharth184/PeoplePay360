"""Knowledge vector store, copilot transcript and the escalation loop."""

from __future__ import annotations

import uuid
from datetime import datetime
from decimal import Decimal

from pgvector.sqlalchemy import Vector
from sqlalchemy import (
    ARRAY,
    Boolean,
    CheckConstraint,
    DateTime,
    Index,
    Integer,
    Numeric,
    String,
    Text,
    UniqueConstraint,
    text,
)
from sqlalchemy.dialects.postgresql import JSONB
from sqlalchemy.dialects.postgresql import UUID as PgUUID
from sqlalchemy.orm import Mapped, mapped_column, relationship

from app.core.config import settings
from app.models.common import created_at_col, fk_uuid, pg_enum, updated_at_col, uuid_pk
from app.core.database import Base
from app.models.enums import (
    EscalationCategory,
    EscalationPriority,
    EscalationStatus,
    UserRole,
)

EMBEDDING_DIM = settings.embedding_dim


class DocumentChunk(Base):
    """A retrievable unit of HR knowledge."""

    __tablename__ = "document_chunks"

    id: Mapped[uuid.UUID] = uuid_pk()
    collection_name: Mapped[str] = mapped_column(String(50), nullable=False)
    title: Mapped[str] = mapped_column(String(255), nullable=False)
    content: Mapped[str] = mapped_column(Text, nullable=False)
    meta: Mapped[dict] = mapped_column(
        "metadata", JSONB, nullable=False, server_default=text("'{}'::jsonb")
    )
    embedding: Mapped[list[float] | None] = mapped_column(Vector(EMBEDDING_DIM))
    created_at: Mapped[datetime] = created_at_col()

    __table_args__ = (Index("idx_document_chunks_collection", "collection_name"),)


class RagRetrievalLog(Base):
    """Every outbound AI use is auditable: what was retrieved, who answered."""

    __tablename__ = "rag_retrieval_log"

    id: Mapped[uuid.UUID] = uuid_pk()
    asked_by_user_id: Mapped[uuid.UUID | None] = fk_uuid(
        "auth_users.id", ondelete="SET NULL"
    )
    employee_id: Mapped[uuid.UUID | None] = fk_uuid("employees.id", ondelete="SET NULL")
    question_text: Mapped[str] = mapped_column(Text, nullable=False)
    mode: Mapped[str] = mapped_column(String(20), nullable=False)
    provider_used: Mapped[str | None] = mapped_column(String(20))
    top_score: Mapped[Decimal | None] = mapped_column(Numeric(4, 3))
    retrieved_chunk_ids: Mapped[list[uuid.UUID]] = mapped_column(
        ARRAY(PgUUID(as_uuid=True)), nullable=False, server_default=text("'{}'")
    )
    created_at: Mapped[datetime] = created_at_col()


class AiConversation(Base):
    __tablename__ = "ai_conversations"

    id: Mapped[uuid.UUID] = uuid_pk()
    user_id: Mapped[uuid.UUID] = fk_uuid(
        "auth_users.id", nullable=False, ondelete="CASCADE"
    )
    employee_id: Mapped[uuid.UUID | None] = fk_uuid("employees.id", ondelete="SET NULL")
    title: Mapped[str] = mapped_column(
        String(160), nullable=False, default="New conversation"
    )
    created_at: Mapped[datetime] = created_at_col()
    updated_at: Mapped[datetime] = updated_at_col()

    messages = relationship(
        "AiMessage",
        back_populates="conversation",
        cascade="all, delete-orphan",
        order_by="AiMessage.created_at",
    )


class AiMessage(Base):
    __tablename__ = "ai_messages"

    id: Mapped[uuid.UUID] = uuid_pk()
    conversation_id: Mapped[uuid.UUID] = fk_uuid(
        "ai_conversations.id", nullable=False, ondelete="CASCADE"
    )
    role: Mapped[str] = mapped_column(String(12), nullable=False)
    content: Mapped[str] = mapped_column(Text, nullable=False)
    mode: Mapped[str | None] = mapped_column(String(20))
    confidence: Mapped[Decimal | None] = mapped_column(Numeric(4, 3))
    citations: Mapped[list] = mapped_column(
        JSONB, nullable=False, server_default=text("'[]'::jsonb")
    )
    created_at: Mapped[datetime] = created_at_col()

    conversation = relationship("AiConversation", back_populates="messages")

    __table_args__ = (
        CheckConstraint("role IN ('USER', 'ASSISTANT')", name="chk_ai_message_role"),
    )


class RagEscalation(Base):
    """A question the assistant refused to guess at, routed to a human."""

    __tablename__ = "rag_escalations"

    id: Mapped[uuid.UUID] = uuid_pk()
    ticket_no: Mapped[str] = mapped_column(String(30), nullable=False, unique=True)

    conversation_id: Mapped[uuid.UUID | None] = mapped_column(PgUUID(as_uuid=True))
    source_message_id: Mapped[uuid.UUID | None] = mapped_column(PgUUID(as_uuid=True))

    employee_id: Mapped[uuid.UUID] = fk_uuid("employees.id", nullable=False)
    asked_by_user_id: Mapped[uuid.UUID] = fk_uuid("auth_users.id", nullable=False)

    question_text: Mapped[str] = mapped_column(Text, nullable=False)
    question_embedding: Mapped[list[float] | None] = mapped_column(Vector(EMBEDDING_DIM))
    category: Mapped[EscalationCategory] = mapped_column(
        pg_enum(EscalationCategory, "escalation_category_enum"),
        nullable=False,
        default=EscalationCategory.OTHER,
    )

    escalation_reason: Mapped[str] = mapped_column(String(40), nullable=False)
    retrieval_confidence: Mapped[Decimal | None] = mapped_column(Numeric(4, 3))
    ai_draft_answer: Mapped[str | None] = mapped_column(Text)

    status: Mapped[EscalationStatus] = mapped_column(
        pg_enum(EscalationStatus, "escalation_status_enum"),
        nullable=False,
        default=EscalationStatus.OPEN,
    )
    priority: Mapped[EscalationPriority] = mapped_column(
        pg_enum(EscalationPriority, "escalation_priority_enum"),
        nullable=False,
        default=EscalationPriority.NORMAL,
    )
    assigned_to_user_id: Mapped[uuid.UUID | None] = fk_uuid(
        "auth_users.id", ondelete="SET NULL"
    )
    assigned_at: Mapped[datetime | None] = mapped_column(DateTime(timezone=True))

    answer_text: Mapped[str | None] = mapped_column(Text)
    answered_by_user_id: Mapped[uuid.UUID | None] = fk_uuid(
        "auth_users.id", ondelete="SET NULL"
    )
    answered_at: Mapped[datetime | None] = mapped_column(DateTime(timezone=True))

    sla_due_at: Mapped[datetime] = mapped_column(
        DateTime(timezone=True), nullable=False
    )
    first_response_at: Mapped[datetime | None] = mapped_column(DateTime(timezone=True))

    publish_to_kb: Mapped[bool] = mapped_column(Boolean, nullable=False, default=False)
    kb_chunk_id: Mapped[uuid.UUID | None] = fk_uuid(
        "document_chunks.id", ondelete="SET NULL"
    )
    duplicate_of_id: Mapped[uuid.UUID | None] = fk_uuid(
        "rag_escalations.id", ondelete="SET NULL"
    )

    created_at: Mapped[datetime] = created_at_col()
    updated_at: Mapped[datetime] = updated_at_col()

    employee = relationship("Employee", foreign_keys=[employee_id])
    asked_by = relationship("AuthUser", foreign_keys=[asked_by_user_id])
    assigned_to = relationship("AuthUser", foreign_keys=[assigned_to_user_id])
    answered_by = relationship("AuthUser", foreign_keys=[answered_by_user_id])
    events = relationship(
        "RagEscalationEvent",
        back_populates="escalation",
        cascade="all, delete-orphan",
        order_by="RagEscalationEvent.created_at",
    )

    __table_args__ = (
        CheckConstraint(
            "escalation_reason IN ('LOW_CONFIDENCE', 'NO_CONTEXT', "
            "'NO_TOOL_MATCH', 'USER_REQUESTED')",
            name="chk_escalation_reason",
        ),
        CheckConstraint(
            "status <> 'ANSWERED' OR (answer_text IS NOT NULL AND "
            "answered_by_user_id IS NOT NULL AND answered_at IS NOT NULL)",
            name="chk_answer_completeness",
        ),
        CheckConstraint(
            "status <> 'ASSIGNED' OR assigned_to_user_id IS NOT NULL",
            name="chk_assignment_completeness",
        ),
        CheckConstraint(
            "retrieval_confidence IS NULL OR (retrieval_confidence >= 0 "
            "AND retrieval_confidence <= 1)",
            name="chk_confidence_range",
        ),
        Index("idx_escalations_queue", "status", "priority", "created_at"),
        Index("idx_escalations_employee", "employee_id", "created_at"),
    )

    @property
    def is_overdue(self) -> bool:
        from datetime import timezone

        if self.status not in (EscalationStatus.OPEN, EscalationStatus.ASSIGNED):
            return False
        return self.sla_due_at < datetime.now(timezone.utc)


class RagEscalationEvent(Base):
    """Append-only thread + audit trail in one table."""

    __tablename__ = "rag_escalation_events"

    id: Mapped[uuid.UUID] = uuid_pk()
    escalation_id: Mapped[uuid.UUID] = fk_uuid(
        "rag_escalations.id", nullable=False, ondelete="CASCADE"
    )
    actor_user_id: Mapped[uuid.UUID | None] = fk_uuid(
        "auth_users.id", ondelete="SET NULL"
    )
    event_type: Mapped[str] = mapped_column(String(30), nullable=False)
    body: Mapped[str | None] = mapped_column(Text)
    visibility: Mapped[str] = mapped_column(
        String(10), nullable=False, default="PUBLIC"
    )
    created_at: Mapped[datetime] = created_at_col()

    escalation = relationship("RagEscalation", back_populates="events")
    actor = relationship("AuthUser", foreign_keys=[actor_user_id])

    __table_args__ = (
        CheckConstraint(
            "visibility IN ('PUBLIC', 'INTERNAL')", name="chk_event_visibility"
        ),
        Index("idx_escalation_events_thread", "escalation_id", "created_at"),
    )


class EscalationRoutingRule(Base):
    """Configurable category -> owning role -> SLA mapping."""

    __tablename__ = "escalation_routing_rules"

    id: Mapped[uuid.UUID] = uuid_pk()
    category: Mapped[EscalationCategory] = mapped_column(
        pg_enum(EscalationCategory, "escalation_category_enum"), nullable=False
    )
    target_role: Mapped[UserRole] = mapped_column(
        pg_enum(UserRole, "user_role_enum"), nullable=False
    )
    department_id: Mapped[uuid.UUID | None] = fk_uuid(
        "departments.id", ondelete="CASCADE"
    )
    sla_hours: Mapped[int] = mapped_column(Integer, nullable=False, default=24)
    priority: Mapped[EscalationPriority] = mapped_column(
        pg_enum(EscalationPriority, "escalation_priority_enum"),
        nullable=False,
        default=EscalationPriority.NORMAL,
    )
    sequence: Mapped[int] = mapped_column(Integer, nullable=False, default=10)
    is_active: Mapped[bool] = mapped_column(Boolean, nullable=False, default=True)

    __table_args__ = (
        UniqueConstraint("category", "department_id", name="uq_routing_cat_dept"),
        CheckConstraint("sla_hours > 0", name="chk_sla_hours_positive"),
    )
