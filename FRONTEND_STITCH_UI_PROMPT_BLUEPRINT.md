# 🎨 PeoplePay360: Stitch Master UI/UX Prompt Blueprint
> **Purpose**: Production-Grade Prompt Engineering for **Stitch UI Builder**  
> **Aesthetic Vision**: Odoo 18 Enterprise Modern + Apple Human Interface Design System + Glassmorphism  
> **Output Target**: Pixel-Perfect, Hackathon-Winning Screens strictly matching the functional specification of `HRMS OXP - 24 hours.excalidraw.svg` and the official hackathon requirements.

---

## 💎 Stitch Master Design System & Style Guide
*(Copy and paste this section as the Global System Prompt in Stitch)*

```text
[STITCH GLOBAL DESIGN SYSTEM PROMPT]
You are designing an elite enterprise mobile HR & Payroll application called "PeoplePay360" for the Odoo Hackathon.
The interface must stand out as the top 0.1% among 1,000+ competing teams.
Follow these design specifications strictly:

1. Color Palette:
   - Primary Brand (Odoo Signature Aubergine): #714B67 (Light), #8E6083 (Dark)
   - Accent & Smart Buttons (Odoo Teal): #017E84 (Light), #00A09D (Dark)
   - Background Surface: #F8FAFC (Light Canvas), #0B0F17 (Dark Canvas)
   - Card Surface: #FFFFFF with 1px border #E2E8F0 and 8px soft blur glassmorphism
   - Success / Active / Paid: #10B981 (Emerald Green)
   - Warning / To Approve / Anomaly: #F59E0B (Amber Flame)
   - Danger / Refused / Absent: #EF4444 (Crimson Red)
   - Text Primary: #0F172A (900 slate), Text Muted: #64748B (500 slate)

2. Typography (Google Font: Plus Jakarta Sans or Outfit):
   - Display Numbers (Dashboard KPI): 28px, Bold, tracking -0.5px
   - Screen Title: 20px, SemiBold
   - Card Title / Employee Name: 16px, SemiBold
   - Body Text: 14px, Regular, 1.4 line-height
   - Status & Badges: 12px, SemiBold, all-caps, tracking +0.5px
   - Code & Financial Amounts: JetBrains Mono / SF Mono, SemiBold

3. Component Aesthetics:
   - Border Radius: 16px for Cards & Sheets, 12px for Input fields, 24px for Badges & Buttons (pill-shaped).
   - Shadows: Soft multi-layered elevation (0 4px 20px -2px rgba(113, 75, 103, 0.08)).
   - Animations & Interactions: Micro-haptics on taps, spring transitions for modals, skeleton shimmer for loading states.
   - Zero Clutter: Clean white space, high scannability, sticky filter bars, and zero boring full-page reloads.
```

---

## 📱 LEVEL 0: AUTHENTICATION & USER MANAGEMENT PROMPTS

---

### Screen 0.1: Enterprise Login & Workspace Access
- **Stitch Screen ID**: `STITCH_AUTH_LOGIN`
- **Target Route**: `/login`
- **Copy-Paste Prompt for Stitch**:
```text
Design a sleek, modern enterprise mobile login screen for "PeoplePay360" (390x844px).

Visual Hierarchy:
1. Top Section (Aubergine Gradient Header):
   - Deep rich gradient from #714B67 to #4A2E43.
   - Minimalist glowing Odoo-style app icon with subtitle "PeoplePay360 • Enterprise HR & Payroll".
   - Clean white headline: "Welcome Back" with subtext: "Sign in to continue to your workspace."

2. Center Card (Elevated Glass Surface):
   - White card container with rounded corners (24px) and subtle glass border.
   - Field 1: Work Email input field with a mail icon, placeholder "name@company.com", and validation state indicator.
   - Field 2: Password input field with a lock icon and an eye toggle to show/hide password.
   - "Forgot Password?" link aligned right in muted aubergine (#714B67).
   - Primary Action Button: "Sign In to Workspace" with deep aubergine fill (#714B67), rounded pill shape, bold white text, and subtle hover glow.

3. Quick Role Demo Switcher (Hackathon Standout Feature):
   - Horizontal pill selector below login: "Quick Demo Roles: [ Admin ] [ HR Manager ] [ Payroll User ] [ Employee ]".
   - Tapping any pill automatically fills sample credentials for fast judging evaluation.

4. Bottom Legal Footer:
   - "Secured by Odoo Enterprise RBAC • Version 2026.1" in 11px muted gray.
```

