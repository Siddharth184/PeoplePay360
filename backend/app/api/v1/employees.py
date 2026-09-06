"""Employee master data, departments, job positions and working schedules."""

from __future__ import annotations

import uuid
from typing import List, Optional

from fastapi import APIRouter, Depends, Query
from sqlalchemy import delete, func, select
from sqlalchemy.orm import aliased, selectinload

from app.api.deps import DbSession, PageParams, User, get_employee_or_404
from app.core.config import settings
from app.core.errors import ConflictError, NotFoundError, ValidationError
from app.core.security import (
    CurrentUser,
    hash_password,
    require_admin,
    require_hr,
    revoke_sessions,
)
from app.models.attendance import Attendance
from app.models.auth import AuthUser
from app.models.contract import HrContract
from app.models.employee import PRIVATE_FIELDS, Employee
from app.models.enums import UserRole
from app.models.master import (
    DAY_NAMES,
    Department,
    JobPosition,
    PublicHoliday,
    WorkingSchedule,
    WorkingScheduleLine,
)
from app.models.payrun import Payslip
from app.models.rag import RagEscalation
from app.models.timeoff import LeaveRequest
from app.schemas.common import MessageResponse
from app.schemas.hr import (
    ContractOut,
    DepartmentCreate,
    DepartmentUpdate,
    DepartmentWithStatsOut,
    EmployeeCreate,
    EmployeeDetailOut,
    EmployeeOut,
    EmployeeSmartCounts,
    EmployeeUpdate,
    JobPositionCreate,
    JobPositionOut,
    JobPositionUpdate,
    PublicHolidayCreate,
    PublicHolidayOut,
    WorkingScheduleCreate,
    WorkingScheduleOut,
    WorkingScheduleUpdate,
)
from app.services.timeoff_service import leave_balance

router = APIRouter(tags=["Employees & Master Data"])


# ===========================================================================
# SERIALISATION WITH PRIVATE-FIELD GATING
# ===========================================================================
def _serialise_employee(
    employee: Employee, *, include_private: bool
) -> EmployeeOut:
    """Private banking / tax identifiers are omitted unless the role allows them.

    Gating happens here, in one place, so a new endpoint cannot accidentally leak
    them by forgetting a filter.
    """
    data = {
        "id": employee.id,
        "badge_id": employee.badge_id,
        "name": employee.name,
        "work_email": employee.work_email,
        "phone": employee.phone,
        "department_id": employee.department_id,
        "department_name": employee.department.name if employee.department else None,
        "job_position_id": employee.job_position_id,
        "job_position_name": (
            employee.job_position.name if employee.job_position else None
        ),
        "manager_id": employee.manager_id,
        "manager_name": employee.manager.name if employee.manager else None,
        "working_schedule_id": employee.working_schedule_id,
        "working_schedule_name": (
            employee.working_schedule.name if employee.working_schedule else None
        ),
        "work_location": employee.work_location,
        "status": employee.status,
        "employee_type": employee.employee_type,
        "company_name": employee.company_name,
        "date_of_joining": employee.date_of_joining,
        "user_id": employee.user_id,
        "has_login": employee.user_id is not None,
        "created_at": employee.created_at,
    }
    if include_private:
        for field in PRIVATE_FIELDS:
            data[field] = getattr(employee, field)
    return EmployeeOut(**data)


# ===========================================================================
# DEPARTMENTS
# ===========================================================================
@router.get(
    "/departments",
    response_model=List[DepartmentWithStatsOut],
    summary="List departments with headcount and manager",
)
def list_departments(db: DbSession, user: User) -> List[DepartmentWithStatsOut]:
    # Two aliases are needed: one for the department's manager, one for the
    # members being counted. Reusing a single Employee entity would join twice
    # on the same table and silently produce wrong counts.
    manager = aliased(Employee, name="dept_manager")
    member = aliased(Employee, name="dept_member")
    rows = db.execute(
        select(
            Department,
            manager.name,
            func.count(member.id).label("employee_count"),
        )
        .outerjoin(manager, manager.id == Department.manager_employee_id)
        .outerjoin(member, member.department_id == Department.id)
        .group_by(Department.id, manager.name)
        .order_by(Department.name)
    ).all()
    return [
        DepartmentWithStatsOut(
            id=dept.id,
            name=dept.name,
            manager_employee_id=dept.manager_employee_id,
            is_active=dept.is_active,
            created_at=dept.created_at,
            manager_name=manager_name,
            employee_count=count,
        )
        for dept, manager_name, count in rows
    ]


