"""Shared schema primitives."""

from __future__ import annotations

from typing import Generic, List, TypeVar

from pydantic import BaseModel, ConfigDict, Field

T = TypeVar("T")


class ORMModel(BaseModel):
    """Base for anything read directly off a SQLAlchemy row."""

    model_config = ConfigDict(from_attributes=True)


class Page(BaseModel, Generic[T]):
    total: int
    limit: int
    offset: int
    items: List[T]


class MessageResponse(BaseModel):
    detail: str


class IdResponse(BaseModel):
    id: str


class PaginationParams(BaseModel):
    limit: int = Field(default=50, ge=1, le=200)
    offset: int = Field(default=0, ge=0)
