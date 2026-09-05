"""Shared enumerations.

Every member's *name* equals its *value* so the SQLAlchemy native-enum binding
(which sends the member name) always matches the PostgreSQL enum labels defined
in db/schema.sql. Getting that wrong is a classic silent-corruption bug.
"""

from __future__ import annotations

import enum


class UserRole(str, enum.Enum):
    ADMIN = "ADMIN"
    HR_PAYROLL_MANAGER = "HR_PAYROLL_MANAGER"
    HR_PAYROLL_USER = "HR_PAYROLL_USER"
    HR_MANAGER = "HR_MANAGER"
    EMPLOYEE = "EMPLOYEE"


class EmployeeStatus(str, enum.Enum):
    ACTIVE = "ACTIVE"
    INACTIVE = "INACTIVE"
    TERMINATED = "TERMINATED"


class ContractStatus(str, enum.Enum):
    DRAFT = "DRAFT"
    RUNNING = "RUNNING"
    EXPIRED = "EXPIRED"
    CANCELLED = "CANCELLED"


class AttendanceStatus(str, enum.Enum):
    PRESENT = "PRESENT"
    LATE = "LATE"
    ABSENT = "ABSENT"
    HALF_DAY = "HALF_DAY"


class ApprovalStatus(str, enum.Enum):
    TO_APPROVE = "TO_APPROVE"
    APPROVED = "APPROVED"
    REFUSED = "REFUSED"


class RuleCategory(str, enum.Enum):
    BASIC = "BASIC"
    ALLOWANCE = "ALLOWANCE"
    GROSS = "GROSS"
    DEDUCTION = "DEDUCTION"
    NET = "NET"


class ComputationType(str, enum.Enum):
    FIXED = "FIXED"
    PERCENTAGE = "PERCENTAGE"
    PYTHON_CODE = "PYTHON_CODE"


class PayrunStatus(str, enum.Enum):
    DRAFT = "DRAFT"
    COMPUTED = "COMPUTED"
    VALIDATED = "VALIDATED"
    PAID = "PAID"


class PayslipStatus(str, enum.Enum):
    DRAFT = "DRAFT"
    DONE = "DONE"
    PAID = "PAID"


class EscalationStatus(str, enum.Enum):
    OPEN = "OPEN"
    ASSIGNED = "ASSIGNED"
    ANSWERED = "ANSWERED"
    CLOSED = "CLOSED"
    REJECTED = "REJECTED"


class EscalationPriority(str, enum.Enum):
    LOW = "LOW"
    NORMAL = "NORMAL"
    HIGH = "HIGH"
    URGENT = "URGENT"


class EscalationCategory(str, enum.Enum):
    LEAVE_POLICY = "LEAVE_POLICY"
    PAYROLL_SALARY = "PAYROLL_SALARY"
    ATTENDANCE = "ATTENDANCE"
    CONTRACT = "CONTRACT"
    TAX_STATUTORY = "TAX_STATUTORY"
    IT_ACCESS = "IT_ACCESS"
    OTHER = "OTHER"


class EscalationReason(str, enum.Enum):
    LOW_CONFIDENCE = "LOW_CONFIDENCE"
    NO_CONTEXT = "NO_CONTEXT"
    NO_TOOL_MATCH = "NO_TOOL_MATCH"
    USER_REQUESTED = "USER_REQUESTED"


class CopilotMode(str, enum.Enum):
    TIER0_TEMPLATE = "TIER0_TEMPLATE"
    ANSWERED = "ANSWERED"
    ESCALATED = "ESCALATED"
    REUSED = "REUSED"


class NotificationKind(str, enum.Enum):
    ESCALATION_NEW = "ESCALATION_NEW"
    ESCALATION_ANSWERED = "ESCALATION_ANSWERED"
    ESCALATION_OVERDUE = "ESCALATION_OVERDUE"
    PAYSLIP_SENT = "PAYSLIP_SENT"
    TIMEOFF_DECISION = "TIMEOFF_DECISION"