@router.post(
    "/departments",
    response_model=DepartmentWithStatsOut,
    status_code=201,
    summary="Create a department",
)
def create_department(
    payload: DepartmentCreate, db: DbSession, _: CurrentUser = Depends(require_hr)
) -> DepartmentWithStatsOut:
    department = Department(
        name=payload.name,
        manager_employee_id=payload.manager_employee_id,
        is_active=payload.is_active,
    )
    db.add(department)
    db.commit()
    db.refresh(department)
    return DepartmentWithStatsOut(
        id=department.id,
        name=department.name,
        manager_employee_id=department.manager_employee_id,
        is_active=department.is_active,
        created_at=department.created_at,
        manager_name=department.manager.name if department.manager else None,
        employee_count=0,
    )


# ===========================================================================
# JOB POSITIONS
# ===========================================================================
@router.get(
    "/job-positions",
    response_model=List[JobPositionOut],
    summary="List job positions",
)
def list_job_positions(
    db: DbSession,
    user: User,
    department_id: Optional[uuid.UUID] = Query(default=None),
) -> List[JobPositionOut]:
    stmt = select(JobPosition).order_by(JobPosition.name)
    if department_id:
        stmt = stmt.where(JobPosition.department_id == department_id)
    return [
        JobPositionOut.model_validate(p)
        for p in db.execute(stmt).scalars().all()
    ]


@router.post(
    "/job-positions",
    response_model=JobPositionOut,
    status_code=201,
    summary="Create a job position",
)
def create_job_position(
    payload: JobPositionCreate, db: DbSession, _: CurrentUser = Depends(require_hr)
) -> JobPositionOut:
    if not db.get(Department, payload.department_id):
        raise NotFoundError(f"Department {payload.department_id} not found.")
    position = JobPosition(name=payload.name, department_id=payload.department_id)
    db.add(position)
    db.commit()
    db.refresh(position)
    return JobPositionOut.model_validate(position)


# ===========================================================================
# WORKING SCHEDULES
# ===========================================================================
@router.get(
    "/schedules",
    response_model=List[WorkingScheduleOut],
    summary="List working schedules with their day lines",
)
def list_schedules(db: DbSession, user: User) -> List[WorkingScheduleOut]:
    schedules = (
        db.execute(
            select(WorkingSchedule)
            .options(selectinload(WorkingSchedule.lines))
            .order_by(WorkingSchedule.name)
        )
        .scalars()
        .all()
    )
    return [WorkingScheduleOut.model_validate(s) for s in schedules]


@router.post(
    "/schedules",
    response_model=WorkingScheduleOut,
    status_code=201,
    summary="Create a schedule with day lines; work_hours is computed by the database",
)
def create_schedule(
    payload: WorkingScheduleCreate, db: DbSession, _: CurrentUser = Depends(require_hr)
) -> WorkingScheduleOut:
    schedule = WorkingSchedule(
        name=payload.name,
        company_name=payload.company_name or settings.company_name,
        days_per_week=payload.days_per_week,
        hours_per_week=payload.hours_per_week,
        timezone=payload.timezone or settings.default_timezone,
    )
    db.add(schedule)
    db.flush()

    for line in payload.lines:
        db.add(
            WorkingScheduleLine(
                schedule_id=schedule.id,
                day_of_week=line.day_of_week,
                day_name=line.day_name or DAY_NAMES[line.day_of_week],
                start_time=line.start_time,
                end_time=line.end_time,
                break_hours=line.break_hours,
            )
        )

    db.commit()
    # Re-read so the database-generated work_hours values come back populated.
    db.expire_all()
    schedule = db.execute(
        select(WorkingSchedule)
        .options(selectinload(WorkingSchedule.lines))
        .where(WorkingSchedule.id == schedule.id)
    ).scalars().one()
    return WorkingScheduleOut.model_validate(schedule)


