"""Central application settings.

Single source of truth for every tunable. Nothing else in the codebase reads
`os.environ` directly (the one documented exception is the LLM provider factory,
which resolves through this module).
"""

from __future__ import annotations

import json
from functools import lru_cache
from typing import List, Literal

from pydantic import Field, field_validator
from pydantic_settings import BaseSettings, SettingsConfigDict

INSECURE_DEV_SECRET = "dev-only-insecure-change-me"


class Settings(BaseSettings):
    model_config = SettingsConfigDict(
        env_file=".env",
        env_file_encoding="utf-8",
        case_sensitive=False,
        extra="ignore",
    )

    # ---- App ---------------------------------------------------------------
    app_name: str = "PeoplePay360"
    environment: Literal["development", "staging", "production", "test"] = "development"
    api_v1_prefix: str = "/api/v1"
    debug: bool = True

    # ---- Database ----------------------------------------------------------
    database_url: str = (
        "postgresql+psycopg://peoplepay:peoplepay@localhost:5433/peoplepay360"
    )
    db_pool_size: int = 10
    db_max_overflow: int = 20
    db_echo: bool = False

    # ---- Security ----------------------------------------------------------
    jwt_secret: str = INSECURE_DEV_SECRET
    jwt_algorithm: str = "HS256"
    access_token_expire_minutes: int = 480
    cors_origins: List[str] = Field(
        default_factory=lambda: [
            "http://localhost:3000",
            "http://localhost:5173",
            "http://localhost:8080",
        ]
    )

    # ---- Company -----------------------------------------------------------
    company_name: str = "OXP Pvt Ltd"
    company_currency_symbol: str = "Rs."
    default_timezone: str = "Asia/Kolkata"

    # ---- AI: retrieval (always local) --------------------------------------
    embedding_provider: Literal["fastembed", "hash"] = "fastembed"
    embedding_model: str = "BAAI/bge-small-en-v1.5"
    embedding_dim: int = 384

    # ---- AI: generation (pluggable) ----------------------------------------
    llm_provider: Literal["groq", "gemini", "ollama", "extractive"] = "extractive"
    groq_api_key: str | None = None
    groq_model: str = "llama-3.3-70b-versatile"
    gemini_api_key: str | None = None
    gemini_model: str = "gemini-2.0-flash"
    ollama_host: str = "http://localhost:11434"
    ollama_model: str = "llama3.2:3b"

    # ---- AI: tuning --------------------------------------------------------
    # Calibrated, not guessed. `scripts/calibrate_threshold.py` scores a golden set
    # of answerable and unanswerable questions against the seeded corpus.
    #
    # Cosine floors are model-specific. bge-small-en-v1.5 scores completely
    # unrelated English prose at ~0.40-0.59, and plausible-but-undocumented
    # questions ("what is the standing desk allowance?") reach ~0.61. The
    # architecture document's 0.45 therefore admits most nonsense. At 0.65 the
    # golden set yields zero confident-but-wrong answers; the handful of genuine
    # questions that fall below it escalate to a human, which is the safe
    # direction. Re-run the calibration after changing EMBEDDING_MODEL or the
    # corpus.
    rag_confidence_threshold: float = 0.65
    rag_dedup_threshold: float = 0.90
    rag_top_k: int = 3
    max_open_tickets_per_employee: int = 5

    # ---- Email -------------------------------------------------------------
    smtp_host: str | None = None
    smtp_port: int = 587
    smtp_user: str | None = None
    smtp_password: str | None = None
    smtp_from: str = "payroll@oxp.example.com"
    smtp_use_tls: bool = True

    @field_validator("cors_origins", mode="before")
    @classmethod
    def _parse_cors(cls, value):
        """Accept both a JSON array and a comma separated list."""
        if isinstance(value, str):
            value = value.strip()
            if not value:
                return []
            if value.startswith("["):
                return json.loads(value)
            return [origin.strip() for origin in value.split(",") if origin.strip()]
        return value

    @property
    def is_production(self) -> bool:
        return self.environment == "production"

    def assert_production_safe(self) -> None:
        """Fail fast rather than run production on a known-public secret."""
        if self.is_production and self.jwt_secret == INSECURE_DEV_SECRET:
            raise RuntimeError(
                "JWT_SECRET is still the development default. Refusing to start in "
                "production. Set a strong random JWT_SECRET."
            )


@lru_cache(maxsize=1)
def get_settings() -> Settings:
    settings = Settings()
    settings.assert_production_safe()
    return settings


settings = get_settings()
