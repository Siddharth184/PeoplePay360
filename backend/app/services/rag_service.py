"""Local vector store ingestion + cosine retrieval over pgvector.

Everything in this module runs on the machine: `fastembed` (or the hashing
fallback) produces the vectors and PostgreSQL does the nearest-neighbour search.
No network call happens here. Generation - the only outbound step - lives in
`llm_provider` and is invoked by `copilot_service`.
"""

from __future__ import annotations

import json
import uuid
from decimal import Decimal
from typing import Any, Dict, List, Sequence

from sqlalchemy import text
from sqlalchemy.orm import Session

from app.core.config import settings
from app.core.errors import ValidationError
from app.services.embedding import chunk_text, embed_query, embed_text, embed_texts

DEFAULT_COLLECTION = "hr_policies"
RESOLVED_FAQ_COLLECTION = "hr_faq_resolved"


def _vector_literal(vector: Sequence[float]) -> str:
    """pgvector accepts its own text form; this avoids a driver-side adapter."""
    return "[" + ",".join(f"{v:.8f}" for v in vector) + "]"


# ---------------------------------------------------------------------------
# INGESTION
# ---------------------------------------------------------------------------
def ingest_hr_policy_document(
    db: Session,
    collection: str,
    title: str,
    text_content: str,
    *,
    metadata: Dict[str, Any] | None = None,
    replace_existing: bool = False,
) -> Dict[str, Any]:
    """Chunk a document, embed each chunk locally and store it in pgvector."""
    chunks = chunk_text(text_content)
    if not chunks:
        raise ValidationError("Document content is empty; nothing to ingest.")

    if replace_existing:
        db.execute(
            text(
                "DELETE FROM document_chunks "
                "WHERE collection_name = :col AND title = :title"
            ),
            {"col": collection, "title": title},
        )

    embeddings = embed_texts(chunks)
    base_meta = dict(metadata or {})
    chunk_ids: List[uuid.UUID] = []

    has_vector = False
    try:
        has_vector = bool(db.execute(text("SELECT COUNT(*) FROM pg_type WHERE typname = 'vector'")).scalar_one())
    except Exception:
        db.rollback()

    for index, (chunk, embedding) in enumerate(zip(chunks, embeddings)):
        meta = {**base_meta, "chunk_index": index, "chunk_count": len(chunks)}
        if has_vector:
            chunk_id = db.execute(
                text(
                    """
                    INSERT INTO document_chunks
                        (collection_name, title, content, metadata, embedding)
                    VALUES (:col, :title, :content, CAST(:meta AS jsonb), CAST(:emb AS vector))
                    RETURNING id
                    """
                ),
                {
                    "col": collection,
                    "title": title,
                    "content": chunk,
                    "meta": json.dumps(meta),
                    "emb": f"[{','.join(f'{v:.8f}' for v in embedding)}]",
                },
            ).scalar_one()
        else:
            chunk_id = db.execute(
                text(
                    """
                    INSERT INTO document_chunks
                        (collection_name, title, content, metadata)
                    VALUES (:col, :title, :content, CAST(:meta AS jsonb))
                    RETURNING id
                    """
                ),
                {
                    "col": collection,
                    "title": title,
                    "content": chunk,
                    "meta": json.dumps(meta),
                },
            ).scalar_one()
        chunk_ids.append(chunk_id)

    db.commit()
    return {
        "collection": collection,
        "title": title,
        "chunks_created": len(chunk_ids),
        "chunk_ids": [str(c) for c in chunk_ids],
    }


def store_verified_answer(
    db: Session,
    *,
    question: str,
    answer: str,
    title: str,
    metadata: Dict[str, Any] | None = None,
) -> uuid.UUID:
    """Knowledge flywheel primitive: index one human-verified Q&A pair.

    The question is prefixed onto the stored text because retrieval is matched
    against the *question* an employee asks, not against the answer prose.
    """
    kb_text = f"Question: {question}\n\nOfficial HR answer: {answer}"
    embedding = embed_text(kb_text)
    return db.execute(
        text(
            """
            INSERT INTO document_chunks
                (collection_name, title, content, metadata, embedding)
            VALUES (:col, :title, :content, CAST(:meta AS jsonb), CAST(:emb AS vector))
            RETURNING id
            """
        ),
        {
            "col": RESOLVED_FAQ_COLLECTION,
            "title": title,
            "content": kb_text,
            "meta": json.dumps({**(metadata or {}), "human_verified": True}),
            "emb": _vector_literal(embedding),
        },
    ).scalar_one()


def delete_document(db: Session, collection: str, title: str) -> int:
    result = db.execute(
        text(
            "DELETE FROM document_chunks WHERE collection_name = :col AND title = :title"
        ),
        {"col": collection, "title": title},
    )
    db.commit()
    return result.rowcount or 0


