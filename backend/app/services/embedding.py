"""Local embedding layer. Always local, always CPU, never a network call.

Two interchangeable backends behind one function:

* ``fastembed`` - `BAAI/bge-small-en-v1.5`, 384-dim ONNX, ~130MB, no torch, no
  CUDA. This is the production path.
* ``hash`` - a dependency-free hashed bag-of-words embedder. Same 384 dims, same
  cosine geometry, purely lexical. It exists so the whole product installs and
  demos on a machine where the ONNX wheel is unavailable, instead of the AI
  endpoints returning 500s.

Which one is live is reported by :func:`embedding_backend_info` and surfaced on
``/health`` so nobody has to guess which mode a demo is running in.
"""

from __future__ import annotations

import hashlib
import logging
import math
import re
import threading
from typing import List, Sequence

from app.core.config import settings

logger = logging.getLogger(__name__)

DIM = settings.embedding_dim
_TOKEN_RE = re.compile(r"[a-z0-9']+")

_lock = threading.Lock()
_fastembed_model = None
_active_backend: str | None = None

# The `bge-*-en` family is trained asymmetrically: passages are embedded bare, but
# queries must carry this instruction. fastembed's `query_embed()` is a passthrough
# for these ONNX builds (verified: it returns a vector identical to `embed()`), so
# the prefix has to be applied here. Without it, relevant and irrelevant passages
# score much closer together and the confidence gate cannot separate them.
BGE_QUERY_INSTRUCTION = "Represent this sentence for searching relevant passages: "


def _query_instruction() -> str:
    model = settings.embedding_model.lower()
    if "bge" in model and "-en" in model:
        return BGE_QUERY_INSTRUCTION
    # e5 models use their own convention.
    if model.startswith("intfloat/e5") or "/e5-" in model:
        return "query: "
    return ""


# ---------------------------------------------------------------------------
# BACKEND: fastembed (preferred)
# ---------------------------------------------------------------------------
def _load_fastembed():
    global _fastembed_model, _active_backend
    if _fastembed_model is not None:
        return _fastembed_model
    from fastembed import TextEmbedding  # imported lazily: optional dependency

    logger.info("Loading local embedding model %s ...", settings.embedding_model)
    _fastembed_model = TextEmbedding(model_name=settings.embedding_model)
    _active_backend = "fastembed"
    return _fastembed_model


# ---------------------------------------------------------------------------
# BACKEND: hashed bag-of-words (fallback)
# ---------------------------------------------------------------------------
_STOPWORDS = frozenset(
    """a an the and or but if then than of to in for on at by with from as is are was
    were be been being do does did doing have has had having i me my we our you your
    he she it they them this that these those what which who whom how when where why
    can will just should now""".split()
)


def _tokenize(text: str) -> List[str]:
    return [t for t in _TOKEN_RE.findall(text.lower()) if t not in _STOPWORDS]


def _hash_embed_one(text: str) -> List[float]:
    """Signed hashing trick over unigrams + bigrams, then L2 normalisation.

    Signed buckets keep unrelated collisions from inflating similarity, and
    bigrams recover a little word-order sensitivity.
    """
    vector = [0.0] * DIM
    tokens = _tokenize(text)
    if not tokens:
        return vector

    grams: List[str] = list(tokens)
    grams += [f"{a}_{b}" for a, b in zip(tokens, tokens[1:])]

    for gram in grams:
        digest = hashlib.blake2b(gram.encode("utf-8"), digest_size=8).digest()
        index = int.from_bytes(digest[:4], "big") % DIM
        sign = 1.0 if digest[4] & 1 else -1.0
        # Sub-linear term weighting, the same intuition as TF saturation in BM25.
        vector[index] += sign

    for i, value in enumerate(vector):
        if value:
            vector[i] = math.copysign(math.log1p(abs(value)), value)

    norm = math.sqrt(sum(v * v for v in vector))
    if norm:
        vector = [v / norm for v in vector]
    return vector


