"""Importing this package registers every ORM mapping on ``Base.metadata``.

Import order matters only insofar as every model must be imported before the
first query is issued, otherwise SQLAlchemy cannot resolve string-based
relationship targets.
"""

from app.models.attendance import Attendance
from app.models.auth import AuthUser, Notification
from app.models.contract import HrContract
from app.models.employee import PRIVATE_FIELDS, Employee
from app.models.master import (
    DAY_NAMES,
    Department,
    JobPosition,
    PublicHoliday,
    WorkingSchedule,
    WorkingScheduleLine,
)
from app.models.payrun import Payrun, Payslip, PayslipLine
from app.models.rag import (
    AiConversation,
    AiMessage,
    DocumentChunk,
    EscalationRoutingRule,
    RagEscalation,
    RagEscalationEvent,
    RagRetrievalLog,
)
from app.models.salary import SalaryRule, SalaryStructure
from app.models.timeoff import LeaveAllocation, LeaveRequest, TimeOffType

__all__ = [
    "Attendance",
    "AuthUser",
    "Notification",
    "HrContract",
    "Employee",
    "PRIVATE_FIELDS",
    "DAY_NAMES",
    "Department",
    "JobPosition",
    "PublicHoliday",
    "WorkingSchedule",
    "WorkingScheduleLine",
    "Payrun",
    "Payslip",
    "PayslipLine",
    "AiConversation",
    "AiMessage",
    "DocumentChunk",
    "EscalationRoutingRule",
    "RagEscalation",
    "RagEscalationEvent",
    "RagRetrievalLog",
    "SalaryRule",
    "SalaryStructure",
    "LeaveAllocation",
    "LeaveRequest",
    "TimeOffType",
]