# ===========================================================================
# PUBLIC HOLIDAYS
# ===========================================================================
@router.get(
    "/holidays", response_model=List[PublicHolidayOut], summary="List public holidays"
)
def list_holidays(db: DbSession, user: User) -> List[PublicHolidayOut]:
    rows = (
        db.execute(select(PublicHoliday).order_by(PublicHoliday.holiday_date))
        .scalars()
        .all()
    )
    return [PublicHolidayOut.model_validate(h) for h in rows]


@router.post(
    "/holidays",
    response_model=PublicHolidayOut,
    status_code=201,
    summary="Add a public holiday (excluded from expected working days)",
)
def create_holiday(
    payload: PublicHolidayCreate, db: DbSession, _: CurrentUser = Depends(require_hr)
) -> PublicHolidayOut:
    holiday = PublicHoliday(name=payload.name, holiday_date=payload.holiday_date)
    db.add(holiday)
    db.commit()
    db.refresh(holiday)
    return PublicHolidayOut.model_validate(holiday)


# ===========================================================================
# EMPLOYEES
# ===========================================================================
@router.get(
    "/employees",
    response_model=List[EmployeeOut],
    summary="Searchable, filterable employee list (Kanban / List views)",
)
def list_employees(
    db: DbSession,
    page: PageParams,
    user: CurrentUser = Depends(require_hr),
    search: Optional[str] = Query(default=None, max_length=120),
    department_id: Optional[uuid.UUID] = Query(default=None),
    job_position_id: Optional[uuid.UUID] = Query(default=None),
    status: Optional[str] = Query(default=None),
    manager_id: Optional[uuid.UUID] = Query(default=None),
    has_running_contract: Optional[bool] = Query(default=None),
) -> List[EmployeeOut]:
    stmt = (
        select(Employee)
        .options(
            selectinload(Employee.department),
            selectinload(Employee.job_position),
            selectinload(Employee.manager),
            selectinload(Employee.working_schedule),
        )
        .order_by(Employee.badge_id)
    )
    if search:
        pattern = f"%{search}%"
        stmt = stmt.where(
            Employee.name.ilike(pattern)
            | Employee.work_email.ilike(pattern)
            | Employee.badge_id.ilike(pattern)
        )
    if department_id:
        stmt = stmt.where(Employee.department_id == department_id)
    if job_position_id:
        stmt = stmt.where(Employee.job_position_id == job_position_id)
    if status:
        stmt = stmt.where(Employee.status == status)
    if manager_id:
        stmt = stmt.where(Employee.manager_id == manager_id)
    if has_running_contract is not None:
        running = select(HrContract.employee_id).where(HrContract.status == "RUNNING")
        stmt = (
            stmt.where(Employee.id.in_(running))
            if has_running_contract
            else stmt.where(Employee.id.not_in(running))
        )

    employees = db.execute(stmt.limit(page.limit).offset(page.offset)).scalars().all()
    return [
        _serialise_employee(e, include_private=user.can_see_private_data)
        for e in employees
    ]


