"""Shared pytest fixtures for backend tests.

These tests run against the real configured PostgreSQL database, because the
attendance guarantees under test are PostgreSQL-specific:

  * the partial unique index ``idx_attendance_single_open``
  * ``SELECT ... FOR UPDATE`` row locking

SQLite cannot express either, so a mock DB would test different behaviour than
production. Each test runs inside an outer transaction that is rolled back on
teardown, and service code that calls ``session.commit()`` is redirected onto a
SAVEPOINT (nested transaction) so those commits never actually persist. The
database is left exactly as it was found.
"""

from __future__ import annotations

import uuid
from datetime import date

import pytest
from sqlalchemy import event, text

from app.core.database import SessionLocal, engine
from app.models.employee import Employee


@pytest.fixture(scope="session", autouse=True)
def _ensure_schema():
    """Fail fast with a clear message if the schema/database is not reachable."""
    try:
        with engine.connect() as conn:
            has_table = conn.execute(
                text(
                    "SELECT COUNT(*) FROM information_schema.tables "
                    "WHERE table_schema='public' AND table_name='attendances'"
                )
            ).scalar_one()
    except Exception as exc:  # pragma: no cover - environment guard
        pytest.skip(f"Database not reachable for tests: {exc}")
        return
    if not has_table:  # pragma: no cover - environment guard
        pytest.skip(
            "The 'attendances' table is missing. Run `python -m scripts.init_db` first."
        )


@pytest.fixture()
def db():
    """A session bound to a transaction that is always rolled back.

    Uses the classic SQLAlchemy 'join an external transaction' recipe so that
    ``db.commit()`` inside the service under test commits to a SAVEPOINT rather
    than the real transaction. On teardown the whole thing is rolled back.
    """
    connection = engine.connect()
    trans = connection.begin()
    session = SessionLocal(bind=connection)

    # Start a SAVEPOINT and restart it every time the service commits/releases it,
    # so nested commits stay inside the outer (rolled-back) transaction.
    session.begin_nested()

    @event.listens_for(session, "after_transaction_end")
    def _restart_savepoint(sess, transaction):  # noqa: ANN001
        if transaction.nested and not transaction._parent.nested:
            sess.begin_nested()

    try:
        yield session
    finally:
        event.remove(session, "after_transaction_end", _restart_savepoint)
        session.close()
        trans.rollback()
        connection.close()


def _make_employee(db, *, name: str, status: str = "ACTIVE") -> Employee:
    """Insert a minimal ACTIVE employee with a unique badge/email."""
    tag = uuid.uuid4().hex[:8]
    emp = Employee(
        badge_id=f"T{tag}",
        name=name,
        work_email=f"{tag}@test.local",
        status=status,
        employee_type="PERMANENT",
        company_name="Test Co",
        date_of_joining=date(2020, 1, 1),
    )
    db.add(emp)
    db.flush()
    return emp


@pytest.fixture()
def employee(db):
    return _make_employee(db, name="Test Employee One")


@pytest.fixture()
def other_employee(db):
    return _make_employee(db, name="Test Employee Two")


@pytest.fixture()
def make_employee(db):
    """Factory so a test can create employees with a specific status."""

    def factory(*, name: str = "Factory Employee", status: str = "ACTIVE") -> Employee:
        return _make_employee(db, name=name, status=status)

    return factory