---

### Screen 0.2: Admin User Management Directory
- **Stitch Screen ID**: `STITCH_USER_MANAGEMENT_LIST`
- **Target Route**: `/settings/users`
- **Copy-Paste Prompt for Stitch**:
```text
Design an Admin User Management mobile directory screen for "PeoplePay360".

Header & Navigation:
- AppBar with title "User Management", subtitle "ADMIN ONLY", and a "+ New User" pill button (#714B67).
- Debounced Search Bar: "Search users, employees, or email...".
- Horizontal Filter Chips: [ All (5) ] [ Admin (1) ] [ Payroll Admin (1) ] [ Payroll User (1) ] [ Time Off Admin (1) ] [ Employee (1) ]. Active chip has #714B67 fill with white text.

List Items (Modern User Cards):
- Card 1: Aarav Mehta
  - Avatar: Circular badge with initials "AM" in teal gradient.
  - Title: "Aarav Mehta" (Bold 15px) | Email: "aarav@company.com" (13px muted).
  - Linked Employee Tag: "Linked: Aarav Mehta (Finance)".
  - Role Badge: "Payroll User" (Teal badge #017E84).
  - Status Indicator: Green dot + "Active" (#10B981).
- Card 2: Maya Shah | "maya@company.com" | Role: "Time Off Admin" | Status: "Active".
- Card 3: Rohan Patel | "rohan@company.com" | Role: "Time Off User" | Status: "Active".
- Card 4: Nisha Rao | "nisha@company.com" | Role: "Payroll Admin" | Status: "Active".

Interactions:
- Tapping any card opens the Edit User Modal Sheet.
- Swiping left shows quick actions: "Edit Roles" (Aubergine) and "Deactivate" (Red).
```

---

### Screen 0.3: Create / Edit User & RBAC Assignment Modal
- **Stitch Screen ID**: `STITCH_USER_EDIT_MODAL`
- **Target Route**: Bottom Sheet Modal
- **Copy-Paste Prompt for Stitch**:
```text
Design a high-end mobile bottom sheet modal for "Create / Edit User & Assign Access".

Header:
- Drag handle at top.
- Title: "Create / Edit User" with close (✕) button at top right.
- Banner Note (Odoo Policy): "User accounts are separate from Employee records, but must be linked to an employee to assign roles and ownership."

Form Layout:
1. Field: "Employee *" -> Searchable select dropdown showing list of employees (e.g. "Aarav Mehta - Payroll Specialist").
2. Field: "Work Email *" -> Auto-populated from employee ("aarav@company.com"), non-editable or editable.
3. Field: "Temporary Password *" -> Masked input with "Generate Strong Password" button.
4. Field: "Assign Roles *" (Interactive Multi-Select Checkbox Group):
   - [ ] Employee (Self-service leave & attendance)
   - [ ] HR Manager (Full employee & time off management)
   - [x] HR Payroll User (Payrun creation & payslip calculation)
   - [ ] HR Payroll Admin (Salary rules & structure config)
   - [ ] System Admin (Full system control)
5. Field: "Account Status" -> Modern iOS-style toggle switch: "Active" (Green).

Bottom Action Bar:
- Dual buttons: "Discard" (Outline gray) and "Save User Access" (Solid Aubergine #714B67).
```

---

## 👥 LEVEL 1: EMPLOYEE DIRECTORY & WORKING SCHEDULES

---

