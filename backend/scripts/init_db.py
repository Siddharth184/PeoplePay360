"""Apply db/schema.sql to the configured database.

Kept separate from the seeder so schema and data are independent concerns:
`init_db` is idempotent and safe to re-run, `seed_db` is destructive by design.

Usage:
    python -m scripts.init_db
    python -m scripts.init_db --drop      # tear down and recreate from scratch
"""

from __future__ import annotations

import argparse
import sys
from pathlib import Path

from sqlalchemy import text

# Allow `python scripts/init_db.py` as well as `python -m scripts.init_db`.
sys.path.insert(0, str(Path(__file__).resolve().parents[1]))

from app.core.config import settings  # noqa: E402
from app.core.database import engine  # noqa: E402

SCHEMA_PATH = Path(__file__).resolve().parents[1] / "db" / "schema.sql"

DROP_SQL = """
DROP SCHEMA public CASCADE;
CREATE SCHEMA public;
"""


def apply_schema(drop: bool = False) -> None:
    if not SCHEMA_PATH.exists():
        raise SystemExit(f"Schema file not found: {SCHEMA_PATH}")

    ddl = SCHEMA_PATH.read_text(encoding="utf-8")

    with engine.begin() as conn:
        if drop:
            print("Dropping and recreating the public schema ...")
            conn.execute(text(DROP_SQL))

        print(f"Applying {SCHEMA_PATH.name} ...")
        # Send the script straight to the driver cursor with NO parameters.
        #
        # Two reasons this cannot go through `text()` or `exec_driver_sql`:
        #   1. The DDL contains DO $$ ... $$ blocks and function bodies, so it
        #      must be executed as one script rather than split on semicolons.
        #   2. It legitimately contains '%' (the plpgsql RAISE format specifier
        #      and format() positional specifiers). psycopg only skips
        #      client-side placeholder parsing when params is None, which is
        #      exactly what a bare cursor.execute(sql) does.
        raw_connection = conn.connection.driver_connection
        with raw_connection.cursor() as cursor:
            cursor.execute(ddl)

    with engine.connect() as conn:
        tables = conn.execute(
            text(
                """
                SELECT COUNT(*) FROM information_schema.tables
                WHERE table_schema = 'public' AND table_type = 'BASE TABLE'
                """
            )
        ).scalar_one()
        has_vector = conn.execute(
            text("SELECT COUNT(*) FROM pg_extension WHERE extname = 'vector'")
        ).scalar_one()
        vector_version = conn.execute(
            text("SELECT extversion FROM pg_extension WHERE extname = 'vector'")
        ).scalar()

    print(f"Schema applied: {tables} tables in `public`.")
    print(f"pgvector installed: {bool(has_vector)} (version {vector_version}).")
    if not has_vector:
        print(
            "INFO: pgvector is missing on host PostgreSQL. Core database schema initialized successfully."
        )


def main() -> None:
    parser = argparse.ArgumentParser(description="Initialise the PeoplePay360 schema.")
    parser.add_argument(
        "--drop",
        action="store_true",
        help="Drop the public schema first (destroys ALL data).",
    )
    args = parser.parse_args()

    masked = settings.database_url
    if "@" in masked:
        prefix, _, rest = masked.partition("://")
        creds, _, host = rest.partition("@")
        user = creds.split(":", 1)[0]
        masked = f"{prefix}://{user}:***@{host}"
    print(f"Target: {masked}")

    if args.drop and settings.is_production:
        raise SystemExit("Refusing to --drop a production database.")

    apply_schema(drop=args.drop)


if __name__ == "__main__":
    main()
