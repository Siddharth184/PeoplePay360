"""Auth, user management and notification schemas."""

from __future__ import annotations

import uuid
from datetime import datetime
from typing import List, Optional

from pydantic import BaseModel, EmailStr, Field

from app.models.enums import UserRole
from app.schemas.common import ORMModel


class LoginRequest(BaseModel):
    email: EmailStr
    password: str = Field(min_length=1, max_length=256)


class TokenResponse(BaseModel):
    access_token: str
    token_type: str = "bearer"
    expires_in: int
    role: UserRole
    user_id: str
    employee_id: Optional[str] = None
    employee_name: Optional[str] = None
    permissions: List[str]


class MeResponse(BaseModel):
    user_id: str
    email: EmailStr
    role: UserRole
    is_active: bool
    permissions: List[str]
    employee_id: Optional[str] = None
    employee_name: Optional[str] = None
    badge_id: Optional[str] = None
    department: Optional[str] = None
    job_position: Optional[str] = None
    manager_name: Optional[str] = None
    unread_notifications: int = 0


class UserCreate(BaseModel):
    email: EmailStr
    password: str = Field(min_length=8, max_length=256)
    role: UserRole = UserRole.EMPLOYEE
    employee_id: Optional[uuid.UUID] = None
    is_active: bool = True


class UserUpdate(BaseModel):
    role: Optional[UserRole] = None
    is_active: Optional[bool] = None
    password: Optional[str] = Field(default=None, min_length=8, max_length=256)


class UserOut(ORMModel):
    id: uuid.UUID
    email: EmailStr
    role: UserRole
    is_active: bool
    created_at: datetime


class UserWithEmployeeOut(UserOut):
    employee_id: Optional[uuid.UUID] = None
    employee_name: Optional[str] = None
    badge_id: Optional[str] = None


class PasswordChangeRequest(BaseModel):
    current_password: str
    new_password: str = Field(min_length=8, max_length=256)


class NotificationOut(ORMModel):
    id: uuid.UUID
    kind: str
    title: str
    body: Optional[str] = None
    deep_link: Optional[str] = None
    escalation_id: Optional[uuid.UUID] = None
    is_read: bool
    created_at: datetime