# ---------------------------------------------------------------------------
# PUBLIC API
# ---------------------------------------------------------------------------
def embed_texts(texts: Sequence[str], *, kind: str = "document") -> List[List[float]]:
    """Embed a batch. Returns one `DIM`-length float list per input string.

    `kind` matters: see BGE_QUERY_INSTRUCTION. Queries get the model's retrieval
    instruction prefix, passages do not.

    The hashing fallback is symmetric by construction, so `kind` is a no-op there.
    """
    global _active_backend
    if kind not in ("document", "query"):
        raise ValueError("kind must be 'document' or 'query'")

    cleaned = [(t or "").strip() for t in texts]
    if not cleaned:
        return []

    if settings.embedding_provider == "fastembed":
        try:
            with _lock:
                model = _load_fastembed()
            payload = cleaned
            if kind == "query":
                instruction = _query_instruction()
                if instruction:
                    payload = [f"{instruction}{t}" for t in cleaned]
            return [list(map(float, vec)) for vec in model.embed(payload)]
        except Exception as exc:  # noqa: BLE001 - degrade, never break the endpoint
            if _active_backend != "hash":
                logger.warning(
                    "fastembed unavailable (%s); falling back to the local hashing "
                    "embedder. Retrieval still works but is lexical rather than "
                    "semantic. `pip install fastembed` to enable the full model.",
                    exc,
                )
            _active_backend = "hash"

    if _active_backend is None:
        _active_backend = "hash"
    return [_hash_embed_one(t) for t in cleaned]


def embed_text(text: str) -> List[float]:
    """Embed a passage destined for storage."""
    return embed_texts([text], kind="document")[0]


def embed_query(text: str) -> List[float]:
    """Embed a user question for retrieval against stored passages."""
    return embed_texts([text], kind="query")[0]


def cosine_similarity(a: Sequence[float], b: Sequence[float]) -> float:
    dot = sum(x * y for x, y in zip(a, b))
    na = math.sqrt(sum(x * x for x in a))
    nb = math.sqrt(sum(y * y for y in b))
    return dot / (na * nb) if na and nb else 0.0


def embedding_backend_info() -> dict:
    """What is actually running right now (not what was merely configured)."""
    return {
        "configured_provider": settings.embedding_provider,
        "active_backend": _active_backend or "not_initialised",
        "model": settings.embedding_model
        if (_active_backend or settings.embedding_provider) == "fastembed"
        else "hashed-bow-384",
        "dimensions": DIM,
        "runs_locally": True,
    }


def warmup() -> None:
    """Pay the model load cost at startup rather than on a user's first question."""
    try:
        embed_text("warmup")
    except Exception as exc:  # noqa: BLE001
        logger.warning("Embedding warmup failed: %s", exc)


def chunk_text(
    text: str, *, chunk_size: int = 900, overlap: int = 150
) -> List[str]:
    """Split on paragraph boundaries where possible, with a sliding-window overlap.

    Overlap matters: an answer that straddles a chunk boundary would otherwise be
    unretrievable from either side.
    """
    normalised = re.sub(r"\n{3,}", "\n\n", (text or "").strip())
    if not normalised:
        return []
    if len(normalised) <= chunk_size:
        return [normalised]

    paragraphs = [p.strip() for p in normalised.split("\n\n") if p.strip()]
    chunks: List[str] = []
    current = ""

    for para in paragraphs:
        if len(para) > chunk_size:
            if current:
                chunks.append(current)
                current = ""
            step = max(1, chunk_size - overlap)
            for start in range(0, len(para), step):
                piece = para[start : start + chunk_size]
                if piece.strip():
                    chunks.append(piece.strip())
            continue

        candidate = f"{current}\n\n{para}" if current else para
        if len(candidate) <= chunk_size:
            current = candidate
        else:
            chunks.append(current)
            tail = current[-overlap:] if overlap else ""
            current = f"{tail}\n\n{para}".strip() if tail else para

    if current:
        chunks.append(current)
    return chunks
