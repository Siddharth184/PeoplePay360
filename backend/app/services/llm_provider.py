"""Pluggable generation layer.

ARCHITECTURAL CONTRACT
----------------------
1. Retrieval (embeddings + pgvector) is ALWAYS local and NEVER passes through here.
2. This module only ever receives text that has already passed redact_pii().
3. Every adapter must degrade to ExtractiveProvider rather than raise, so a
   provider outage can never break the product.
"""

from __future__ import annotations

import logging
import re
from abc import ABC, abstractmethod
from typing import Dict, List, Optional

import httpx

from app.core.config import settings

logger = logging.getLogger(__name__)

REQUEST_TIMEOUT_SECONDS = 20

SYSTEM_PROMPT = (
    "You are the PeoplePay360 HR assistant. Answer ONLY from the CONTEXT provided. "
    "Never invent policy, amounts, dates, or entitlements. If the CONTEXT is "
    "insufficient, reply exactly: INSUFFICIENT_CONTEXT. Be concise and factual."
)

INSUFFICIENT_CONTEXT_SENTINEL = "INSUFFICIENT_CONTEXT"

# ---------------------------------------------------------------------------
# PII BOUNDARY: nothing leaves the process without passing through here.
# ---------------------------------------------------------------------------
_PII_PATTERNS = [
    (re.compile(r"\b[A-Z]{4}0[A-Z0-9]{6}\b"), "[IFSC_REDACTED]"),      # IFSC first:
    (re.compile(r"\b[A-Z]{5}\d{4}[A-Z]\b"), "[PAN_REDACTED]"),          # Indian PAN
    (re.compile(r"\b\d{3}-\d{2}-\d{4}\b"), "[SSN_REDACTED]"),           # US SSN
    (re.compile(r"\b\d{9,18}\b"), "[ACCOUNT_REDACTED]"),                # bank accounts
    (re.compile(r"\b[\w.+-]+@[\w-]+\.[\w.-]+\b"), "[EMAIL_REDACTED]"),  # work emails
    (re.compile(r"(?<!\d)(?:\+91[\s-]?)?[6-9]\d{9}(?!\d)"), "[PHONE_REDACTED]"),
]


def redact_pii(text: str) -> str:
    """Defence in depth.

    Personal identifiers must never reach a third-party API, even though the
    prompt builder is not supposed to include them. Patterns are ordered
    longest/most-specific first so a broader rule cannot swallow a narrower one.
    """
    if not text:
        return text
    for pattern, replacement in _PII_PATTERNS:
        text = pattern.sub(replacement, text)
    return text


class LLMProvider(ABC):
    """The port. Swapping implementations must require zero caller changes."""

    name: str = "abstract"

    @abstractmethod
    def generate(self, prompt: str, context_chunks: Optional[List[Dict]] = None) -> str:
        ...

    def health(self) -> bool:
        return True


# ---------------------------------------------------------------------------
# TIER 3 - always available, never fails, requires nothing.
# ---------------------------------------------------------------------------
class ExtractiveProvider(LLMProvider):
    """No LLM. Returns the strongest retrieved passage verbatim with attribution.

    This is not a degraded gimmick: for an HR policy bot, quoting the handbook
    exactly is arguably MORE trustworthy than paraphrasing it.
    """

    name = "extractive"

    def generate(self, prompt: str, context_chunks: Optional[List[Dict]] = None) -> str:
        if not context_chunks:
            return (
                "I couldn't find anything in the HR knowledge base about that. "
                "I can forward your question to the HR team if you'd like."
            )
        top = context_chunks[0]
        body = (top.get("content") or "").strip()
        answer = [
            "Here is what the official documentation says:",
            "",
            "\n".join(f"> {line}" for line in body.splitlines() if line.strip()),
            "",
            f"Source: {top.get('title', 'HR knowledge base')}",
        ]
        if len(context_chunks) > 1:
            others = ", ".join(c.get("title", "") for c in context_chunks[1:])
            answer.append(f"Related sections: {others}")
        return "\n".join(answer)


# ---------------------------------------------------------------------------
# TIER 2a - RECOMMENDED. OpenAI-compatible, fastest free tier.
# ---------------------------------------------------------------------------
class GroqProvider(LLMProvider):
    name = "groq"
    ENDPOINT = "https://api.groq.com/openai/v1/chat/completions"

    def __init__(self, api_key: str, model: str = "llama-3.3-70b-versatile") -> None:
        self.api_key = api_key
        self.model = model

    def generate(self, prompt: str, context_chunks: Optional[List[Dict]] = None) -> str:
        try:
            response = httpx.post(
                self.ENDPOINT,
                timeout=REQUEST_TIMEOUT_SECONDS,
                headers={"Authorization": f"Bearer {self.api_key}"},
                json={
                    "model": self.model,
                    "temperature": 0.1,  # factual, not creative
                    "max_tokens": 700,
                    "messages": [
                        {"role": "system", "content": SYSTEM_PROMPT},
                        {"role": "user", "content": prompt},
                    ],
                },
            )
            response.raise_for_status()
            text = response.json()["choices"][0]["message"]["content"].strip()
            if INSUFFICIENT_CONTEXT_SENTINEL in text:
                return ExtractiveProvider().generate(prompt, context_chunks)
            return text
        except Exception as exc:  # noqa: BLE001
            # Rate limited (429), key invalid, or offline -> degrade, never crash.
            logger.warning("Groq unavailable (%s); falling back to extractive.", exc)
            return ExtractiveProvider().generate(prompt, context_chunks)