### Screen 1.1: Employees Multi-View Hub (Kanban & List)
- **Stitch Screen ID**: `STITCH_EMPLOYEE_HUB`
- **Target Route**: `/employees`
- **Copy-Paste Prompt for Stitch**:
```text
Design an enterprise Employee Directory mobile screen with Kanban & List toggle for PeoplePay360.

Header:
- Title: "Employees (42)"
- View Switcher: Segmented pill toggle: [ 🎴 Kanban ] [ 📋 List ].
- Search Bar with voice search icon: "Search employees by name, job, or department...".
- Department Filter Chips: [ All Departments ] [ Finance (12) ] [ Engineering (18) ] [ HR (4) ] [ Sales (8) ].

View Mode A: Modern Kanban Grid (2 Columns):
- Employee Card:
  - Background: White with soft rounded border (16px).
  - Avatar: Circular photo or gradient avatar with initials (e.g., "AM").
  - Name: "Aarav Mehta" (15px SemiBold).
  - Position: "Payroll Specialist" (12px Slate).
  - Department Tag: "Finance" (Subtle gray pill).
  - Status Pill: Green pulsing dot with "Active".
  - Quick action: Mini phone and email icons at card footer.

View Mode B: Compact List Row:
- Clean row with Avatar, Name, Email (aarav@oxp.com), Job Title, Department, and Chevron right (›).

Floating Action Button:
- Circular "+ NEW" button in Odoo Teal (#017E84) with drop shadow.
```

---

### Screen 1.2: Employee 360 Form & Smart Buttons Hub
- **Stitch Screen ID**: `STITCH_EMPLOYEE_DETAIL`
- **Target Route**: `/employees/:id`
- **Copy-Paste Prompt for Stitch**:
```text
Design the Employee 360 Master Form mobile screen for "Aarav Mehta".
This screen acts as the operational hub connecting Contracts, Attendance, and Time Off.

Profile Header:
- Large 64px avatar with online status indicator.
- Name: "Aarav Mehta" (20px Bold).
- Subtitle: "Payroll Specialist • Finance Department".
- Contact Row: Email ("aarav@oxp.com") | Phone ("+91 98765 43210") with tap-to-call.

Odoo-Signature Smart Buttons Ribbon (Horizontal Scrolling Ribbon):
- Smart Button 1: 🎟️ "Time Off: 3 Requests" (Teal border & background tint).
- Smart Button 2: 📜 "Contracts: 2 (1 Active)" (Aubergine border & tint).
- Smart Button 3: ⏱️ "Attendance: 14 Days" (Blue border & tint).
- Smart Button 4: 📊 "Allocations: 20 Days" (Purple border & tint).
*Each smart button displays the live record count and opens the related filtered list.*

Segmented Tabs:
[ Work Information ] [ Private Information ] [ Payroll Settings ]

Work Information Content:
- Department: "Finance"
- Manager: "Sara Khan" (clickable chip linking to manager profile)
- Working Schedule: "40 Hours / Week" (clickable chip opening schedule builder)
- Work Location: "Mumbai Head Office"
- Status: "Active" (Green badge)

Bottom Action Bar:
- "Edit Employee" button + "Export Profile PDF" icon.
```

---

### Screen 1.3 & 1.4: Working Schedule Master List & 5-Day Time Grid Builder
- **Stitch Screen ID**: `STITCH_SCHEDULE_BUILDER`
- **Target Route**: `/employees/schedules/:id`
- **Copy-Paste Prompt for Stitch**:
```text
Design a Working Schedule Builder mobile screen for "40 Hours / Week".

Top Meta Card:
- Schedule Name: "40 Hours / Week"
- Company: "OXP Pvt Ltd" | Timezone: "Asia/Kolkata (GMT +5:30)"
- Live Metric Header: "5 Days / Week • 40.0 Total Working Hours".

Weekly Shift Schedule Grid (Monday - Friday):
- Interactive time card for each day of the week:
  - Day: "Monday" (Bold)
  - Start Time: "09:00 AM" (Interactive time picker pill)
  - End Time: "06:00 PM" (Interactive time picker pill)
  - Break: "1h 00m" (Dropdown: 30m, 45m, 1h)
  - Calculated Work Hours: "8.0h" (Automated badge in Teal #017E84)
  - Remove button: (✕)
- Repeat cards for Tuesday, Wednesday, Thursday, Friday.
- "+ Add Day" dashed button to add Saturday/Sunday custom shifts.

Automated Total Summary Footer:
- Sticky bottom card: "Total Weekly Working Time: 40 Hours" with validation checkmark: "Standard 8h/day shift verified".
- Primary Button: "Save Working Schedule" (#714B67).
```