@router.post(
    "/employees",
    response_model=EmployeeOut,
    status_code=201,
    summary="Create an employee master record, optionally provisioning a login",
)
def create_employee(
    payload: EmployeeCreate, db: DbSession, user: CurrentUser = Depends(require_hr)
) -> EmployeeOut:
    badge_id = payload.badge_id or _generate_badge_id(db)

    if db.execute(
        select(Employee).where(Employee.badge_id == badge_id)
    ).scalars().first():
        raise ConflictError(f"Badge ID {badge_id} is already in use.")
    if db.execute(
        select(Employee).where(
            func.lower(Employee.work_email) == payload.work_email.lower()
        )
    ).scalars().first():
        raise ConflictError(f"Work email {payload.work_email} is already in use.")

    department_id = payload.department_id
    if not department_id and payload.department_name:
        dept_obj = db.execute(
            select(Department).where(func.lower(Department.name) == payload.department_name.lower().trim())
        ).scalars().first()
        if dept_obj:
            department_id = dept_obj.id

    job_position_id = payload.job_position_id
    if not job_position_id and payload.job_position_name:
        jp_obj = db.execute(
            select(JobPosition).where(func.lower(JobPosition.name) == payload.job_position_name.lower().trim())
        ).scalars().first()
        if jp_obj:
            job_position_id = jp_obj.id

    manager_id = payload.manager_id
    if not manager_id and payload.manager_name:
        mgr_obj = db.execute(
            select(Employee).where(func.lower(Employee.name).like(f"%{payload.manager_name.lower().trim()}%"))
        ).scalars().first()
        if mgr_obj:
            manager_id = mgr_obj.id

    if department_id and not db.get(Department, department_id):
        raise NotFoundError("Department not found.")
    if job_position_id and not db.get(JobPosition, job_position_id):
        raise NotFoundError("Job position not found.")
    if payload.working_schedule_id and not db.get(
        WorkingSchedule, payload.working_schedule_id
    ):
        raise NotFoundError("Working schedule not found.")
    if manager_id and not db.get(Employee, manager_id):
        raise NotFoundError("Manager employee not found.")

    if payload.create_login and not user.is_admin:
        raise ValidationError(
            "Only an administrator may provision a login. Create the employee "
            "first, then ask an admin to create the account."
        )

    employee = Employee(
        badge_id=badge_id,
        name=payload.name,
        work_email=payload.work_email,
        phone=payload.phone,
        department_id=department_id,
        job_position_id=job_position_id,
        manager_id=manager_id,
        working_schedule_id=payload.working_schedule_id,
        work_location=payload.work_location,
        status=payload.status.value,
        employee_type=payload.employee_type,
        company_name=payload.company_name or settings.company_name,
        date_of_joining=payload.date_of_joining or None,
        bank_account_number=payload.bank_account_number,
        bank_name=payload.bank_name,
        bank_ifsc_or_routing=payload.bank_ifsc_or_routing,
        pan_or_ssn=payload.pan_or_ssn,
    )
    if payload.date_of_joining is None:
        # Let the database default (CURRENT_DATE) apply.
        employee.date_of_joining = None

    db.add(employee)
    db.flush()

    if payload.create_login:
        login = AuthUser(
            email=payload.work_email,
            hashed_password=hash_password(payload.login_password),
            role=UserRole(payload.login_role) if payload.login_role else UserRole.EMPLOYEE,
        )
        db.add(login)
        db.flush()
        employee.user_id = login.id

    db.commit()
    db.refresh(employee)
    return _serialise_employee(employee, include_private=user.can_see_private_data)


@router.get(
    "/employees/{employee_id}",
    response_model=EmployeeDetailOut,
    summary="Full employee 360 profile with smart counts (EMPLOYEE sees self only)",
)
def get_employee(
    employee_id: uuid.UUID, db: DbSession, user: User
) -> EmployeeDetailOut:
    # Row scoping: an EMPLOYEE may only read their own record.
    user.assert_can_read_employee(employee_id)
    employee = get_employee_or_404(db, employee_id)

    counts = EmployeeSmartCounts(
        contracts_total=db.execute(
            select(func.count(HrContract.id)).where(
                HrContract.employee_id == employee.id
            )
        ).scalar_one(),
        contracts_running=db.execute(
            select(func.count(HrContract.id)).where(
                HrContract.employee_id == employee.id, HrContract.status == "RUNNING"
            )
        ).scalar_one(),
        payslips_total=db.execute(
            select(func.count(Payslip.id)).where(Payslip.employee_id == employee.id)
        ).scalar_one(),
        attendance_records=db.execute(
            select(func.count(Attendance.id)).where(
                Attendance.employee_id == employee.id
            )
        ).scalar_one(),
        timeoff_requests_pending=db.execute(
            select(func.count(LeaveRequest.id)).where(
                LeaveRequest.employee_id == employee.id,
                LeaveRequest.status == "TO_APPROVE",
            )
        ).scalar_one(),
        open_escalations=db.execute(
            select(func.count(RagEscalation.id)).where(
                RagEscalation.employee_id == employee.id,
                RagEscalation.status.in_(["OPEN", "ASSIGNED"]),
            )
        ).scalar_one(),
    )

    active_contract = db.execute(
        select(HrContract)
        .where(HrContract.employee_id == employee.id, HrContract.status == "RUNNING")
        .order_by(HrContract.start_date.desc())
    ).scalars().first()

    base = _serialise_employee(employee, include_private=user.can_see_private_data)
    return EmployeeDetailOut(
        **base.model_dump(),
        counts=counts,
        active_contract=(
            ContractOut(
                **{
                    **{
                        c: getattr(active_contract, c)
                        for c in (
                            "id",
                            "reference_code",
                            "employee_id",
                            "department_id",
                            "job_position_id",
                            "working_schedule_id",
                            "start_date",
                            "end_date",
                            "wage_monthly",
                            "status",
                            "notes",
                            "created_at",
                        )
                    },
                    "employee_name": employee.name,
                }
            )
            if active_contract
            else None
        ),
        leave_balances=leave_balance(db, employee.id),
    )