def list_collections(db: Session) -> List[Dict[str, Any]]:
    rows = db.execute(
        text(
            """
            SELECT collection_name,
                   COUNT(*) AS chunk_count,
                   COUNT(DISTINCT title) AS document_count,
                   MAX(created_at) AS last_updated
            FROM document_chunks
            GROUP BY collection_name
            ORDER BY collection_name
            """
        )
    ).all()
    return [
        {
            "collection_name": r.collection_name,
            "chunk_count": r.chunk_count,
            "document_count": r.document_count,
            "last_updated": r.last_updated,
        }
        for r in rows
    ]


# ---------------------------------------------------------------------------
# RETRIEVAL
# ---------------------------------------------------------------------------
def semantic_search_policies(
    db: Session,
    query: str,
    top_k: int | None = None,
    *,
    collections: Sequence[str] | None = None,
) -> List[Dict[str, Any]]:
    """Cosine similarity search over the HR knowledge base.

    `1 - (embedding <=> q)` is cosine similarity in [-1, 1]; pgvector's `<=>`
    returns cosine *distance*, so the ordering below is ascending distance.
    """
    if not (query or "").strip():
        return []

    top_k = top_k or settings.rag_top_k
    # embed_query, not embed_text: bge is asymmetric (see embedding.embed_texts).
    query_embedding = _vector_literal(embed_query(query))

    sql = """
        SELECT id, collection_name, title, content, metadata,
               (1 - (embedding <=> CAST(:emb AS vector))) AS similarity
        FROM document_chunks
        WHERE embedding IS NOT NULL
        {collection_filter}
        ORDER BY embedding <=> CAST(:emb AS vector)
        LIMIT :k
    """
    params: Dict[str, Any] = {"emb": query_embedding, "k": top_k}
    collection_filter = ""
    if collections:
        collection_filter = "AND collection_name = ANY(:collections)"
        params["collections"] = list(collections)

    rows = db.execute(
        text(sql.format(collection_filter=collection_filter)), params
    ).fetchall()

    return [
        {
            "chunk_id": str(r.id),
            "collection": r.collection_name,
            "title": r.title,
            "content": r.content,
            "metadata": r.metadata or {},
            "score": float(r.similarity),
            # A human-verified answer outranks generic handbook prose in the UI.
            "human_verified": bool((r.metadata or {}).get("human_verified")),
        }
        for r in rows
    ]


def build_grounded_prompt(
    question: str,
    chunks: Sequence[Dict[str, Any]],
    *,
    personal_context: str | None = None,
) -> str:
    """Assemble the CONTEXT block.

    Only `document_chunks` content (company handbook text) goes in here. Employee
    rows never do - those are answered by the Tier 0 template path instead.
    """
    policy_context = "\n\n".join(
        f"[{index + 1}] {chunk['title']}\n{chunk['content']}"
        for index, chunk in enumerate(chunks)
    ) or "(no policy documentation retrieved)"

    sections = [
        "CONTEXT - Official PeoplePay360 HR documentation:",
        policy_context,
    ]
    if personal_context:
        sections += ["", "CONTEXT - The employee's own records:", personal_context]
    sections += [
        "",
        "Answer the employee's question using ONLY the context above. Cite the "
        "numbered source you used. If the context does not contain the answer, "
        "reply exactly: INSUFFICIENT_CONTEXT.",
        "",
        f"Employee question: {question}",
        "Answer:",
    ]
    return "\n".join(sections)


def log_retrieval(
    db: Session,
    *,
    user_id: uuid.UUID | str | None,
    employee_id: uuid.UUID | str | None,
    question: str,
    mode: str,
    provider_used: str | None,
    top_score: float | None,
    chunk_ids: Sequence[str] | None,
) -> None:
    """Auditability: every AI answer records what grounded it and who phrased it."""
    db.execute(
        text(
            """
            INSERT INTO rag_retrieval_log
                (asked_by_user_id, employee_id, question_text, mode,
                 provider_used, top_score, retrieved_chunk_ids)
            VALUES (:user, :emp, :q, :mode, :provider, :score, CAST(:chunks AS uuid[]))
            """
        ),
        {
            "user": str(user_id) if user_id else None,
            "emp": str(employee_id) if employee_id else None,
            "q": question,
            "mode": mode,
            "provider": provider_used,
            "score": Decimal(str(round(top_score, 3))) if top_score is not None else None,
            "chunks": list(chunk_ids or []),
        },
    )


def knowledge_base_stats(db: Session) -> Dict[str, Any]:
    row = db.execute(
        text(
            """
            SELECT COUNT(*) AS chunks,
                   COUNT(DISTINCT title) AS documents,
                   COUNT(*) FILTER (WHERE collection_name = :faq) AS verified_answers
            FROM document_chunks
            """
        ),
        {"faq": RESOLVED_FAQ_COLLECTION},
    ).one()
    return {
        "total_chunks": row.chunks,
        "total_documents": row.documents,
        "human_verified_answers": row.verified_answers,
        "confidence_threshold": settings.rag_confidence_threshold,
        "top_k": settings.rag_top_k,
    }