---

### Screen 1.5 & 1.6: Contracts Directory & Period Contract Form
- **Stitch Screen ID**: `STITCH_CONTRACT_FORM`
- **Target Route**: `/employees/contracts/:id`
- **Copy-Paste Prompt for Stitch**:
```text
Design an Employee Contract Form mobile screen for "CON/2026/0042".

Header:
- Reference Code: "CON/2026/0042"
- Status Stepper: [ Draft ] -> [ RUNNING (Active) ] -> [ Expired ] -> [ Cancelled ].
  Active state is "RUNNING" highlighted in Emerald Green.

Form Cards:
1. Employment Terms:
   - Employee: "Aarav Mehta" (Finance)
   - Job Position: "Payroll Specialist"
   - Contract Period: "01-Jan-2026" to "Ongoing (—)"
   - Working Schedule: "40 Hours / Week"

2. Compensation:
   - Monthly Wage: Large bold typography "₹ 85,000.00 / month" in Teal (#017E84).
   - Salary Structure: "Regular Salary Structure" (12 rules applied).

3. Period Validation Guard Banner (Hackathon Business Rule):
   - Blue alert box: "✓ Active Contract Guard: This is the single active running contract for Aarav Mehta for the current payroll period. Historical contracts are archived."

Action Buttons:
- "Update Contract Terms" (#714B67) | "Print Contract Summary".
```

---

## ⏱️ LEVEL 2: ATTENDANCE & REAL-TIME PUNCH ENGINE

---

### Screen 2.1: Quick Floating Attendance Punch Modal (Dynamic Island Style)
- **Stitch Screen ID**: `STITCH_ATTENDANCE_PUNCH_MODAL`
- **Target Route**: Persistent Floating Modal
- **Copy-Paste Prompt for Stitch**:
```text
Design an ultra-innovative Quick Attendance Punch Bottom Sheet modal for mobile (390x844px).

Visual Style:
- Glassmorphic dark card overlay with smooth frosted backdrop.
- Greeting: "Good morning, Aarav Mehta!"
- Current Date & Digital Clock: "Wednesday, Sep 02, 2026 • 09:48:22 AM".

Live Timer Gauge (Centerpiece):
- Circular animated progress ring showing percentage of 8-hour shift completed (86%).
- Center Digital Ticking Timer: Large bold numbers "06 : 56 : 14" (Hours : Minutes : Seconds) ticking live.
- Subtitle: "Elapsed time since check-in at 09:05 AM".

Status Indicators:
- Status Pill: Pulsing Emerald Green dot with text "Currently Checked In".
- Shift Target: "Target: 8h 00m | Est. Check-Out: 06:05 PM".

Punch Button Action:
- When Checked In: Large Crimson Red pill button "CHECK OUT NOW" (#EF4444) with biometric fingerprint icon and haptic confirmation.
- When Checked Out: Large Emerald Green pill button "CHECK IN TO SHIFT" (#10B981).

Footer Note:
- "Geofence verified: Mumbai Head Office (Wi-Fi: OXP-Corp-5G)".
```

---

