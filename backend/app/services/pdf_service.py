"""Official A4 payslip PDF generation.

ReportLab rather than WeasyPrint: WeasyPrint needs GTK/Pango/Cairo native
libraries, which is a hostile install on Windows. ReportLab is pure Python, so
`pip install -r requirements.txt` is all a teammate needs.

The PDF is generated on demand and streamed; nothing is written to disk, so there
is no stale-file cache to invalidate when a payslip is recomputed.
"""

from __future__ import annotations

import io
import uuid
from decimal import Decimal
from typing import Any, Dict, List

from reportlab.lib import colors
from reportlab.lib.enums import TA_CENTER
from reportlab.lib.pagesizes import A4
from reportlab.lib.styles import ParagraphStyle, getSampleStyleSheet
from reportlab.lib.units import mm
from reportlab.platypus import (
    HRFlowable,
    Paragraph,
    SimpleDocTemplate,
    Spacer,
    Table,
    TableStyle,
)
from sqlalchemy import text
from sqlalchemy.orm import Session

from app.core.config import settings
from app.core.errors import NotFoundError

BRAND_TEAL = colors.HexColor("#017E84")
BRAND_DARK = colors.HexColor("#1F2933")
LIGHT_ROW = colors.HexColor("#F4F7F8")
BORDER = colors.HexColor("#D5DEE0")
CURRENCY = settings.company_currency_symbol


def _money(value: Any) -> str:
    return f"{CURRENCY}{Decimal(str(value or 0)):,.2f}"


def _num(value: Any) -> str:
    return f"{Decimal(str(value or 0)).normalize():f}"


def fetch_payslip_bundle(db: Session, payslip_id: uuid.UUID | str) -> Dict[str, Any]:
    """Everything the payslip document needs, in one round trip per table."""
    header = db.execute(
        text(
            """
            SELECT p.id, p.reference_code, p.date_start, p.date_end, p.worked_days,
                   p.basic_amount, p.gross_amount, p.net_amount, p.status,
                   p.warning_notes,
                   e.id AS employee_id, e.name AS employee_name, e.badge_id,
                   e.work_email, e.work_location, e.date_of_joining,
                   e.bank_name, e.bank_account_number, e.bank_ifsc_or_routing,
                   e.pan_or_ssn,
                   d.name AS department, j.name AS job_position,
                   c.reference_code AS contract_reference, c.wage_monthly,
                   s.name AS structure_name,
                   r.reference_code AS payrun_reference, r.name AS payrun_name
            FROM payslips p
            JOIN employees e ON e.id = p.employee_id
            LEFT JOIN departments d ON d.id = e.department_id
            LEFT JOIN job_positions j ON j.id = e.job_position_id
            JOIN hr_contracts c ON c.id = p.contract_id
            JOIN salary_structures s ON s.id = p.salary_structure_id
            JOIN payruns r ON r.id = p.payrun_id
            WHERE p.id = CAST(:sid AS uuid)
            """
        ),
        {"sid": str(payslip_id)},
    ).fetchone()

    if not header:
        raise NotFoundError(f"Payslip {payslip_id} not found.")

    lines = db.execute(
        text(
            """
            SELECT rule_name, rule_code, category, sequence, amount
            FROM payslip_lines
            WHERE payslip_id = CAST(:sid AS uuid)
            ORDER BY sequence ASC
            """
        ),
        {"sid": str(payslip_id)},
    ).fetchall()

    return {"header": header, "lines": lines}


def _mask_account(account: str | None) -> str:
    """Show only the last four digits, even to the employee who owns it."""
    if not account:
        return "Not on file"
    tail = account[-4:]
    return f"{'*' * max(0, len(account) - 4)}{tail}"


