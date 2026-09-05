"""Payslip email dispatch.

When `SMTP_HOST` is blank the dispatcher runs in **dry-run mode**: it does all the
work (renders the PDF, resolves recipients, stamps `emailed_at`, writes the
notification) but logs instead of sending. That keeps the endpoint demoable
without wiring real credentials, and makes it obvious in the response which mode
was used rather than silently pretending to have sent mail.
"""

from __future__ import annotations

import logging
import smtplib
import uuid
from datetime import datetime, timezone
from email.message import EmailMessage
from typing import Any, Dict, List

from sqlalchemy import text
from sqlalchemy.orm import Session

from app.core.config import settings
from app.core.errors import ConflictError, NotFoundError
from app.services.pdf_service import build_payslip_pdf, payslip_filename

logger = logging.getLogger(__name__)


def smtp_configured() -> bool:
    return bool(settings.smtp_host)


def _send(message: EmailMessage) -> None:
    with smtplib.SMTP(settings.smtp_host, settings.smtp_port, timeout=20) as smtp:
        if settings.smtp_use_tls:
            smtp.starttls()
        if settings.smtp_user and settings.smtp_password:
            smtp.login(settings.smtp_user, settings.smtp_password)
        smtp.send_message(message)


def _build_message(
    *,
    to_address: str,
    employee_name: str,
    payrun_name: str,
    reference_code: str,
    pdf_bytes: bytes,
    filename: str,
) -> EmailMessage:
    message = EmailMessage()
    message["Subject"] = f"Your payslip for {payrun_name} ({reference_code})"
    message["From"] = settings.smtp_from
    message["To"] = to_address
    message.set_content(
        f"Hello {employee_name},\n\n"
        f"Your payslip for {payrun_name} is attached as a PDF.\n"
        f"Reference: {reference_code}\n\n"
        "You can also view the full rule-by-rule breakdown in PeoplePay360, or "
        "ask the HR Copilot to explain any deduction.\n\n"
        f"-- {settings.company_name} Payroll"
    )
    message.add_attachment(
        pdf_bytes, maintype="application", subtype="pdf", filename=filename
    )
    return message


def send_payrun_payslips(
    db: Session, payrun_id: uuid.UUID | str, *, only_unsent: bool = True
) -> Dict[str, Any]:
    """Bulk-email every payslip in a payrun. Requires the batch to be VALIDATED."""
    payrun = db.execute(
        text(
            "SELECT id, reference_code, name, status FROM payruns "
            "WHERE id = CAST(:pid AS uuid)"
        ),
        {"pid": str(payrun_id)},
    ).fetchone()
    if not payrun:
        raise NotFoundError(f"Payrun {payrun_id} not found.")
    if payrun.status not in ("VALIDATED", "PAID"):
        raise ConflictError(
            f"Payrun {payrun.reference_code} is {payrun.status}. Validate it before "
            "sending payslips so employees never receive a draft figure."
        )

    clause = "AND p.emailed_at IS NULL" if only_unsent else ""
    rows = db.execute(
        text(
            f"""
            SELECT p.id, p.reference_code, e.name, e.work_email, e.user_id
            FROM payslips p JOIN employees e ON e.id = p.employee_id
            WHERE p.payrun_id = CAST(:pid AS uuid) {clause}
            ORDER BY e.badge_id
            """
        ),
        {"pid": str(payrun_id)},
    ).fetchall()

    dry_run = not smtp_configured()
    sent: List[str] = []
    failed: List[Dict[str, str]] = []

    for row in rows:
        try:
            pdf_bytes = build_payslip_pdf(db, row.id)
            message = _build_message(
                to_address=row.work_email,
                employee_name=row.name,
                payrun_name=payrun.name,
                reference_code=row.reference_code,
                pdf_bytes=pdf_bytes,
                filename=payslip_filename(db, row.id),
            )
            if dry_run:
                logger.info(
                    "[DRY RUN] Payslip %s (%d KB) would be emailed to %s",
                    row.reference_code,
                    len(pdf_bytes) // 1024,
                    row.work_email,
                )
            else:
                _send(message)

            db.execute(
                text(
                    "UPDATE payslips SET emailed_at = :now WHERE id = CAST(:sid AS uuid)"
                ),
                {"now": datetime.now(timezone.utc), "sid": str(row.id)},
            )
            if row.user_id:
                db.execute(
                    text(
                        """
                        INSERT INTO notifications
                            (recipient_user_id, kind, title, body, deep_link)
                        VALUES (CAST(:u AS uuid), 'PAYSLIP_SENT', :title, :body, :link)
                        """
                    ),
                    {
                        "u": str(row.user_id),
                        "title": f"Your payslip for {payrun.name} is ready",
                        "body": f"Payslip {row.reference_code} has been issued.",
                        "link": f"/payslips/{row.id}",
                    },
                )
            sent.append(row.reference_code)
        except Exception as exc:  # noqa: BLE001 - one bad address must not abort the batch
            logger.warning("Failed to email payslip %s: %s", row.reference_code, exc)
            failed.append({"reference_code": row.reference_code, "error": str(exc)})

    db.commit()

    return {
        "payrun_reference": payrun.reference_code,
        "mode": "dry_run" if dry_run else "smtp",
        "smtp_host": settings.smtp_host or None,
        "candidates": len(rows),
        "sent_count": len(sent),
        "failed_count": len(failed),
        "sent": sent,
        "failed": failed,
        "note": (
            "SMTP_HOST is not configured, so messages were rendered and logged but "
            "not transmitted."
            if dry_run
            else None
        ),
    }