@router.patch(
    "/employees/{employee_id}",
    response_model=EmployeeOut,
    summary="Update an employee record (PATCH)",
)
@router.put(
    "/employees/{employee_id}",
    response_model=EmployeeOut,
    summary="Update an employee record (PUT)",
)
def update_employee(
    employee_id: uuid.UUID,
    payload: EmployeeUpdate,
    db: DbSession,
    user: CurrentUser = Depends(require_hr),
) -> EmployeeOut:
    employee = get_employee_or_404(db, employee_id)
    updates = payload.model_dump(exclude_unset=True)

    private_updates = {k for k in updates if k in PRIVATE_FIELDS}
    if private_updates and not user.can_see_private_data:
        raise ValidationError(
            "Only Payroll or Admin roles may edit banking and tax identifiers: "
            f"{sorted(private_updates)}"
        )
    if "manager_id" in updates and updates["manager_id"] == employee.id:
        raise ValidationError("An employee cannot be their own manager.")

    if "job_position_name" in updates and updates["job_position_name"]:
        pos_name = str(updates.pop("job_position_name")).strip()
        if pos_name:
            pos = db.execute(select(JobPosition).where(func.lower(JobPosition.name) == pos_name.lower())).scalars().first()
            if not pos:
                pos = JobPosition(name=pos_name, department_id=employee.department_id)
                db.add(pos)
                db.flush()
            employee.job_position_id = pos.id

    if "department_name" in updates and updates["department_name"]:
        dept_name = str(updates.pop("department_name")).strip()
        if dept_name:
            dept = db.execute(select(Department).where(func.lower(Department.name) == dept_name.lower())).scalars().first()
            if not dept:
                dept = Department(name=dept_name)
                db.add(dept)
                db.flush()
            employee.department_id = dept.id

    for field, value in updates.items():
        setattr(employee, field, value.value if hasattr(value, "value") else value)

    db.commit()
    db.refresh(employee)
    return _serialise_employee(employee, include_private=user.can_see_private_data)


@router.delete(
    "/employees/{employee_id}",
    response_model=MessageResponse,
    summary="Archive an employee (sets TERMINATED; payroll history is preserved)",
)
def archive_employee(
    employee_id: uuid.UUID, db: DbSession, _: CurrentUser = Depends(require_admin)
) -> MessageResponse:
    employee = get_employee_or_404(db, employee_id)

    running = db.execute(
        select(func.count(HrContract.id)).where(
            HrContract.employee_id == employee.id, HrContract.status == "RUNNING"
        )
    ).scalar_one()
    if running:
        raise ConflictError(
            "End or cancel the running contract before terminating this employee."
        )

    # Deliberately a soft delete: payslips reference employees with ON DELETE
    # RESTRICT, and financial history must remain auditable.
    employee.status = "TERMINATED"
    if employee.user_id:
        login = db.get(AuthUser, employee.user_id)
        if login:
            login.is_active = False
            db.flush()
            # Terminating someone must cut off their live session, not just stop
            # the next login.
            revoke_sessions(db, login.id)
    db.commit()
    return MessageResponse(
        detail=f"{employee.name} marked TERMINATED and their login deactivated."
    )