### Screen 2.2 & 2.3: Attendance Master Logs & Audit Inspector
- **Stitch Screen ID**: `STITCH_ATTENDANCE_LOGS`
- **Target Route**: `/attendance`
- **Copy-Paste Prompt for Stitch**:
```text
Design the Attendance Records Directory mobile screen.

Header:
- Title: "Attendance Records"
- Quick Filter Pills: [ Today (Sep 2) ] [ My Team ] [ Missing Check-outs (5) ] [ Late Entries (18) ].

List View (Card Rows):
- Row 1: Aarav Mehta
  - Time: 09:05 AM -> 06:10 PM | Worked: 9.08 hrs (Overtime: +0.50h)
  - Badge: "Present" (Green #10B981).
- Row 2: Sara Khan
  - Time: 09:15 AM -> 06:02 PM | Worked: 8.78 hrs
  - Badge: "Present" (Green #10B981).
- Row 3: John Dsouza
  - Time: 09:32 AM -> 05:58 PM | Worked: 8.43 hrs
  - Badge: "Present" (Green #10B981).
- Row 4: Neha Patel
  - Time: — -> — | Worked: 0.00 hrs
  - Badge: "Absent" (Red #EF4444) with quick "Log Leave" action.

Tapping any row opens the Audit Inspector to review timestamps or request manual correction.
```

---

## 🏖️ LEVEL 3: TIME OFF & LEAVE ALLOCATIONS

---

### Screen 3.1 & 3.2: Time Off Requests Hub & Swipe-to-Approve
- **Stitch Screen ID**: `STITCH_LEAVE_REQUESTS`
- **Target Route**: `/timeoff/requests`
- **Copy-Paste Prompt for Stitch**:
```text
Design the Time Off Requests Hub mobile screen with Manager Swipe Actions.

Header:
- Title: "Time Off Requests"
- Filter Tabs: [ To Approve (3) ] [ Approved ] [ My Team ] [ All Requests ].
- "To Approve" tab has a red counter badge (🔴 3).

Request Cards:
- Card 1: Aarav Mehta
  - Leave Type: "Paid Time Off" (Blue pill).
  - Date Range: "12-Sep-2026 -> 14-Sep-2026 (3 Working Days)".
  - Balance Impact: "Consumes 3 days from Annual Leave 2026 (12 days remaining)".
  - Reason: "Family vacation to Goa".
  - Approver: "Sara Khan".
  - Status: "To Approve" (Amber badge #F59E0B).
  - Action Buttons (Dual Buttons):
    - [ ✓ Approve ] (Solid Emerald Green #10B981).
    - [ ✕ Refuse ] (Outline Crimson Red #EF4444).

- Card 2: Sara Khan | "Sick Leave" | "18-Sep (1 Day)" | Status: "Approved".
- Card 3: John Dsouza | "Comp Off" | "27-Sep (1 Day)" | Status: "To Approve".

Floating Action Button:
- "+ Request Leave" in Odoo Teal (#017E84).
```

---

### Screen 3.3 & 3.4: Leave Allocations Balance Math Matrix
- **Stitch Screen ID**: `STITCH_ALLOCATION_MATRIX`
- **Target Route**: `/timeoff/allocations`
- **Copy-Paste Prompt for Stitch**:
```text
Design the Leave Allocations Matrix mobile screen displaying balance equations.

Header:
- Title: "Leave Allocations & Balances"
- Subtitle: "Year 2026 • Policy Balances".

Allocation Cards (Visual Math Representation):
- Card: Aarav Mehta • Paid Time Off
  - Visual Progress Bar:
    - 40% Taken (Dark Amber)
    - 60% Remaining (Teal Green)
  - Math Equation Grid:
    - [ Allocated: 20 Days ] = [ Taken: 8 Days ] + [ Remaining: 12 Days ]
  - Validity: "Valid until Dec 31, 2026".
  - Status: "Approved by Sara Khan" (Green checkmark).

- Card: Sara Khan • Paid Time Off
  - [ Allocated: 18 Days ] = [ Taken: 4 Days ] + [ Remaining: 14 Days ].

- Card: Neha Patel • Comp Off
  - [ Allocated: 2 Days ] = [ Taken: 1 Day ] + [ Remaining: 1 Day ].
```

---

## 💰 LEVEL 4: PAYRUN & PAYSLIP PIPELINE (CORE CHALLENGE)

---

