"""FastAPI application entrypoint."""

from __future__ import annotations

import logging
from contextlib import asynccontextmanager

from fastapi import FastAPI
from fastapi.middleware.cors import CORSMiddleware
from sqlalchemy import text

from app.api.v1.router import api_router
from app.core.config import settings
from app.core.database import engine
from app.core.errors import register_exception_handlers

# Importing the models package registers every ORM mapping before the first query.
import app.models  # noqa: F401

logging.basicConfig(
    level=logging.DEBUG if settings.debug else logging.INFO,
    format="%(asctime)s %(levelname)-8s %(name)s: %(message)s",
)
logger = logging.getLogger("peoplepay360")

DESCRIPTION = """
Enterprise HR & Payroll platform with a local-first AI copilot.

**What makes this backend different**

* **Zero-loophole integrity** - overlapping RUNNING contracts, duplicate payslips,
  negative leave balances and double-open attendance punches are all impossible,
  enforced by database constraints and triggers rather than by hopeful application code.
* **AST-safe salary rules** - Odoo-style Python formulas run inside a sandbox that
  allowlists AST nodes, blocks dunder attribute access, and executes with empty
  builtins. Every amount is `Decimal`, never a float.
* **Two-step payrun wizard** - step 1 is a read-only dry run that reports every
  pre-flight anomaly; nothing is written until an operator selects employees.
* **An assistant that refuses to guess** - retrieval and all personal-data answers
  are 100% local and deterministic. When retrieval confidence is too low the
  question is escalated to the right human, and their verified answer is embedded
  back into the knowledge base so the same question is answered automatically
  next time. No model training anywhere.
"""


@asynccontextmanager
async def lifespan(app: FastAPI):
    logger.info("Starting %s (%s)", settings.app_name, settings.environment)

    # Fail loudly at boot if the database or pgvector is missing, rather than at
    # the first user request.
    try:
        with engine.connect() as conn:
            version = conn.execute(text("SHOW server_version")).scalar()
            has_vector = conn.execute(
                text("SELECT COUNT(*) FROM pg_extension WHERE extname = 'vector'")
            ).scalar()
        logger.info("PostgreSQL %s connected; pgvector installed: %s", version, bool(has_vector))
        if not has_vector:
            logger.warning(
                "pgvector extension is NOT installed. Run db/schema.sql before "
                "using any AI endpoint."
            )
    except Exception as exc:  # noqa: BLE001
        logger.error(
            "Database unavailable at startup: %s. Bring it up with "
            "`docker compose up -d db` and apply db/schema.sql.",
            exc,
        )

    # Pay the embedding model load cost now, not on a user's first question.
    from app.services.embedding import warmup

    warmup()

    from app.services.llm_provider import get_llm_provider

    get_llm_provider()

    yield
    logger.info("Shutting down %s", settings.app_name)


app = FastAPI(
    title=f"{settings.app_name} API",
    description=DESCRIPTION,
    version="1.0.0",
    lifespan=lifespan,
    docs_url="/docs",
    redoc_url="/redoc",
    openapi_url="/openapi.json",
)

app.add_middleware(
    CORSMiddleware,
    allow_origins=settings.cors_origins,
    allow_credentials=True,
    allow_methods=["*"],
    allow_headers=["*"],
)

register_exception_handlers(app)
app.include_router(api_router, prefix=settings.api_v1_prefix)


@app.get("/", tags=["Meta"], summary="Service banner")
def root() -> dict:
    return {
        "service": settings.app_name,
        "version": "1.0.0",
        "environment": settings.environment,
        "docs": "/docs",
        "api": settings.api_v1_prefix,
    }


@app.get("/health", tags=["Meta"], summary="Liveness and dependency health")
def health() -> dict:
    from app.services.embedding import embedding_backend_info
    from app.services.llm_provider import get_llm_provider

    database_ok = True
    pgvector_ok = False
    detail: str | None = None
    try:
        with engine.connect() as conn:
            conn.execute(text("SELECT 1"))
            pgvector_ok = bool(
                conn.execute(
                    text("SELECT COUNT(*) FROM pg_extension WHERE extname = 'vector'")
                ).scalar()
            )
    except Exception as exc:  # noqa: BLE001
        database_ok = False
        detail = str(exc)

    provider = get_llm_provider()
    return {
        "status": "ok" if database_ok and pgvector_ok else "degraded",
        "database": {"connected": database_ok, "pgvector": pgvector_ok, "detail": detail},
        "embeddings": embedding_backend_info(),
        "llm_provider": {"active": provider.name, "configured": settings.llm_provider},
    }