def _generate_badge_id(db) -> str:
    """EMP-001, EMP-002, ... derived from the highest existing numeric suffix."""
    rows = db.execute(select(Employee.badge_id)).scalars().all()
    highest = 0
    for badge in rows:
        if badge and badge.upper().startswith("EMP-"):
            suffix = badge.split("-", 1)[1]
            if suffix.isdigit():
                highest = max(highest, int(suffix))
    return f"EMP-{highest + 1:03d}"


# ===========================================================================
# MASTER DATA MUTATION
# Deletes are guarded by in-use checks. Master data that has been referenced by
# a transaction is deactivated rather than destroyed, because payroll and
# attendance history must stay readable.
# ===========================================================================
def _in_use_count(db, model, **filters) -> int:
    stmt = select(func.count()).select_from(model)
    for column, value in filters.items():
        stmt = stmt.where(getattr(model, column) == value)
    return db.execute(stmt).scalar_one()


@router.patch(
    "/departments/{department_id}",
    response_model=DepartmentWithStatsOut,
    summary="Rename a department, set its manager, or deactivate it",
)
def update_department(
    department_id: uuid.UUID,
    payload: DepartmentUpdate,
    db: DbSession,
    _: CurrentUser = Depends(require_hr),
) -> DepartmentWithStatsOut:
    department = db.get(Department, department_id)
    if not department:
        raise NotFoundError(f"Department {department_id} not found.")

    updates = payload.model_dump(exclude_unset=True)
    if "manager_employee_id" in updates and updates["manager_employee_id"]:
        manager = db.get(Employee, updates["manager_employee_id"])
        if not manager:
            raise NotFoundError("Manager employee not found.")
    for field, value in updates.items():
        setattr(department, field, value)

    db.commit()
    db.refresh(department)
    headcount = _in_use_count(db, Employee, department_id=department.id)
    return DepartmentWithStatsOut(
        id=department.id,
        name=department.name,
        manager_employee_id=department.manager_employee_id,
        is_active=department.is_active,
        created_at=department.created_at,
        manager_name=department.manager.name if department.manager else None,
        employee_count=headcount,
    )


@router.delete(
    "/departments/{department_id}",
    response_model=MessageResponse,
    summary="Delete a department, or deactivate it when still referenced",
)
def delete_department(
    department_id: uuid.UUID, db: DbSession, _: CurrentUser = Depends(require_hr)
) -> MessageResponse:
    department = db.get(Department, department_id)
    if not department:
        raise NotFoundError(f"Department {department_id} not found.")

    employees = _in_use_count(db, Employee, department_id=department.id)
    positions = _in_use_count(db, JobPosition, department_id=department.id)
    contracts = _in_use_count(db, HrContract, department_id=department.id)

    if employees or positions or contracts:
        department.is_active = False
        db.commit()
        return MessageResponse(
            detail=(
                f"'{department.name}' is referenced by {employees} employee(s), "
                f"{positions} position(s) and {contracts} contract(s), so it was "
                "deactivated instead of deleted."
            )
        )

    db.delete(department)
    db.commit()
    return MessageResponse(detail=f"Department '{department.name}' deleted.")


@router.patch(
    "/job-positions/{position_id}",
    response_model=JobPositionOut,
    summary="Rename a job position or move it to another department",
)
def update_job_position(
    position_id: uuid.UUID,
    payload: JobPositionUpdate,
    db: DbSession,
    _: CurrentUser = Depends(require_hr),
) -> JobPositionOut:
    position = db.get(JobPosition, position_id)
    if not position:
        raise NotFoundError(f"Job position {position_id} not found.")

    updates = payload.model_dump(exclude_unset=True)
    if "department_id" in updates and not db.get(Department, updates["department_id"]):
        raise NotFoundError("Department not found.")
    for field, value in updates.items():
        setattr(position, field, value)

    db.commit()
    db.refresh(position)
    return JobPositionOut.model_validate(position)