### Screen 4.1: 2-Step Interactive Payrun Creation Wizard (Modal Sheet)
- **Stitch Screen ID**: `STITCH_PAYRUN_WIZARD`
- **Target Route**: Modal Sheet Stepper
- **Copy-Paste Prompt for Stitch**:
```text
Design a 2-Step Payrun Creation Wizard mobile sheet for PeoplePay360.

Step Indicator at Top:
- Step 1: Define Scope (Completed/Active)  ------>  Step 2: Select Employees (Active)

--- VIEW FOR STEP 1: DEFINE SCOPE ---
- Title: "New Pay Run (Step 1 of 2)"
- Subtitle: "Choose the salary structure and payroll period."
- Dropdown 1: "Salary Structure *" -> "United States: Regular Pay" or "India: Regular Salary".
- Date Range Picker: "Period *" -> "01-Sep-2026" to "30-Sep-2026" (September 2026).
- Policy Note Banner: "Clicking Continue moves to employee selection. The Payrun record is only created after selecting employees in Step 2."
- Bottom Button: "Continue to Employee Selection →" (Aubergine fill #714B67).

--- VIEW FOR STEP 2: SELECT EMPLOYEES ---
- Title: "Select Employee Records (Step 2 of 2)"
- Header: "22 Employees Eligible for September 2026" with "Select All (22)" checkbox.
- Employee Selection List (Rows with checkboxes):
  - [✓] Anita Oliver | 40h/wk | Start: Jan 1 | Wage: $4,500.00
  - [✓] Audrey Peterson | 40h/wk | Start: Jan 1 | Wage: $4,000.00
  - [✓] Billy Kyle | 40h/wk | Start: Sep 2 | Wage: $3,100.00
  - [✓] Eli Lambert | 40h/wk | Start: Jan 1 | Wage: $4,350.00
  - [✓] Paul Williams | 40h/wk | Start: Jul 1 | Wage: $3,950.00
- Sticky Bottom Summary:
  - Text: "22 Employees Selected • Est. Gross: $92,400.00"
  - Dual Buttons: "← Back to Scope" (Outline) | "Create Payrun Batch ✓" (Solid Teal #017E84).
```

---

### Screen 4.2 & 4.3: Payrun Command Center & Anomaly Alert Inspector
- **Stitch Screen ID**: `STITCH_PAYRUN_COMMAND_CENTER`
- **Target Route**: `/payroll/payruns/:id`
- **Copy-Paste Prompt for Stitch**:
```text
Design the Payrun Command Center mobile screen for "February 2026".

Header Banner:
- Title: "Payrun / February 2026"
- Status Badge: "Validated" (Blue #2563EB).
- Summary Metrics Row:
  - Structure: Regular Salary | Period: 01-Feb - 28-Feb | Employees: 42 | Net: ₹ 18.4L.

Operational Pipeline Toolbar (Horizontal Action Bar):
- [ ⚡ COMPUTE ] (Recalculates all draft payslips via salary rules).
- [ 🛡️ VALIDATE ] (Locks payslips and runs pre-flight anomaly checks).
- [ 💵 MARK PAID ] (Marks payouts as complete).
- [ 📤 SEND PAYSLIPS ] (Bulk email PDF payslips to all employees).

Payroll Warnings Alert Card (Standout Feature):
- Amber warning container with ⚠️ icon:
  - "⚠️ 2 employees missing bank account details (Sara Khan, Neha Patel)"
  - "⚠️ 1 duplicate payslip detected (John Dsouza)"
  - "⚠️ 4 draft payslips pending validation"

Embedded Payslips List (42 Records):
- Row: Aarav Mehta | 22 Worked Days | Basic: ₹50k | Gross: ₹80k | Net: ₹75k | Status: "Done" | [ 📄 PDF ].
- Row: Sara Khan | ⚠️ A/C Missing | Net: ₹88k | Status: "Done" | [ 📄 PDF ].
- Row: John Dsouza | ⚠️ Duplicate | Net: ₹66k | Status: "Draft" | [ 📄 PDF ].
```