def build_payslip_pdf(db: Session, payslip_id: uuid.UUID | str) -> bytes:
    bundle = fetch_payslip_bundle(db, payslip_id)
    header = bundle["header"]
    lines = bundle["lines"]

    buffer = io.BytesIO()
    doc = SimpleDocTemplate(
        buffer,
        pagesize=A4,
        leftMargin=18 * mm,
        rightMargin=18 * mm,
        topMargin=16 * mm,
        bottomMargin=16 * mm,
        title=f"Payslip {header.reference_code}",
        author=settings.company_name,
        subject=f"Payslip for {header.employee_name}",
    )

    styles = getSampleStyleSheet()
    title_style = ParagraphStyle(
        "PPTitle",
        parent=styles["Title"],
        fontSize=18,
        textColor=BRAND_TEAL,
        spaceAfter=2,
    )
    subtitle_style = ParagraphStyle(
        "PPSubtitle",
        parent=styles["Normal"],
        fontSize=9.5,
        textColor=BRAND_DARK,
        alignment=TA_CENTER,
    )
    section_style = ParagraphStyle(
        "PPSection",
        parent=styles["Heading3"],
        fontSize=10.5,
        textColor=BRAND_TEAL,
        spaceBefore=10,
        spaceAfter=4,
    )
    small = ParagraphStyle(
        "PPSmall", parent=styles["Normal"], fontSize=7.5, textColor=colors.grey
    )


    story: List[Any] = [
        Paragraph(settings.company_name, title_style),
        Paragraph(
            f"Payslip {header.reference_code} &nbsp;|&nbsp; "
            f"{header.date_start:%d %b %Y} to {header.date_end:%d %b %Y}",
            subtitle_style,
        ),
        Spacer(1, 4 * mm),
        HRFlowable(width="100%", thickness=1, color=BRAND_TEAL, spaceAfter=6),
    ]

    # --- Identity block -----------------------------------------------------
    identity = [
        ["Employee", header.employee_name, "Badge ID", header.badge_id],
        [
            "Department",
            header.department or "-",
            "Position",
            header.job_position or "-",
        ],
        [
            "Work location",
            header.work_location or "-",
            "Date of joining",
            f"{header.date_of_joining:%d %b %Y}",
        ],
        [
            "Contract",
            header.contract_reference,
            "Monthly wage",
            _money(header.wage_monthly),
        ],
        [
            "Salary structure",
            header.structure_name,
            "Payrun",
            f"{header.payrun_name} ({header.payrun_reference})",
        ],
        [
            "Bank",
            header.bank_name or "Not on file",
            "Account",
            _mask_account(header.bank_account_number),
        ],
        [
            "Worked days",
            _num(header.worked_days),
            "Payslip status",
            header.status,
        ],
    ]
    identity_table = Table(
        identity, colWidths=[28 * mm, 58 * mm, 28 * mm, 60 * mm], hAlign="LEFT"
    )
    identity_table.setStyle(
        TableStyle(
            [
                ("FONTSIZE", (0, 0), (-1, -1), 8.5),
                ("TEXTCOLOR", (0, 0), (0, -1), colors.grey),
                ("TEXTCOLOR", (2, 0), (2, -1), colors.grey),
                ("FONTNAME", (1, 0), (1, -1), "Helvetica-Bold"),
                ("FONTNAME", (3, 0), (3, -1), "Helvetica-Bold"),
                ("BOTTOMPADDING", (0, 0), (-1, -1), 3),
                ("TOPPADDING", (0, 0), (-1, -1), 3),
                ("LINEBELOW", (0, 0), (-1, -2), 0.25, BORDER),
            ]
        )
    )
    story += [identity_table]

    # --- Earnings / deductions ---------------------------------------------
    def rule_table(rows: List[Any], amount_header: str) -> Table:
        data = [["Component", "Code", amount_header]]
        for row in rows:
            data.append(
                [row.rule_name, row.rule_code, _money(abs(Decimal(str(row.amount))))]
            )
        table = Table(data, colWidths=[86 * mm, 38 * mm, 50 * mm], hAlign="LEFT")
        style = [
            ("BACKGROUND", (0, 0), (-1, 0), BRAND_TEAL),
            ("TEXTCOLOR", (0, 0), (-1, 0), colors.white),
            ("FONTNAME", (0, 0), (-1, 0), "Helvetica-Bold"),
            ("FONTSIZE", (0, 0), (-1, -1), 9),
            ("ALIGN", (2, 0), (2, -1), "RIGHT"),
            ("GRID", (0, 0), (-1, -1), 0.25, BORDER),
            ("TOPPADDING", (0, 0), (-1, -1), 4),
            ("BOTTOMPADDING", (0, 0), (-1, -1), 4),
        ]
        for index in range(1, len(data)):
            if index % 2 == 0:
                style.append(("BACKGROUND", (0, index), (-1, index), LIGHT_ROW))
        table.setStyle(TableStyle(style))
        return table

    earnings = [l for l in lines if l.category in ("BASIC", "ALLOWANCE")]
    subtotals = [l for l in lines if l.category == "GROSS"]
    deductions = [l for l in lines if l.category == "DEDUCTION"]
    net_rules = [l for l in lines if l.category == "NET"]

    story += [Paragraph("Earnings", section_style)]
    story += [
        rule_table(earnings, "Amount")
        if earnings
        else Paragraph("No earning components recorded.", small)
    ]

    if subtotals:
        story += [Paragraph("Subtotals", section_style), rule_table(subtotals, "Amount")]

    story += [Paragraph("Deductions", section_style)]
    story += [
        rule_table(deductions, "Amount")
        if deductions
        else Paragraph("No deductions applied.", small)
    ]

    # --- Totals -------------------------------------------------------------
    total_deductions = sum(
        (abs(Decimal(str(l.amount))) for l in deductions), Decimal("0.00")
    )
    totals = [
        ["Basic", _money(header.basic_amount)],
        ["Gross earnings", _money(header.gross_amount)],
        ["Total deductions", f"- {_money(total_deductions)}"],
        ["NET PAYABLE", _money(header.net_amount)],
    ]
    totals_table = Table(totals, colWidths=[110 * mm, 64 * mm], hAlign="RIGHT")
    totals_table.setStyle(
        TableStyle(
            [
                ("FONTSIZE", (0, 0), (-1, -1), 9.5),
                ("ALIGN", (1, 0), (1, -1), "RIGHT"),
                ("LINEABOVE", (0, 0), (-1, 0), 0.5, BORDER),
                ("BACKGROUND", (0, 3), (-1, 3), BRAND_TEAL),
                ("TEXTCOLOR", (0, 3), (-1, 3), colors.white),
                ("FONTNAME", (0, 3), (-1, 3), "Helvetica-Bold"),
                ("FONTSIZE", (0, 3), (-1, 3), 11),
                ("TOPPADDING", (0, 0), (-1, -1), 5),
                ("BOTTOMPADDING", (0, 0), (-1, -1), 5),
            ]
        )
    )
    story += [Spacer(1, 6 * mm), totals_table]

    if net_rules:
        story += [
            Spacer(1, 2 * mm),
            Paragraph(
                "Net pay is produced by the rule "
                f"'{net_rules[0].rule_name}' ({net_rules[0].rule_code}).",
                small,
            ),
        ]

    if header.warning_notes:
        story += [
            Spacer(1, 4 * mm),
            Paragraph(f"<b>Payroll notes:</b> {header.warning_notes}", small),
        ]

    story += [
        Spacer(1, 8 * mm),
        HRFlowable(width="100%", thickness=0.5, color=BORDER, spaceAfter=4),
        Paragraph(
            "This is a computer-generated payslip produced by PeoplePay360. "
            "Every amount above is derived from the salary structure "
            f"'{header.structure_name}' and this employee's recorded attendance "
            "for the period. Bank account digits are partially masked for security.",
            small,
        ),
    ]

    doc.build(story)
    return buffer.getvalue()


def payslip_filename(db: Session, payslip_id: uuid.UUID | str) -> str:
    row = db.execute(
        text(
            """
            SELECT p.reference_code, e.badge_id
            FROM payslips p JOIN employees e ON e.id = p.employee_id
            WHERE p.id = CAST(:sid AS uuid)
            """
        ),
        {"sid": str(payslip_id)},
    ).fetchone()
    if not row:
        raise NotFoundError(f"Payslip {payslip_id} not found.")
    safe_ref = row.reference_code.replace("/", "-")
    return f"payslip-{row.badge_id}-{safe_ref}.pdf"