@router.delete(
    "/job-positions/{position_id}",
    response_model=MessageResponse,
    summary="Delete a job position (refused while employees hold it)",
)
def delete_job_position(
    position_id: uuid.UUID, db: DbSession, _: CurrentUser = Depends(require_hr)
) -> MessageResponse:
    position = db.get(JobPosition, position_id)
    if not position:
        raise NotFoundError(f"Job position {position_id} not found.")

    holders = _in_use_count(db, Employee, job_position_id=position.id)
    contracts = _in_use_count(db, HrContract, job_position_id=position.id)
    if holders or contracts:
        raise ConflictError(
            f"'{position.name}' is held by {holders} employee(s) and named on "
            f"{contracts} contract(s). Reassign them first."
        )

    db.delete(position)
    db.commit()
    return MessageResponse(detail=f"Job position '{position.name}' deleted.")


@router.patch(
    "/schedules/{schedule_id}",
    response_model=WorkingScheduleOut,
    summary="Update a schedule; supplying `lines` REPLACES the weekly pattern",
)
def update_schedule(
    schedule_id: uuid.UUID,
    payload: WorkingScheduleUpdate,
    db: DbSession,
    _: CurrentUser = Depends(require_hr),
) -> WorkingScheduleOut:
    schedule = db.get(WorkingSchedule, schedule_id)
    if not schedule:
        raise NotFoundError(f"Working schedule {schedule_id} not found.")

    updates = payload.model_dump(exclude_unset=True)
    lines = updates.pop("lines", None)
    for field, value in updates.items():
        setattr(schedule, field, value)

    if lines is not None:
        # Replace wholesale. Editing individual rows would leave the caller unable
        # to remove a day, which is the common case when a shift pattern changes.
        db.execute(
            delete(WorkingScheduleLine).where(
                WorkingScheduleLine.schedule_id == schedule.id
            )
        )
        db.flush()
        for line in lines:
            db.add(
                WorkingScheduleLine(
                    schedule_id=schedule.id,
                    day_of_week=line["day_of_week"],
                    day_name=line.get("day_name") or DAY_NAMES[line["day_of_week"]],
                    start_time=line["start_time"],
                    end_time=line["end_time"],
                    break_hours=line.get("break_hours", 1),
                )
            )

    db.commit()
    db.expire_all()
    schedule = db.execute(
        select(WorkingSchedule)
        .options(selectinload(WorkingSchedule.lines))
        .where(WorkingSchedule.id == schedule_id)
    ).scalars().one()
    return WorkingScheduleOut.model_validate(schedule)


@router.delete(
    "/schedules/{schedule_id}",
    response_model=MessageResponse,
    summary="Delete a schedule, or deactivate it when still assigned",
)
def delete_schedule(
    schedule_id: uuid.UUID, db: DbSession, _: CurrentUser = Depends(require_hr)
) -> MessageResponse:
    schedule = db.get(WorkingSchedule, schedule_id)
    if not schedule:
        raise NotFoundError(f"Working schedule {schedule_id} not found.")

    employees = _in_use_count(db, Employee, working_schedule_id=schedule.id)
    contracts = _in_use_count(db, HrContract, working_schedule_id=schedule.id)
    if employees or contracts:
        schedule.is_active = False
        db.commit()
        return MessageResponse(
            detail=(
                f"'{schedule.name}' is assigned to {employees} employee(s) and "
                f"{contracts} contract(s), so it was deactivated instead of deleted. "
                "Attendance and payroll history keep resolving it."
            )
        )

    db.delete(schedule)
    db.commit()
    return MessageResponse(detail=f"Working schedule '{schedule.name}' deleted.")


@router.delete(
    "/holidays/{holiday_id}",
    response_model=MessageResponse,
    summary="Remove a public holiday",
)
def delete_holiday(
    holiday_id: uuid.UUID, db: DbSession, _: CurrentUser = Depends(require_hr)
) -> MessageResponse:
    holiday = db.get(PublicHoliday, holiday_id)
    if not holiday:
        raise NotFoundError(f"Holiday {holiday_id} not found.")
    name, when = holiday.name, holiday.holiday_date
    db.delete(holiday)
    db.commit()
    return MessageResponse(
        detail=(
            f"Removed '{name}' on {when}. Leave durations and expected working days "
            "computed from now on will count that date as a working day."
        )
    )