---

### Screen 4.5 & 4.6: Employee Payslip Computation Tree & Official PDF Preview
- **Stitch Screen ID**: `STITCH_PAYSLIP_DETAIL`
- **Target Route**: `/payroll/payslips/:id`
- **Copy-Paste Prompt for Stitch**:
```text
Design the detailed Payslip Computation Tree and In-App PDF Preview mobile screen for "Aarav Mehta - February 2026".

Payslip Meta Header:
- Name: "Aarav Mehta" | Payrun: "February 2026"
- Contract Wage: "₹ 85,000.00" | Worked Days: "22 Days" | Status: "Done".

Salary Computation Tree (Structured Breakdown):
- Table showing Rule Name, Category, Code, and Computed Amount:
  - 🟢 Basic Salary (BASIC) | Basic | + ₹ 50,000.00
  - 🟢 House Rent Allowance (HRA) | Allowance | + ₹ 20,000.00
  - 🟢 Standard Allowance (STD) | Allowance | + ₹ 10,000.00
  - 🔵 Gross Salary Total (GROSS) | Gross | = ₹ 80,000.00
  - 🔴 Provident Fund (PF) | Deduction | - ₹ 3,000.00
  - 🔴 Professional Tax (PT) | Deduction | - ₹ 2,000.00
  - 🟢 Net Salary Payable (NET) | Net | = ₹ 75,000.00 (Highlighted in bold teal card).

Bottom Action Bar:
- [ 🖨️ Print / Preview PDF ] (Opens high-res official A4 payslip viewer).
- [ 📤 Share via WhatsApp / Email ].
```

---

## ⚙️ LEVEL 5: SALARY STRUCTURES & PYTHON CODE RULES

---

### Screen 5.2 & 5.4: Ordered Rule Sequencing & Python Code Syntax Editor
- **Stitch Screen ID**: `STITCH_SALARY_RULE_EDITOR`
- **Target Route**: `/payroll/rules/:id`
- **Copy-Paste Prompt for Stitch**:
```text
Design the Salary Rule Builder & Python Syntax Editor mobile screen for "Gross Salary (GROSS)".

Rule Identity:
- Rule Name: "Gross Salary" | Code: "GROSS" | Category: "Gross" | Sequence: "60".

Computation Type Switcher:
- Radio Segment: [ Fixed Amount ] [ Percentage of Base ] [ Python Code / Formula (Selected) ].

Python Code Editor Widget (Monaco / JetBrains Dark Theme):
- Dark syntax-highlighted code editor container with line numbers:
  1 | # Dynamic Salary Rule Expression
  2 | # Available objects: contract, worked_days, categories, rules
  3 | result = categories['BASIC'] + categories['ALLOWANCE']
  4 | if worked_days < 20:
  5 |     result = (categories['BASIC'] / 22) * worked_days
- Quick Insert Token Chips:
  [ + contract.wage ] [ + categories['BASIC'] ] [ + worked_days ] [ + rules['HRA'] ].

Formula Validation Sandbox:
- "Test Formula" button with instant preview output: "✓ Syntax Valid • Output: ₹ 80,000.00".
- Bottom Button: "Save Salary Rule" (#714B67).
```

---

## 📊 LEVEL 6: EXECUTIVE HR & PAYROLL ANALYTICS COMMAND CENTER

---

