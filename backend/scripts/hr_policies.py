"""HR knowledge base source documents.

These are the corpus the RAG retrieval layer searches. They are written as real
policy prose (not lorem ipsum) because retrieval quality is entirely a function of
the corpus: a bot cannot cite a handbook that does not exist.

Each entry is (collection, title, body).
"""

from __future__ import annotations

from typing import List, Tuple

POLICY_DOCUMENTS: List[Tuple[str, str, str]] = [
    (
        "hr_policies",
        "Paid Time Off Policy",
        """
Paid Time Off (PTO) Policy

Every full-time employee receives an annual allocation of 20 paid time off days,
granted by the HR Manager at the start of each calendar year. Allocations are
recorded against a validity year and must be approved before they can be spent.

Requesting time off. Submit the request through PeoplePay360 at least three
working days before the intended start date. The system calculates the duration
from your assigned working schedule, so weekends and configured public holidays
are never deducted from your balance. Your remaining balance is checked at
submission time as well as at approval time; a request that would take you
negative is rejected outright.

Approval. Time off requests are approved by your reporting manager or by the HR
Manager. You cannot approve your own request. Once approved, the days are debited
from your allocation immediately. If an approved request is later refused or
cancelled, the days are credited straight back to the same allocation.

Carry forward. Unused PTO does not automatically carry into the next year.
Allocations are consumed oldest validity year first, so older entitlements are
spent before newer ones and nothing silently expires while a newer balance sits
unused.

Half days. A half day is recorded by submitting a request with an explicit
duration of 0.5 days. Half days count as 0.5 worked days in payroll proration.
""",
    ),
    (
        "hr_policies",
        "Sick Leave Policy",
        """
Sick Leave Policy

Employees receive 12 sick leave days per calendar year. Sick leave is intended for
personal illness, medical appointments and recovery.

Notification. Inform your reporting manager as early as possible on the first day
of absence, ideally before your scheduled shift start time. Record the absence in
PeoplePay360 as soon as you are able to; a retrospective request is acceptable for
sick leave.

Medical certificate. A medical certificate is required for any continuous sick
absence of three days or more. Submit it to the HR Manager. Absences without the
required certificate may be reclassified as unpaid leave.

Sick leave and payroll. Approved sick leave does not reduce your worked days for
proration purposes. Unexplained absence, meaning a scheduled working day with no
attendance record and no approved leave, is flagged as an anomaly on the payroll
pre-flight report and may result in a deduction.
""",
    ),
    (
        "hr_policies",
        "Attendance and Working Hours Policy",
        """
Attendance and Working Hours Policy

Standard schedule. The default working schedule is 40 hours per week across five
days, Monday to Friday, 09:00 to 18:00 with a one hour unpaid break. That yields
eight paid working hours per day. Alternative schedules such as the Night Shift
are assigned per employee and payroll always prorates against the employee's own
assigned schedule, never a company-wide assumption.

Check in and check out. Use the Check In / Check Out toggle in PeoplePay360. You
may only have one open punch at a time; the system will not let you check in twice
without checking out. Worked hours are computed from the difference between your
check-in and check-out timestamps.

Late arrival. A check-in more than 15 minutes after your scheduled start time is
recorded with the status LATE. Repeated late arrivals are reviewed by your
reporting manager.

Half days. If your recorded worked hours for a day fall below half of the expected
hours for that day, the punch is automatically marked HALF_DAY and counts as 0.5
worked days.

Overtime. Hours worked beyond the expected hours for that day are recorded as
overtime. Overtime is recorded for every employee, but whether it is paid depends
on the salary structure applied to your contract.

Corrections. If a punch is wrong, ask HR to correct it. Every manual correction is
stamped as a manual edit with an audit note naming the reason, so the attendance
log always shows what was changed and why.
""",
    ),
    (
        "payroll_rules",
        "Salary Structure and Payslip Components",
        """
Salary Structure and Payslip Components

The Regular Salary structure computes your payslip from your contract's monthly
wage using rules applied in a fixed sequence. Each rule produces one line on your
payslip, so every figure is traceable.

Earnings.
Basic Salary (BASIC) is 50% of your contract monthly wage.
House Rent Allowance (HRA) is 40% of Basic Salary.
Standard Allowance (STD) is a fixed amount of 10,000 per month.
Gross Salary (GROSS) is the sum of Basic plus all allowances.

Deductions.
Provident Fund (PF) is 6% of Basic Salary.
Professional Tax (PT) is a fixed 2,000 per month.

Net pay.
Net Salary (NET) is Gross Salary minus total deductions.

Worked example. On a contract monthly wage of 100,000: Basic is 50,000, HRA is
20,000, Standard Allowance is 10,000, giving a Gross of 80,000. Provident Fund is
3,000 and Professional Tax is 2,000, giving total deductions of 5,000. Net pay is
therefore 75,000.

Numeric integrity. Every amount is calculated using fixed-point decimal
arithmetic and rounded to two decimal places using the half-up convention.
Floating point numbers are never used anywhere in payroll computation.
""",
    ),
    (
        "payroll_rules",
        "Payroll Run Process and Payslip Delivery",
        """
Payroll Run Process and Payslip Delivery

Payroll is processed as a two-step workflow so mistakes are caught before any
record is created.

Step one is a read-only validation. The payroll officer selects a salary structure
and a period. The system resolves the contract that is valid for that exact period
for each candidate employee and reports every anomaly it finds: a missing or
expired contract, several conflicting running contracts, a payslip that already
exists for an overlapping period, missing bank details, a missing tax identifier,
zero recorded attendance, or unexplained absences. Nothing is written to the
database during step one.

Step two creates the batch. The officer selects specific employees and the system
generates the payrun and one payslip per selected employee. By default a blocking
anomaly aborts the whole batch so the problem is visible rather than producing a
silently short payroll.

The batch then moves through Draft, Computed, Validated and Paid. A batch cannot
be validated while any payslip has negative net pay, and cannot be marked paid
while any included employee is missing bank details.

Payslip delivery. Payslips are emailed as PDF attachments only after the batch is
validated, so no employee ever receives a draft figure. Your bank account number
is partially masked on the PDF.

Questions about your payslip. Ask the HR Copilot to explain your deductions. It
answers from the actual computed payslip lines and the rule definitions that
produced them, so the numbers it quotes are the numbers that were paid.
""",
    ),
    (
        "hr_policies",
        "Employment Contract Terms",
        """
Employment Contract Terms

Contract reference. Every contract has a unique reference in the form
CON/YYYY/NNNN. Your contract records your monthly wage, your working schedule,
your department and job position, and its start and end dates. A contract with no
end date is ongoing.

Contract states. A contract begins as Draft. Activating it moves it to Running.
When it passes its end date it becomes Expired; it can be Cancelled before or
during its term.

One running contract at a time. You cannot have two Running contracts covering
overlapping dates. This is enforced by the database, not just by the interface, so
it holds even for bulk imports. When payroll runs for a period it resolves the one
contract valid for that period; zero matches or several matches are both treated
as errors rather than guessed at.

Probation. New employees serve a probation period of three months from the date of
joining. During probation the notice period is seven days for either party.

Notice period. After probation the notice period is 30 days for employees and
30 days for the company, unless your contract states otherwise.

Contract renewal. Contracts ending within 45 days are flagged on the payroll
pre-flight report so HR can begin the renewal conversation before the contract
lapses and payroll is blocked.
""",
    ),
    (
        "hr_policies",
        "Statutory Deductions and Tax Documents",
        """
Statutory Deductions and Tax Documents

Provident Fund. Provident Fund is deducted at 6% of Basic Salary and remitted
monthly. The deduction appears on your payslip as the line PF.

Professional Tax. Professional Tax is a fixed statutory deduction of 2,000 per
month and appears on your payslip as the line PT.

Tax identifiers. Your PAN, or its local equivalent, must be on your employee
record for statutory reporting to be complete. Payroll flags a missing tax
identifier as a warning during the pre-flight check. Contact the Payroll Manager
to add or correct it.

Form 16 and the annual tax statement. Form 16 is the annual tax statement that
summarises your total salary paid and the tax deducted at source for the financial
year. It is issued by the Payroll Manager after the close of the financial year,
normally within 60 days. Form 16 is what you attach to your personal income tax
return. If you need a reissue, a corrected copy, or a Form 16 covering a year in
which you left the company, raise the request with the Payroll Manager. Employees
who joined mid-year receive a Form 16 covering only the months they were on
payroll here.

Privacy of your identifiers. Bank account numbers, PAN and routing codes are
visible only to Payroll and Admin roles. They are redacted before any text is sent
to an external AI service, and personal-data questions are answered locally from
the database without contacting any external service at all.
""",
    ),
    (
        "handbook",
        "Using the PeoplePay360 HR Copilot",
        """
Using the PeoplePay360 HR Copilot

The Copilot answers two different kinds of question in two different ways, on
purpose.

Questions about your own data, such as your leave balance, your recent payslips,
your attendance this month or your contract terms, are answered directly from the
database using a fixed template. No language model is involved, so the numbers are
exact and nothing about you is sent anywhere.

Questions about policy are answered by searching the company handbook and payroll
documentation. The Copilot cites the sections it used so you can verify the answer
yourself.

How the Copilot decides to escalate a question to a human. Every policy search
returns a confidence score. The Copilot compares that score against a calibrated
threshold, and if the best match falls below it the Copilot refuses to answer
rather than guessing. It escalates in four situations: the retrieved documentation
is too weak a match to ground an answer, the search returned nothing at all, the
question needs data no available tool exposes, or you explicitly asked for a
human. In each case the recorded reason is attached to the ticket, so the decision
to escalate is auditable rather than a black box.

What escalation does. The Copilot creates a ticket, routes it to the team that
owns that category of question, starts an SLA clock, and tells you the ticket
number. Leave and attendance questions go to the HR Manager. Salary, payroll and
tax questions go to the Payroll Manager. Account and access questions go to an
Administrator. Nothing is ever dropped: an uncategorised question goes to an
Administrator as a catch-all. You are notified as soon as a human replies, and if
a ticket passes its SLA it is raised to urgent and administrators are alerted.

The Copilot learns from those replies. When HR answers your ticket they can publish
the answer to the knowledge base, and the Copilot will answer that question
directly from then on. If someone else later asks the same question, they get the
verified human answer immediately instead of waiting for a new ticket.

Asking for a human directly. If an answer does not help, choose "Ask HR instead".
That routes your question to a person straight away.
""",
    ),
    (
        "handbook",
        "Roles and What Each Can Do",
        """
Roles and What Each Can Do

PeoplePay360 has five roles.

Employee. Can view their own profile, contracts, payslips, attendance and leave
balance. Can check in and out, request time off, ask the Copilot and escalate a
question to HR. Can only ever see their own records.

HR Manager. Manages employees, contracts, working schedules and attendance, and
approves time off. Owns leave, attendance and contract questions in the escalation
queue. Cannot see banking or tax identifiers and cannot run payroll.

Payroll User. Everything the HR Manager can do, plus creating and computing
payroll runs and payslips, and viewing banking details needed for payment. Can
read salary structures but not change them.

Payroll Manager. Everything a Payroll User can do, plus creating and editing
salary structures and salary rules. Owns salary and tax questions in the escalation
queue and may publish verified answers into the knowledge base.

Administrator. Full access, including user account management and the escalation
routing configuration. Owns access and catch-all questions.

Separation of duties. You cannot approve your own time off request unless you are
an Administrator, and the last active Administrator cannot demote or deactivate
themselves.
""",
    ),
]