# ---------------------------------------------------------------------------
# TIER 2b - BACKUP KEY.
# ---------------------------------------------------------------------------
class GeminiProvider(LLMProvider):
    name = "gemini"
    ENDPOINT = "https://generativelanguage.googleapis.com/v1beta/models/{model}:generateContent"

    def __init__(self, api_key: str, model: str = "gemini-2.0-flash") -> None:
        self.api_key = api_key
        self.model = model

    def generate(self, prompt: str, context_chunks: Optional[List[Dict]] = None) -> str:
        try:
            response = httpx.post(
                self.ENDPOINT.format(model=self.model),
                timeout=REQUEST_TIMEOUT_SECONDS,
                params={"key": self.api_key},
                json={
                    "systemInstruction": {"parts": [{"text": SYSTEM_PROMPT}]},
                    "contents": [{"parts": [{"text": prompt}]}],
                    "generationConfig": {"temperature": 0.1, "maxOutputTokens": 700},
                },
            )
            response.raise_for_status()
            text = response.json()["candidates"][0]["content"]["parts"][0]["text"].strip()
            if INSUFFICIENT_CONTEXT_SENTINEL in text:
                return ExtractiveProvider().generate(prompt, context_chunks)
            return text
        except Exception as exc:  # noqa: BLE001
            logger.warning("Gemini unavailable (%s); falling back to extractive.", exc)
            return ExtractiveProvider().generate(prompt, context_chunks)


# ---------------------------------------------------------------------------
# TIER 2c - only worthwhile on a GPU box or for air-gapped deployment.
# ---------------------------------------------------------------------------
class OllamaProvider(LLMProvider):
    name = "ollama"

    def __init__(
        self, host: str = "http://localhost:11434", model: str = "llama3.2:3b"
    ) -> None:
        self.host = host.rstrip("/")
        self.model = model

    def generate(self, prompt: str, context_chunks: Optional[List[Dict]] = None) -> str:
        try:
            response = httpx.post(
                f"{self.host}/api/generate",
                timeout=120,  # CPU inference is slow; generous timeout
                json={
                    "model": self.model,
                    "system": SYSTEM_PROMPT,
                    "prompt": prompt,
                    "stream": False,
                    "options": {"temperature": 0.1},
                },
            )
            response.raise_for_status()
            text = response.json()["response"].strip()
            if INSUFFICIENT_CONTEXT_SENTINEL in text:
                return ExtractiveProvider().generate(prompt, context_chunks)
            return text
        except Exception as exc:  # noqa: BLE001
            logger.warning("Ollama unavailable (%s); falling back to extractive.", exc)
            return ExtractiveProvider().generate(prompt, context_chunks)

    def health(self) -> bool:
        try:
            return httpx.get(f"{self.host}/api/tags", timeout=3).status_code == 200
        except Exception:  # noqa: BLE001
            return False


# ---------------------------------------------------------------------------
# FACTORY - single source of truth, cached for process lifetime.
# ---------------------------------------------------------------------------
_provider_singleton: Optional[LLMProvider] = None


def get_llm_provider() -> LLMProvider:
    """Resolve the provider from configuration ONCE.

    Falls back to extractive whenever the selected provider is misconfigured, so
    a missing API key degrades answer *style* instead of taking down the endpoint.
    """
    global _provider_singleton
    if _provider_singleton is not None:
        return _provider_singleton

    choice = (settings.llm_provider or "extractive").strip().lower()

    if choice == "groq":
        key = settings.groq_api_key
        _provider_singleton = (
            GroqProvider(key, settings.groq_model) if key else ExtractiveProvider()
        )
    elif choice == "gemini":
        key = settings.gemini_api_key
        _provider_singleton = (
            GeminiProvider(key, settings.gemini_model) if key else ExtractiveProvider()
        )
    elif choice == "ollama":
        _provider_singleton = OllamaProvider(settings.ollama_host, settings.ollama_model)
    else:
        _provider_singleton = ExtractiveProvider()

    if _provider_singleton.name == "extractive" and choice != "extractive":
        logger.warning(
            "LLM_PROVIDER=%s selected but not configured; running in extractive mode. "
            "Retrieval and SQL answers are unaffected.",
            choice,
        )

    logger.info("LLM provider active: %s", _provider_singleton.name)
    return _provider_singleton


def reset_llm_provider() -> None:
    """Test hook: drop the cached singleton so a new configuration takes effect."""
    global _provider_singleton
    _provider_singleton = None