### Screen 6.1: Executive Dashboard (Cross-Model Analytics)
- **Stitch Screen ID**: `STITCH_EXECUTIVE_DASHBOARD`
- **Target Route**: `/dashboard`
- **Copy-Paste Prompt for Stitch**:
```text
Design the Executive HR & Payroll Analytics Command Center mobile dashboard for PeoplePay360.
This dashboard integrates live data from Employees, Contracts, Attendances, Time Off, and Payroll.

Sticky Top Filter Bar:
- Horizontal scrolling filter chips: [ Period: Sep 2026 ▾ ] [ Dept: All ▾ ] [ Type: All Staff ▾ ] [ Company: OXP Pvt Ltd ▾ ].

1. Executive 5-KPI Metric Ribbon (Horizontal Cards):
   - Card 1: 💳 Net Salary Paid: "₹ 18.4L" (Green badge "+8.5% vs last month").
   - Card 2: 📄 Payslips: "148" (Subtext: "142 paid, 6 pending").
   - Card 3: ⚖️ Avg Salary: "₹ 12,432" (Subtext: "Based on active contracts").
   - Card 4: 🏖️ Leave Days: "34 Days" (Subtext: "Approved in period").
   - Card 5: 🛡️ Attendance Health: "94%" (Subtext: "Present coverage").

2. Interactive Charts Section:
   - Chart A (Bar Chart): "Salary Cost by Department"
     - Horizontal bars: IT (₹170k), Sales (₹150k), Finance (₹130k), Support (₹110k), HR (₹90k).
   - Chart B (Spline Gradient Area Chart): "Monthly Net Salary Trend"
     - Smooth curve across 6 months: Apr (14.8L) -> May (15.2L) -> Jun (14.3L) -> Jul (15.0L) -> Aug (17.1L) -> Sep (18.4L).

3. Operational Alerts & Attendance Health Row:
   - Left Card: "Attendance Split" -> Present (94), Late (18), Absent (9), Overtime (22). Missing punches alert: 5.
   - Right Card: "Payroll Anomalies" -> 2 missing bank accounts, 1 duplicate payslip, 4 unvalidated drafts.

4. Department Master Table:
   - Department | Headcount | Monthly Salary Total
   - IT | 18 Staff | ₹ 4.2L
   - Sales | 22 Staff | ₹ 5.7L
   - HR | 8 Staff | ₹ 1.9L
   - Support | 14 Staff | ₹ 3.1L
```

---

## 🤖 LEVEL 7: AI HR ASSISTANT & RAG COPILOT (STANDOUT INNOVATION)

---

### Screen 7.1: AI HR & Payroll Copilot Floating Drawer
- **Stitch Screen ID**: `STITCH_AI_COPILOT`
- **Target Route**: `/copilot` (Floating Assistant Modal)
- **Copy-Paste Prompt for Stitch**:
```text
Design an AI HR & Payroll Copilot conversational mobile drawer for PeoplePay360.

Header:
- Title: "PeoplePay360 AI Assistant"
- Subtitle: "Powered by Local RAG & PostgreSQL" with a green active node indicator.
- Action: "Clear Chat" and "Minimize (—)".

Suggested Question Chips (Quick Starters):
- [ "How many PTO days do I have left?" ]
- [ "Explain the deductions on my Feb payslip" ]
- [ "What is our policy for sick leave medical certificates?" ]

Chat Message Thread:
- User Bubble: "Why was ₹5,000 deducted from my February payslip?"
- AI Copilot Bubble (Rich Markdown & Cards):
  - "Hello Aarav! Based on your **February 2026 Payslip (SLIP/2026/0001)**, your total deductions were **₹5,000.00** broken down as follows:
    1. **Provident Fund (PF)**: ₹3,000.00 (12% of Basic Salary)
    2. **Professional Tax (PT)**: ₹2,000.00 (Standard statutory slab)
    *No penalties or unpaid leave deductions were applied.*"
  - Source Citation Chip: "Verified with Regular Salary Rule Engine & Indian Statutory Tax Slabs".

Input Bar at Bottom:
- Pill-shaped input: "Ask anything about HR policy, salary, or leave..." with a mic icon and an Aubergine send button (#714B67).
```

---

## 🚀 How To Feed These Prompts Into Stitch
1. Paste the **Stitch Master Design System Prompt** into Stitch's global configuration.
2. Generate screen-by-screen starting from **Screen 0.1 (Login)** through **Screen 6.1 (Dashboard)** and **Screen 7.1 (AI Copilot)**.
3. Every prompt explicitly dictates color codes, typography sizes, interactive states, and business validation messages to produce a **flawless, production-grade mobile app experience**.
