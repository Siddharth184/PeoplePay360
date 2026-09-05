# 🚀 Production-Grade HRMS & Payroll Flutter Master Prompt Blueprint
> **Codename**: *PeoplePay 360* (Odoo Hackathon Winning Edition)  
> **Target Framework**: Flutter 3.35+ / Dart 3.9+ (latest stable channel)  
> **Design Language**: Odoo 18 Next-Gen + Apple Human Interface Guidelines + Glassmorphism  
> **Source Blueprint**: 100% Strict Alignment to `HRMS OXP - 24 hours.excalidraw.svg`

---

## 🌟 Executive Strategy: Why This App Wins The Hackathon

To stand out among **1,000+ teams**, the implementation must go beyond basic CRUD forms. It must feel like an **ultra-smooth, enterprise-grade, lightning-fast mobile application** that enterprise HR leaders and employees genuinely love using.

### Key Standout Innovations Built In:
1. **Dynamic Island Attendance Widget**: Quick floating attendance pill with real-time ticking timer, biometric punch simulation, and instant status color transition (Crimson 🔴 $\to$ Emerald 🟢).
2. **2-Step Animated Payrun Wizard**: Bottom sheet with spring animation that isolates payroll scope selection from batch employee filtering with real-time aggregate wage calculation.
3. **Smart Rule Python Engine**: Code syntax-highlighted editor for salary rules with real-time expression validation (`result = categories['BASIC'] * 0.20`).
4. **Instant In-App PDF Generation & Preview**: Pixel-perfect Odoo-style Payslip thermal/A4 preview with one-tap WhatsApp/Email share using Flutter `printing` and `pdf` packages.
5. **Real-Time Cross-Model HR Analytics**: Touch-interactive charts (`fl_chart`) merging Payslips, Contracts, Attendances, and Time Off Allocations with live payroll warning alerts.
6. **Smart Button Navigation Architecture**: Relational counters on Employee profiles (`Time Off: 3`, `Contracts: 2`, `Attendance: 14`) that open pre-filtered lists with seamless Hero transitions.

---

## 🎨 Global Design System & Token Architecture

### 1. Color Palette (Light & Dark HSL Tokens)
| Token Name | Light Mode Hex | Dark Mode Hex | Usage |
| :--- | :--- | :--- | :--- |
| **Odoo Primary (Aubergine)** | `#714B67` | `#A27B99` | Main brand, AppBars, Primary Buttons, Active Tabs |
| **Odoo Secondary (Teal)** | `#017E84` | `#00A09D` | Accents, Smart Buttons, Metric Highlights, Positive Trends |
| **Deep Background** | `#F8FAFC` | `#0B0F17` | Canvas scaffold background |
| **Surface Card** | `#FFFFFF` | `#161F30` | Glass cards, Modals, Form Containers |
| **Surface Elevated** | `#F1F5F9` | `#1E293B` | Table headers, chip backgrounds, disabled inputs |
| **Success / Present / Paid** | `#10B981` | `#059669` | Check-in active, Done status, Paid payslips |
| **Warning / Pending / Draft**| `#F59E0B` | `#D97706` | To Approve, Draft payrun, Anomaly alerts |
| **Danger / Absent / Refuse** | `#EF4444` | `#DC2626` | Check-out required, Refused leaves, Critical warnings |
| **Text Primary** | `#0F172A` | `#F8FAFC` | Main headings, Employee names, Metric values |
| **Text Secondary** | `#64748B` | `#94A3B8` | Subtitles, Field labels, Helper hints |
| **Border / Divider** | `#E2E8F0` | `#334155` | Outlines, table borders, card dividers |

### 2. Typography Hierarchy (Google Fonts: `Plus Jakarta Sans` or `Outfit`)
- **Display 1** (28px, Bold, Tracking -0.5): Dashboard metrics, Hero payroll figures
- **Heading 1** (22px, SemiBold): Screen titles, Drawer headers
- **Heading 2** (18px, SemiBold): Card titles, Section dividers
- **Body Regular** (14px, Regular): List item details, Form values
- **Label Small** (12px, Medium, Tracking +0.2): Status badges, Table headers, Helper text
- **Mono Code** (13px, `JetBrains Mono`): Python rule expressions, Contract codes, Wage numbers

### 3. Recommended Flutter Packages Stack
```yaml
dependencies:
  flutter:
    sdk: flutter
  # State Management & DI
  flutter_riverpod: ^2.5.1
  riverpod_annotation: ^2.3.5
  freezed_annotation: ^2.4.4
  
  # Navigation & Modals
  go_router: ^14.2.0
  wolt_modal_sheet: ^0.5.0
  modal_bottom_sheet: ^3.0.0
  
  # UI, Micro-Animations & Sliders
  flutter_animate: ^4.5.0
  flutter_slidable: ^3.1.0
  badges: ^3.1.2
  shimmer: ^3.0.0
  glassmorphism_ui: ^0.3.0
  
  # Charts & Visualizations
  fl_chart: ^0.68.0
  percent_indicator: ^4.2.3
  
  # PDF Generation & Code Editor
  pdf: ^3.10.8
  printing: ^5.12.0
  flutter_highlight: ^0.7.0
  code_text_field: ^2.2.1
  
  # Utilities & Formatting
  intl: ^0.19.0
  uuid: ^4.4.0
  haptic_feedback: ^0.5.1+1

  # AI Copilot (Phase 7)
  flutter_markdown: ^0.7.4   # render rich RAG answers
  http: ^1.2.2               # call the /api/v1/ai/assistant endpoint
```
> **Version note**: The pins above are a known-good, mutually compatible baseline. On a fresh checkout run `flutter pub upgrade --major-versions` to pull the current majors for your installed Flutter stable channel, then `flutter pub outdated` to confirm nothing conflicts.

---

# 📱 SCREEN-BY-SCREEN MASTER SPECIFICATIONS & PROMPT BLUEPRINT

---

## 🔐 PHASE 0: Authentication, Multi-Tenant & User Access Flow

```
+-------------------------------------------------------------------------------+
| FLOW 0: AUTHENTICATION & USER MANAGEMENT                                      |
|                                                                               |
|  [0.1 Login Screen] ---> [Successful Auth] ---> [Role-Based Dashboard]        |
|          |                                                                    |
|  (Admin Only)                                                                 |
|          v                                                                    |
|  [0.2 User Management List] ---> [0.3 Create/Edit User Modal]                 |
|       - Filter by Role               - Link Employee Record                   |
|       - Active/Inactive              - Assign Roles & Privileges              |
+-------------------------------------------------------------------------------+
```

---

### Screen 0.1: Enterprise Login & Workspace Access
- **Screen ID**: `SCR_AUTH_LOGIN`
- **Route**: `/login`
- **Role Visibility**: Public / All Users
- **Visual Design & UX**:
  - Deep Aubergine gradient header with modern glass card form.
  - Odoo logo + **PeoplePay 360** animated badge.
  - Work email input (`name@company.com`) with real-time email regex validator.
  - Password input with toggleable visibility eye icon and haptic confirmation.
  - Role switcher quick-demo pill: `[ Admin ]` `[ HR Manager ]` `[ Payroll User ]` `[ Employee ]` for fast hackathon judging evaluation.
  - "Sign In to Workspace" primary button with Odoo Aubergine fill (`#714B67`) and loading spinner state.
- **On Click & Navigation Actions**:
  - Click `Sign In` $\to$ Authenticates user, stores JWT/Session token, determines Role $\to$ Navigates to `SCR_DASHBOARD_MAIN` (`/dashboard`).
  - Click `Forgot Password?` $\to$ Opens glass modal bottom sheet for email OTP reset.
  - Click `Quick Demo Role Pills` $\to$ Auto-populates credentials for Aarav Mehta (Payroll), Maya Shah (Time Off Admin), or Nisha Rao (Payroll Admin).
- **Production Edge Cases**:
  - Account inactive check: Displays warning banner if user status is `Inactive`.
  - Rate limiting with animated 30s lockout counter after 5 invalid attempts.

---

### Screen 0.2: User Management Directory (Admin Only)
- **Screen ID**: `SCR_USER_MANAGEMENT_LIST`
- **Route**: `/settings/users`
- **Role Visibility**: `Hr Payroll Admin`, `System Admin` only
- **Visual Design & UX**:
  - Top Search bar (`Search users, employees or email...`) with instant debounce filtering.
  - Horizontal Role Filter Chips: `All`, `Admin`, `Payroll Admin`, `Payroll User`, `Time Off Admin`, `Time Off User`, `Employee`.
  - List item cards:
    - User Avatar with initials badge.
    - User Full Name + Work Email (`aarav@company.com`).
    - Linked Employee Name chip.
    - Role pill badge (e.g. `Payroll User` in Teal `#017E84`, `Admin` in Aubergine `#714B67`).
    - Status pill: `Active` (Emerald Green `#10B981`) or `Inactive` (Slate Gray).
- **On Click & Navigation Actions**:
  - Click `+ New User` floating action button / header action $\to$ Opens `SCR_USER_FORM_MODAL` with empty state.
  - Click on any User Card $\to$ Opens `SCR_USER_FORM_MODAL` pre-populated in Edit mode.
  - Swipe User Card Left $\to$ Shows quick toggle for `Deactivate / Activate User`.

---

### Screen 0.3: Create / Edit User & RBAC Assignment
- **Screen ID**: `SCR_USER_FORM_MODAL`
- **Route**: `/settings/users/edit/:id` (Modal Bottom Sheet / Full Screen Dialog)
- **Visual Design & UX**:
  - Form Fields:
    - `Employee *` (Searchable Dropdown selector populated from active Employee records).
    - `Work Email *` (Auto-filled from selected Employee, editable).
    - `Password` (Auto-generated temporary password or manual input).
    - `Roles Multi-Select *` (Checkbox chips: `Employee`, `HR Manager`, `HR Payroll User`, `HR Payroll Admin`, `Admin`).
    - `Account Status` (Toggle switch: `Active` / `Inactive`).
  - Explanatory security note banner: *"Users must not be able to assign or elevate their own roles. Roles control which modules and smart buttons appear."*
- **On Click & Navigation Actions**:
  - Click `Select Employee` $\to$ Opens quick employee bottom sheet picker.
  - Click `Save Access / Create User` $\to$ Validates required fields, links user to employee, updates RBAC permissions, closes sheet with toast.
  - Click `Discard / Close (✕)` $\to$ Reverts unsaved changes with confirmation alert.

---

## 👥 PHASE 1: Employee Directory & Working Schedule Engine

```
+-------------------------------------------------------------------------------+
| FLOW 1: EMPLOYEES & WORKING SCHEDULES                                         |
|                                                                               |
|  [1.1 Employees Hub] (Kanban <--> List View Toggle)                           |
|          |                                                                    |
|          +---> [1.2 Employee 360 Form]                                        |
|          |         |-- [Time Off (3) Smart Button]  ---> SCR_LEAVE_REQUESTS   |
|          |         |-- [Contracts (2) Smart Button] ---> SCR_CONTRACTS_LIST   |
|          |         \-- [Attendance (14) Button]     ---> SCR_ATTENDANCE_LOGS  |
|          |                                                                    |
|  [1.3 Working Schedules List] ---> [1.4 Schedule Builder Form (Mon-Fri Grid)] |
|  [1.5 Contracts List]         ---> [1.6 Contract Detail & Wage Form]          |
+-------------------------------------------------------------------------------+
```

---

### Screen 1.1: Employees Multi-View Hub (Kanban & List)
- **Screen ID**: `SCR_EMPLOYEE_HUB`
- **Route**: `/employees`
- **Visual Design & UX**:
  - AppBar with search field + View Mode Switcher (`Kanban` 🎴 / `List` 📋).
  - Department Filter Chips (`All`, `Finance`, `Engineering`, `HR`, `Sales`, `Support`).
  - **Kanban View (Default)**:
    - 2-Column Responsive Staggered Grid.
    - Employee Card:
      - Gradient Avatar circle with initials (`AM`, `SK`, `JD`, `NP`).
      - Employee Name (Bold 15px).
      - Job Position (`Payroll Specialist`, `HR Officer`, `Developer`).
      - Department Tag (`Finance`, `Engineering`).
      - Active Status Dot (Green `#10B981`).
  - **List View**:
    - Compact Data Row: Avatar, Name, Email (`aarav@oxp.com`), Job, Department, Status Pill.
- **On Click & Navigation Actions**:
  - Click any Employee Card / Row $\to$ Navigates to `SCR_EMPLOYEE_DETAIL` (`/employees/:id`) with Hero animation on avatar and name.
  - Click `+ NEW` $\to$ Navigates to `SCR_EMPLOYEE_DETAIL` in creation mode (`/employees/new`).
  - Quick action swipe on list row: Call / Email / Mark Inactive.

---

### Screen 1.2: Employee 360 Form & Smart-Action Hub
- **Screen ID**: `SCR_EMPLOYEE_DETAIL`
- **Route**: `/employees/:id`
- **Visual Design & UX**:
  - Top Profile Header with Large Avatar, Full Name (`Aarav Mehta`), Job Title (`Payroll Specialist • Finance`), Email, and Phone (`+91 98765 43210`).
  - **Smart Buttons Bar (Odoo Signature Feature)**:
    - 🎟️ `Time Off [ 3 ]` (Teal background, shows remaining days / requests).
    - 📜 `Contracts [ 2 ]` (Aubergine background, shows total contracts).
    - ⏱️ `Attendance [ 14 ]` (Blue background, shows present records count).
  - Tabbed Segmented Control:
    - **Tab A: Work Information**: Department (`Finance`), Manager (`Sara Khan`), Work Location (`Mumbai`), Working Schedule (`40 Hours / Week`), Company (`OXP Pvt Ltd`), Work Email (`aarav@oxp.com`), Status (`Active`).
    - **Tab B: Private Information**: Bank Account Details, Identification Number, Emergency Contact, Address.
- **On Click & Navigation Actions**:
  - Click `Time Off [ 3 ]` Smart Button $\to$ Opens `SCR_LEAVE_REQUESTS` pre-filtered for `Employee == Aarav Mehta`.
  - Click `Contracts [ 2 ]` Smart Button $\to$ Opens `SCR_CONTRACTS_LIST` pre-filtered for `Employee == Aarav Mehta`.
  - Click `Attendance [ 14 ]` Smart Button $\to$ Opens `SCR_ATTENDANCE_LOGS` pre-filtered for `Employee == Aarav Mehta`.
  - Click `Working Schedule ("40 Hours / Week")` field $\to$ Direct link to open `SCR_SCHEDULE_DETAIL`.
  - Click `EDIT / SAVE` $\to$ Toggles inline editing mode.

---

### Screen 1.3: Working Schedules Master Directory
- **Screen ID**: `SCR_SCHEDULES_LIST`
- **Route**: `/employees/schedules`
- **Visual Design & UX**:
  - Search bar + Filter button.
  - Schedule Cards showing:
    - Schedule Name (`40 Hours / Week`, `Night Shift`, `Retail Weekend`, `Flexible Hybrid`, `Part-time 20h`).
    - Days / Week badge (e.g. `5 Days`).
    - Total Hours / Week (e.g. `40h`, `37.5h`, `20h`).
    - Company (`My Company` / `OXP Pvt Ltd`).
    - Status (`Active` / `Inactive`).
- **On Click & Navigation Actions**:
  - Click on any Schedule Card $\to$ Opens `SCR_SCHEDULE_DETAIL` (`/employees/schedules/:id`).
  - Click `+ New Schedule` $\to$ Opens `SCR_SCHEDULE_DETAIL` in creation mode.

---

### Screen 1.4: Working Schedule Builder & Weekly Time Grid
- **Screen ID**: `SCR_SCHEDULE_DETAIL`
- **Route**: `/employees/schedules/:id`
- **Visual Design & UX**:
  - Header: Schedule Name (`40 Hours / Week`), Days/Week (`5`), Hours/Week (`40h`), Timezone (`Asia/Kolkata`).
  - **Weekly Schedule Time Grid Table**:
    - Columns: `Day`, `Start Time`, `End Time`, `Break`, `Calculated Hours`, `Action (✕)`.
    - Rows: Monday through Friday (`9:00 AM` to `6:00 PM`, `1h break` = `8h`).
  - Live Calculated Total Card: **Total Weekly Hours: 40h**.
  - `+ Add Day` button to add Saturday/Sunday custom shifts.
- **On Click & Navigation Actions**:
  - Click time picker on `Start Time` / `End Time` $\to$ Opens Cupertino Wheel / Material TimePicker.
  - Click `(✕)` $\to$ Removes shift row and recalculates total weekly hours instantly.
  - Click `Save Schedule` $\to$ Validates that weekly hours equal the sum of day shifts.

---

### Screen 1.5: Employee Contracts Master List
- **Screen ID**: `SCR_CONTRACTS_LIST`
- **Route**: `/employees/contracts`
- **Visual Design & UX**:
  - Filter chips: `All Contracts`, `Running (Active)`, `Draft`, `Expired`.
  - Search by Contract Reference or Employee Name (`CON/2026/0042`, `Aarav Mehta`).
  - Contract Card:
    - Reference Code in bold mono (`CON/2026/0042`).
    - Employee Name (`Aarav Mehta`) + Department (`Finance`).
    - Start Date & End Date (`01-Jan-26` $\to$ `Ongoing`).
    - Wage / Month prominently highlighted in bold Teal (`₹85,000` or `$4,500.00`).
    - Status Badge: `Running` (Emerald Green `#10B981`), `Expired` (Slate `#94A3B8`), `Draft` (Amber `#F59E0B`).
- **On Click & Navigation Actions**:
  - Click any Contract Card $\to$ Navigates to `SCR_CONTRACT_DETAIL` (`/employees/contracts/:id`).
  - Click `+ NEW` $\to$ Opens contract creation form.

---

### Screen 1.6: Employee Contract Detail & Wage Configuration
- **Screen ID**: `SCR_CONTRACT_DETAIL`
- **Route**: `/employees/contracts/:id`
- **Visual Design & UX**:
  - Contract Reference Banner (`CON/2026/0042` - `Running`).
  - Form Fields:
    - `Employee *`: Searchable Picker (`Aarav Mehta`).
    - `Department` & `Job Position`: (`Finance` / `Payroll Specialist`).
    - `Start Date *` & `End Date`: (`01-Jan-2026` to `—`).
    - `Wage / Month *`: Currency input (`₹85,000`).
    - `Working Schedule`: Dropdown (`40 Hours / Week`).
    - `Salary Structure`: Dropdown (`Regular Salary Structure`).
    - `Notes / Structure Type`: Text box (*"This running contract is the source for payroll calculation in active period."*).
- **On Click & Navigation Actions**:
  - Status progression stepper: `[ Draft ]` $\to$ `[ Running ]` $\to$ `[ Expired ]` $\to$ `[ Cancelled ]`.
  - Validation Rule: If another `Running` contract exists for this employee in the same period, prompt conflict alert dialog before activating.

---

## ⏱️ PHASE 2: Attendance System & Real-Time Punch Engine

```
+-------------------------------------------------------------------------------+
| FLOW 2: ATTENDANCE & REAL-TIME PUNCH                                          |
|                                                                               |
|  [Global Floating Punch Widget]                                               |
|       |                                                                       |
|       v                                                                       |
|  [2.1 Check-In / Check-Out Glass Modal] ---> Live Ticking Timer + Status Pill |
|                                                                               |
|  [2.2 Attendance Records List]                                                |
|       - Quick filters: [Today] [My Attendance] [Missing Punches]              |
|       - Columns: In, Out, Worked Hours, Status                                |
|       |                                                                       |
|       v                                                                       |
|  [2.3 Attendance Inspector Form] ---> Overtime Audit & Manual Fix Log         |
+-------------------------------------------------------------------------------+
```

---

### Screen 2.1: Quick Attendance Floating Widget & Punch Modal
- **Screen ID**: `SCR_ATTENDANCE_WIDGET_MODAL`
- **Component**: Global persistent navbar icon & Wolt Modal Sheet
- **Visual Design & UX**:
  - Floating pill on AppBar: Shows current state (🔴 Red Clock when checked out, 🟢 Green Pulsing Clock when checked in).
  - Clicking opens **Punch Command Bottom Sheet**:
    - Greeting: *"Welcome back, Aarav Mehta!"*
    - Date: Today's date with live digital clock (`09:48:22 AM`).
    - Real-Time Elapsed Timer: Large bold typography (`6h 56m 12s`) ticking every second if checked in.
    - Worked Hours Progress Ring: Showing percentage of daily 8h target.
    - Main Punch Action Button:
      - When Checked Out: Large Green Button `[ CHECK IN ]` with fingerprint/clock icon.
      - When Checked In: Large Crimson Button `[ CHECK OUT ]` with haptic feedback.
- **On Click & Navigation Actions**:
  - Click `CHECK IN` $\to$ Captures timestamp (`02-Sep-2026 09:05`), changes status indicator to Green, starts live ticker, triggers haptic success.
  - Click `CHECK OUT` $\to$ Captures checkout timestamp, calculates exact worked hours (`9.08 hrs`), overtime (`0.50 hrs`), closes modal with celebration micro-animation.

---

### Screen 2.2: Attendance Logs Master Directory
- **Screen ID**: `SCR_ATTENDANCE_LIST`
- **Route**: `/attendance`
- **Visual Design & UX**:
  - Filter pills: `Today`, `My Attendance`, `Finance Team`, `Missing Check-outs`.
  - Search bar (`Search attendance by employee...`).
  - Attendance Card / List Row:
    - Employee Name & Avatar (`Aarav Mehta`, `Sara Khan`, `John Dsouza`, `Neha Patel`).
    - Check-In Time (`09:05 AM`) & Check-Out Time (`18:10 PM` or `— Now`).
    - Worked Hours Badge (`9.08 hrs` in bold).
    - Status Badge: `Present` (Green), `Late` (Amber), `Absent` (Red `#EF4444`).
- **On Click & Navigation Actions**:
  - Click row $\to$ Opens `SCR_ATTENDANCE_DETAIL` for in-depth inspection and manual audit edits.
  - Click `+ NEW` $\to$ Allows HR Manager to log manual attendance entry.

---

### Screen 2.3: Attendance Record Inspector & Overtime Audit Form
- **Screen ID**: `SCR_ATTENDANCE_DETAIL`
- **Route**: `/attendance/:id`
- **Visual Design & UX**:
  - Form Fields: `Employee` (`Aarav Mehta`), `Department` (`Finance`), `Manager` (`Sara Khan`), `Check-In Datetime` (`02-Sep-2026 09:05`), `Check-Out Datetime` (`02-Sep-2026 18:10`), `Worked Hours` (`9.08`), `Overtime` (`0.50 hrs`), `Status` (`Present`).
  - Audit Notes box: *"System-generated from quick check-in widget. Verified against 40h working schedule."*
- **On Click & Navigation Actions**:
  - Click `EDIT` (HR Manager only) $\to$ Allows manual timestamp correction with mandatory audit reason.

---

## 🏖️ PHASE 3: Time Off, Allocations & Leave Policy System

```
+-------------------------------------------------------------------------------+
| FLOW 3: TIME OFF & LEAVE POLICIES                                             |
|                                                                               |
|  [Navbar: Time Off Dropdown]                                                  |
|       |-- [3.1 Time Off Requests]  ---> [3.2 Request Detail & Approval Form]  |
|       |-- [3.3 Allocations Matrix] ---> [3.4 Allocation Detail Form]          |
|       \-- [3.5 Time Off Types]     ---> [3.6 Policy & Rule Form]              |
+-------------------------------------------------------------------------------+
```

---

### Screen 3.1: Time Off Requests Master Hub
- **Screen ID**: `SCR_LEAVE_REQUESTS`
- **Route**: `/timeoff/requests`
- **Visual Design & UX**:
  - Segmented Filter Tabs: `All Requests`, `My Team`, `To Approve` (with badge counter 🔴 `3`), `Approved`, `Refused`.
  - Request Card:
    - Employee Avatar & Name (`Aarav Mehta`, `Sara Khan`, `John Dsouza`).
    - Leave Type Pill with custom color: `Paid Time Off` (Blue), `Sick Leave` (Orange), `Comp Off` (Purple).
    - Date Span: `12-Sep → 14-Sep` (`3 Days`).
    - Reason snippet: *"Family vacation"*.
    - Status Badge: `To Approve` (Amber), `Approved` (Emerald), `Refused` (Crimson).
    - **Inline Quick Manager Actions (Swipe or Buttons)**: `[ Approve ✓ ]` & `[ Refuse ✕ ]`.
- **On Click & Navigation Actions**:
  - Click `Approve ✓` $\to$ Deducts balance from allocated days, marks status `Approved`, fires push notification.
  - Click `Refuse ✕` $\to$ Prompts refuse reason dialog, updates status to `Refused`.
  - Click Request Card $\to$ Opens full detail view `SCR_LEAVE_REQUEST_DETAIL`.
  - Click `+ NEW` $\to$ Opens leave request modal creator.

---

### Screen 3.2: Time Off Request Creator & Detail View
- **Screen ID**: `SCR_LEAVE_REQUEST_DETAIL`
- **Route**: `/timeoff/requests/:id`
- **Visual Design & UX**:
  - Employee selector + Time Off Type dropdown (`Paid Time Off`).
  - Real-time Balance Checker Banner: *"Available Balance: 12 Days remaining. This request consumes 3 Days."*
  - Date Range Picker with interactive calendar: Start Date (`12-Sep-2026`) to End Date (`14-Sep-2026`).
  - Total Duration: Auto-computed excluding weekends based on Employee's working schedule (`3 Days`).
  - Approver: (`Sara Khan`).
  - Reason / Description: Multi-line text field.
- **On Click & Navigation Actions**:
  - Submitting checks whether the requested leave type requires allocation and prevents submission if remaining balance < requested days.

---

### Screen 3.3: Leave Allocations Matrix (Balance Math Hub)
- **Screen ID**: `SCR_LEAVE_ALLOCATIONS`
- **Route**: `/timeoff/allocations`
- **Visual Design & UX**:
  - Visual Leave Balance Math Card for each employee:
    - Employee Name (`Aarav Mehta`, `Sara Khan`, `Neha Patel`).
    - Leave Type (`Paid Time Off`, `Comp Off`).
    - Math Gauge Bar: **Allocated (20 Days)** = **Taken (8 Days)** + **Remaining (12 Days)**.
    - Status: `Approved` / `To Approve`.
- **On Click & Navigation Actions**:
  - Click any Allocation Card $\to$ Opens `SCR_ALLOCATION_DETAIL` (`/timeoff/allocations/:id`).
  - Click `+ NEW` $\to$ HR Manager grants new leave allocation balance.

---

### Screen 3.4: Leave Allocation Form & Validity Assignor
- **Screen ID**: `SCR_ALLOCATION_DETAIL`
- **Route**: `/timeoff/allocations/:id`
- **Visual Design & UX**:
  - Form Fields: `Employee *` (`Aarav Mehta`), `Time Off Type *` (`Paid Time Off`), `Allocated Days *` (`20 Days`), `Validity Period` (`2026 Annual Balance`), `Approver` (`Sara Khan`), `Status` (`Approved` / `To Approve`), `Description` (*"Annual leave balance granted at start of policy year"*).
- **On Click & Navigation Actions**:
  - Manager clicks `Approve` $\to$ Credits the balance to employee's profile.

---

### Screen 3.5: Time Off Types Configuration List
- **Screen ID**: `SCR_LEAVE_TYPES_LIST`
- **Route**: `/timeoff/types`
- **Visual Design & UX**:
  - Configuration List Cards:
    - `Paid Time Off` (Unit: `Days`, Allocation: `Required`, Approval: `Manager`, Color: `Blue`, Status: `Active`).
    - `Sick Leave` (Unit: `Days`, Allocation: `No`, Approval: `Manager`, Color: `Red`, Status: `Active`).
    - `Comp Off` (Unit: `Hours`, Allocation: `Required`, Approval: `Officer`, Color: `Purple`, Status: `Active`).
- **On Click & Navigation Actions**:
  - Click type $\to$ Opens `SCR_LEAVE_TYPE_DETAIL` for rule editing.

---

### Screen 3.6: Time Off Type Policy Form
- **Screen ID**: `SCR_LEAVE_TYPE_DETAIL`
- **Route**: `/timeoff/types/:id`
- **Visual Design & UX**:
  - Fields: `Type Name` (`Paid Time Off`), `Take Time Off in` (`Days` / `Hours`), `Requires Allocation` (`Yes` / `No` switch), `Approval Level` (`Manager` / `HR Officer` / `No Validation`), `Payroll / Work Entry Type` (`Leave Work Entry`), `Display Color Picker` (`Blue`), `Active` toggle.
  - Policy helper note: *"Time Off Type drives approval behavior and whether a request consumes an approved allocation."*

---

## 💰 PHASE 4: High-Performance Payroll & Payrun Engine

```
+-------------------------------------------------------------------------------+
| FLOW 4: PAYRUN & PAYSLIP EXECUTION PIPELINE                                   |
|                                                                               |
|  [4.1 New Payrun Wizard] (2-Step Bottom Sheet)                                |
|       Step 1: Scope (Structure + Period) ---> Step 2: Multi-Employee Select   |
|                                                      |                        |
|                                                      v                        |
|  [4.2 Payruns Directory] <================== [Payrun Created]                 |
|          |                                                                    |
|          v                                                                    |
|  [4.3 Payrun Command Center]                                                  |
|       - Actions: [COMPUTE] -> [VALIDATE] -> [MARK PAID] -> [SEND PAYSLIPS]    |
|       - Anomaly / Warning Badges (Missing A/C, Duplicate slips)               |
|       - Embedded Payslips Table                                               |
|          |                                                                    |
|          v                                                                    |
|  [4.5 Payslip Breakdown Form] ---> [4.6 In-App PDF Preview & Share]           |
+-------------------------------------------------------------------------------+
```

---

### Screen 4.1: 2-Step Payrun Creation Wizard
- **Screen ID**: `SCR_PAYRUN_CREATE_WIZARD`
- **Component**: Wolt Modal Sheet / Full-Screen Stepper
- **Visual Design & UX**:
  - **Step 1: Payroll Scope Definition**:
    - Header: *"Step 1: Select Payrun Scope"*
    - Pay Structure Selector Dropdown: (`United States: Regular Pay`, `India: Regular Salary`).
    - Period Range Picker: (`Sep 1, 2026 → Sep 30, 2026`).
    - Note Banner: *"This step collects scope only. Payrun is created after selecting employees."*
    - Action Buttons: `[ Continue → ]` (Primary Aubergine), `[ Discard ]`.
  - **Step 2: Employee Multi-Select Ledger**:
    - Header: *"Step 2: Select Employee Records (1–22 of 22)"*
    - Top Search & Select All Checkbox (`Select All (22)`).
    - Employee Row with Checkbox:
      - Checkbox `[✓]`, Employee Name (`Anita Oliver`, `Audrey Peterson`, `Billy Kyle`, `Eli Lambert`, `Paul Williams`), Working Hours (`40h/wk`), Start Date (`Jan 1`), Wage (`$4,500.00`).
    - Bottom Summary Bar: Shows count of selected employees (e.g. `22 Employees Selected • Total Est. Wage: $92,400`).
    - Action Buttons: `[ Create Payrun ✓ ]` (Teal Fill), `[ ← Back ]`.
- **On Click & Navigation Actions**:
  - Click `Continue` on Step 1 $\to$ Transitions smoothly to Step 2 with slide animation.
  - Click `Create Payrun` on Step 2 $\to$ Generates Payrun object and links individual Draft Payslips for each selected employee $\to$ Navigates to `SCR_PAYRUN_DETAIL`.

---

### Screen 4.2: Payruns Period Master Hub
- **Screen ID**: `SCR_PAYRUNS_LIST`
- **Route**: `/payroll/payruns`
- **Visual Design & UX**:
  - Year Filter (`2026`), Search bar.
  - Payrun Card:
    - Month / Title in bold: `February 2026`, `January 2026`, `March 2026`.
    - Date Span: `01-Feb-2026 → 28-Feb-2026`.
    - Employee Count Badge: `42 employees`.
    - **Payroll Warning Pill**:
      - `2 warnings` (Amber `#F59E0B` with ⚠️ icon for missing bank accounts or duplicates).
      - `No warnings` (Green `#10B981` with ✓ icon).
    - State Badge: `Draft` (Slate), `Validated` (Blue), `Paid` (Emerald Green).
- **On Click & Navigation Actions**:
  - Click Payrun Card $\to$ Opens `SCR_PAYRUN_DETAIL` (`/payroll/payruns/:id`).
  - Click `+ NEW` $\to$ Launches `SCR_PAYRUN_CREATE_WIZARD`.

---

### Screen 4.3: Payrun Command Center & Batch Payslip Manager
- **Screen ID**: `SCR_PAYRUN_DETAIL`
- **Route**: `/payroll/payruns/:id`
- **Visual Design & UX**:
  - Top Breadcrumb & Status Pill: `Payrun / February 2026` • `[ Validated ]`.
  - Summary Header Grid: Structure (`Regular Salary`), Period (`01-Feb — 28-Feb`), Total Employees (`42`), Net Total (`₹18,40,000`).
  - **Action Pipeline Toolbar**:
    - ⚡ `[ COMPUTE ]` (Aubergine fill: Recalculates all draft payslips using salary rules).
    - 🛡️ `[ VALIDATE ]` (Blue fill: Validates calculations and locks records).
    - 💵 `[ MARK PAID ]` (Green fill: Marks all slips paid and updates journal status).
    - 📤 `[ SEND PAYSLIPS ]` (Teal outline: Batch emails PDF payslips to all employees).
  - **Embedded Payslips Table / Card List**:
    - Columns / Row items:
      - Employee Name (`Aarav Mehta`, `Sara Khan`, `John Dsouza`).
      - Warning Indicator (`—`, `⚠️ A/C missing`, `⚠️ Duplicate`).
      - Worked Days (`22 days`).
      - Basic (`₹50k`), Gross (`₹80k`), Net (`₹75k`).
      - Status (`Draft`, `Done`, `Paid`).
      - PDF Icon (`[ 📄 PDF ]`).
- **On Click & Navigation Actions**:
  - Click on any Employee Payslip row $\to$ Navigates to `SCR_PAYSLIP_DETAIL` (`/payroll/payslips/:id`).
  - Click `📄 PDF` icon on any row $\to$ Opens `SCR_PAYSLIP_PDF_VIEWER` directly.
  - Click `COMPUTE` $\to$ Triggers loading animation across all slip rows and updates totals.

---

### Screen 4.4: Payslips Master List & Warning Inspector
- **Screen ID**: `SCR_PAYSLIPS_LIST`
- **Route**: `/payroll/payslips`
- **Visual Design & UX**:
  - Filters: `Period: Feb 2026`, `Status: All`, `Has Warnings Only`.
  - Search by employee name or payslip code.
  - Payslip Card showing: Employee Avatar, Name, Structure, Basic, Gross, Net, Warning Badge, and Status.
- **On Click & Navigation Actions**:
  - Click row $\to$ Opens `SCR_PAYSLIP_DETAIL`.

---

### Screen 4.5: Employee Payslip Computation & Salary Breakdown Form
- **Screen ID**: `SCR_PAYSLIP_DETAIL`
- **Route**: `/payroll/payslips/:id`
- **Visual Design & UX**:
  - Header: `Payslip / Aarav Mehta / February 2026` (`01-Feb — 28-Feb`).
  - Meta Cards: `Worked Days: 22`, `Contract Wage: ₹85,000`, `Status: Done`.
  - **Salary Computation Tree Breakdown (Odoo Engine)**:
    - Table Columns: `Rule Name`, `Category`, `Amount`, `Code`.
    - Line Items:
      - 🟢 `Basic Salary` | `Basic` | `+ ₹50,000` | `BASIC`
      - 🟢 `House Rent Allowance` | `Allowance` | `+ ₹20,000` | `HRA`
      - 🟢 `Standard Allowance` | `Allowance` | `+ ₹10,000` | `STD`
      - 🔵 **`Gross Salary`** | **`Gross`** | **`₹80,000`** | `GROSS`
      - 🔴 `Provident Fund` | `Deduction` | `- ₹3,000` | `PF`
      - 🔴 `Professional Tax` | `Deduction` | `- ₹2,000` | `PT`
      - 🟢 **`Net Salary`** | **`Net`** | **`₹75,000`** | `NET`
  - Action Toolbar: `[ COMPUTE ]` | `[ MARK PAID ]` | `[ 🖨️ PRINT PAYSLIP ]`.
- **On Click & Navigation Actions**:
  - Click `PRINT PAYSLIP` $\to$ Generates PDF and navigates to `SCR_PAYSLIP_PDF_VIEWER`.
  - Click `COMPUTE` $\to$ Re-executes the Salary Rule sequence for this employee.

---

### Screen 4.6: In-App Interactive PDF Payslip Viewer & Share
- **Screen ID**: `SCR_PAYSLIP_PDF_VIEWER`
- **Route**: `/payroll/payslips/:id/pdf`
- **Visual Design & UX**:
  - High-resolution Flutter `PdfPreview` widget rendering official company payslip layout:
    - Company Logo + Header (`OXP Pvt Ltd - Employee Payslip`).
    - Employee Details Grid (Name, ID, Department, Designation, Bank A/C, PF No).
    - Earnings & Deductions 2-Column Table with clean borders.
    - Net Pay in words (*"Rupees Seventy Five Thousand Only"*).
    - Authorized Signature watermark.
  - Floating Action Bar: `[ 📥 Download PDF ]`, `[ 🖨️ Print Thermal/A4 ]`, `[ 📤 Share via WhatsApp / Email ]`.

---

## ⚙️ PHASE 5: Salary Structures, Rules & Python Formula Engine

```
+-------------------------------------------------------------------------------+
| FLOW 5: SALARY STRUCTURES & PYTHON RULES                                      |
|                                                                               |
|  [5.1 Salary Structures List] ---> [5.2 Structure Detail & Rule Sequence Form]|
|                                                   |                           |
|                                                   v                           |
|  [5.3 Salary Rules Directory] ---> [5.4 Rule Builder & Python Syntax Editor]  |
|                                         - Fixed Amount                        |
|                                         - % of Base (Wage/Gross/Basic)        |
|                                         - Python Code Expression Engine       |
+-------------------------------------------------------------------------------+
```

---

### Screen 5.1: Salary Structures Master Directory
- **Screen ID**: `SCR_SALARY_STRUCTURES_LIST`
- **Route**: `/payroll/structures`
- **Visual Design & UX**:
  - List of configured Salary Structures:
    - `Regular Salary` (`12 rules`, `42 employees assigned`, `Active`).
    - `Intern Salary` (`8 rules`, `6 employees assigned`, `Active`).
    - `Contractor Structure` (`6 rules`, `9 employees assigned`, `Active`).
- **On Click & Navigation Actions**:
  - Click Structure $\to$ Opens `SCR_SALARY_STRUCTURE_DETAIL` (`/payroll/structures/:id`).
  - Click `+ NEW` $\to$ Creates a new salary structure.

---

### Screen 5.2: Salary Structure Detail & Ordered Rule Sequencing Form
- **Screen ID**: `SCR_SALARY_STRUCTURE_DETAIL`
- **Route**: `/payroll/structures/:id`
- **Visual Design & UX**:
  - Fields: `Structure Name` (`Regular Salary`), `Active` (Toggle: `True`).
  - **Ordered Salary Rules Table**:
    - Columns: `Sequence`, `Rule Name`, `Code`, `Category`, `Actions`.
    - Drag-and-drop handles (`ReorderableListView`) to change calculation sequence.
    - Rule list:
      1. `Seq 1`: `Basic Salary` (`BASIC` - `Basic`)
      2. `Seq 10`: `House Rent Allowance` (`HRA` - `Allowance`)
      3. `Seq 20`: `Standard Allowance` (`STD` - `Allowance`)
      4. `Seq 30`: `Performance Bonus` (`BONUS` - `Allowance`)
      5. `Seq 40`: `Leave Travel Allowance` (`LTA` - `Allowance`)
      6. `Seq 50`: `Fixed Allowance` (`FIX` - `Allowance`)
      7. `Seq 60`: `Gross Salary` (`GROSS` - `Gross`)
      8. `Seq 70`: `LWF Fund` (`LWF` - `Deduction`)
      9. `Seq 80`: `Provident Fund` (`PF` - `Deduction`)
      10. `Seq 90`: `ESIC` (`ESIC` - `Deduction`)
      11. `Seq 100`: `Professional Tax` (`PT` - `Deduction`)
      12. `Seq 110`: `Net Salary` (`NET` - `Net`)
  - `+ Add Rule to Structure` button.
- **On Click & Navigation Actions**:
  - Dragging rule row updates calculation sequence in database in real time.
  - Click rule row $\to$ Opens rule builder `SCR_SALARY_RULE_DETAIL`.

---

### Screen 5.3: Salary Rules Master Registry
- **Screen ID**: `SCR_SALARY_RULES_LIST`
- **Route**: `/payroll/rules`
- **Visual Design & UX**:
  - Search by rule code or name. Filter by Category (`Basic`, `Allowance`, `Gross`, `Deduction`, `Net`).
  - Rules list displaying Name, Code, Category, Structure, and Sequence.

---

### Screen 5.4: Salary Rule Builder & Python Code Syntax Editor
- **Screen ID**: `SCR_SALARY_RULE_DETAIL`
- **Route**: `/payroll/rules/:id`
- **Visual Design & UX**:
  - Top Fields: `Rule Name` (`Basic Salary`), `Code` (`BASIC`), `Category` (`Basic`), `Salary Structure` (`Regular Salary`), `Sequence` (`1`), `Active` (`True`).
  - **Computation Type Selector (Radio Pills)**:
    - `[ 1. Fixed Amount ]`
    - `[ 2. Percentage of Wage / Base ]`
    - `[ 3. Python Code / Formula ]`
  - **Dynamic Configuration Form depending on Selection**:
    - If `Percentage`: Base Dropdown (`Contract Wage` / `Gross` / `Basic`) + Percentage Input (`50%`).
    - If `Fixed Amount`: Currency input (`₹2,000`).
    - If `Python Code`:
      - Code Editor Box with JetBrains Mono font, dark syntax theme (`flutter_highlight`):
        ```python
        # Python Salary Rule Formula
        # Available vars: contract, payslip, categories, rules, worked_days
        result = contract.wage * 0.50
        if worked_days['WORK100'].number_of_days < 20:
            result = (contract.wage / 22) * worked_days['WORK100'].number_of_days
        ```
      - Quick Insert Token chips: `contract.wage`, `categories['BASIC']`, `worked_days`, `rules['HRA']`.
      - Real-Time "Test Formula" Sandbox button with instant calculation preview.
- **On Click & Navigation Actions**:
  - Click `Test Expression` $\to$ Runs mock compilation and displays simulated output value.
  - Click `Save Rule` $\to$ Validates Python syntax and persists rule.

---

## 📊 PHASE 6: Executive HR & Payroll Analytics Command Center

```
+-------------------------------------------------------------------------------+
| FLOW 6: EXECUTIVE PAYROLL & HR ANALYTICS DASHBOARD                            |
|                                                                               |
|  [Global Filters Bar: Period | Department | Employee Type | Company]          |
|                                                                               |
|  [6.1 Executive 5-KPI Ribbon]                                                 |
|   - Net Paid (₹18.4L)  - Payslips (148)  - Avg Salary (₹12,432)               |
|   - Time Off (34 Days) - Attendance Health (94%)                              |
|                                                                               |
|  [6.2 Department Cost Bars] <---------> [6.3 6-Month Salary Spline Trend]    |
|                                                                               |
|  [6.4 Payslip Status Donut & Anomaly Alerts Feed (Missing A/C, Expiring)]    |
|                                                                               |
|  [6.5 Attendance & Leave Split] <-----> [6.6 Department Aggregate Table]     |
+-------------------------------------------------------------------------------+
```

---

### Screen 6.1: Executive Command Dashboard (All-in-One View)
- **Screen ID**: `SCR_DASHBOARD_MAIN`
- **Route**: `/dashboard`
- **Visual Design & UX**:
  - **Top Global Filter Bar (Horizontal Sticky Bar)**:
    - `Period`: Dropdown (`Sep 2026`).
    - `Department`: Dropdown (`All Departments`, `Finance`, `IT`, `Sales`, `HR`, `Support`).
    - `Employee Type`: Dropdown (`All Types`, `Full-time`, `Contractor`).
    - `Company`: (`OXP Pvt Ltd`).
  - **Section 1: 5-Metric Executive KPI Ribbon**:
    1. 💳 **Total Net Salary Paid**: `₹ 18.4L` (Subtext: `+8.5% vs previous month` in green with ↗️ arrow).
    2. 📄 **Payslips Generated**: `148` (Subtext: `142 paid, 6 pending`).
    3. ⚖️ **Avg Salary / Employee**: `₹ 12,432` (Subtext: `Based on current payrun`).
    4. 🏖️ **Approved Time Off Days**: `34 Days` (Subtext: `Across selected period`).
    5. 🛡️ **Attendance Health**: `94%` (Subtext: `Present / reviewed records`).

  - **Section 2: Interactive Charts Row (`fl_chart`)**:
    - **Chart A: Salary Cost by Department (Bar Chart)**:
      - Interactive touch bars: `IT (₹170k)`, `Sales (₹150k)`, `Finance (₹130k)`, `Support (₹110k)`, `HR (₹90k)`.
      - Touch tooltip showing exact department headcount and wage sum.
    - **Chart B: Monthly Net Salary Trend (Spline Area Chart)**:
      - 6-Month smooth gradient line chart (`Apr: 14.8L`, `May: 15.2L`, `Jun: 14.3L`, `Jul: 15.0L`, `Aug: 17.1L`, `Sep: 18.4L`).
      - Gradient fill under curve with touch cursor indicator.

  - **Section 3: Payslip Status Donut & Payroll Alerts Feed**:
    - **Left: Payslip Status Donut Chart**:
      - Colored segments: `Paid (142)`, `Done (4)`, `Pending (2)`.
    - **Right: Real-Time Payroll Anomaly Alerts Card**:
      - ⚠️ `2 employees missing bank account` (Click to open filtered employee list).
      - ⚠️ `1 duplicate payslip warning` (Click to resolve duplicate).
      - ⚠️ `4 draft payslips still not validated` (Click to validate).
      - ⚠️ `3 contracts expiring this month` (Click to open contracts).

  - **Section 4: Attendance & Time Off Overview Cards**:
    - **Left: Attendance Health Overview**:
      - Progress gauges: `Present (94)`, `Late (18)`, `Absent (9)`, `Overtime (22)`.
      - Issue pill counter: `Missing check-outs: 5` | `Manual edits: 7`.
    - **Right: Time Off Breakdown**:
      - `Paid Time Off`: `24 Approved` | `3 Pending` | `118 Days Balance`.
      - `Sick Leave`: `6 Approved` | `1 Pending` | `N/A`.
      - `Comp Off`: `4 Approved` | `2 Pending` | `11 Days Balance`.

  - **Section 5: Department Cross-Model Summary Table**:
    - Columns: `Department`, `Headcount`, `Monthly Salary Total`.
    - Rows: `IT (18 employees - ₹4.2L)`, `Sales (22 employees - ₹5.7L)`, `HR (8 employees - ₹1.9L)`, `Support (14 employees - ₹3.1L)`.

- **On Click & Navigation Actions**:
  - Changing any Filter in top bar instantly updates all 5 metrics, both charts, the alert feed, and the table dynamically without page reload.
  - Clicking any alert chip navigates directly to the offending records.

---

## 🤖 PHASE 7: AI HR & Payroll Copilot (Local RAG — Signature Differentiator)

```
+-------------------------------------------------------------------------------+
| FLOW 7: AI HR COPILOT (HYBRID RAG)                                            |
|                                                                               |
|  [Global Floating Copilot FAB on every screen]                               |
|       |                                                                       |
|       v                                                                       |
|  [7.1 Copilot Chat Drawer]                                                    |
|     - Suggested starter chips                                                 |
|     - Streamed answers with source citations                                  |
|     - Hybrid routing: personal SQL data + policy vector search                |
|          |                                                                    |
|          +--> Personal data intent  ---> scoped SQL (self employee_id only)   |
|          \--> Policy / rules intent  ---> pgvector cosine search over docs     |
+-------------------------------------------------------------------------------+
```

This phase consumes the backend `POST /api/v1/ai/assistant` endpoint (see `BACKEND_PRODUCTION_ARCHITECTURE.md` §4). The Flutter side is a thin, beautiful conversational client — **no model runs on-device and no API key ever ships in the app**. Embedding and retrieval happen locally on the server against PostgreSQL + `pgvector`; answer phrasing is delegated server-side to a pluggable provider (§4.2).

> **Client contract**: the app is completely unaware of which LLM provider is active. It only reads `mode` (`ANSWERED` / `ESCALATED`), `answer`, `confidence`, and `citations`. Switching Groq → Gemini → offline extractive mode requires **zero Flutter changes**.

### The Escalation Loop (Screens 7.2 – 7.4)
When the assistant cannot answer confidently it **does not guess**. It opens a ticket, routes it to the right Admin/HR responder, the human replies directly, and the employee is notified in-app. The verified answer is then indexed so the bot answers it itself next time.

```
+-------------------------------------------------------------------------------+
| FLOW 7B: HUMAN-IN-THE-LOOP ESCALATION                                         |
|                                                                               |
|  [7.1 Copilot Chat]                                                           |
|      | confidence < 0.45  OR  user taps "Ask HR instead"                      |
|      v                                                                        |
|  [Escalation Card appears inline: "Forwarded to HR - ESC/2026/0001"]          |
|      |                                                                        |
|      +--> [7.3 My Questions] (employee tracks own tickets + reads replies)    |
|      |                                                                        |
|      \--> [7.2 Admin Escalation Inbox]  (badge on nav, SLA countdown)         |
|                   |                                                           |
|                   v                                                           |
|            [7.4 Answer Composer]                                              |
|              - AI draft pre-filled (edit & approve, don't retype)             |
|              - Internal notes (never shown to employee)                       |
|              - Toggle: "Publish to Knowledge Base"                            |
|                   |                                                           |
|                   v                                                           |
|            Employee notified -> bot learns the answer                         |
+-------------------------------------------------------------------------------+
```

---

### Screen 7.1: AI HR & Payroll Copilot Chat Drawer
- **Screen ID**: `SCR_AI_COPILOT`
- **Route**: `/copilot` (Global floating FAB + Wolt Modal Sheet / right-side drawer)
- **Role Visibility**: All Authenticated (answers are always scoped to the caller's own `employee_id`)
- **Visual Design & UX**:
  - Persistent gradient Copilot FAB (Aubergine→Teal) bottom-right on every screen with a subtle breathing glow.
  - Drawer header: **PeoplePay360 AI Assistant**, subtitle *"Grounded in your HR knowledge base"* with a green active-node dot.
  - **Suggested starter chips** (shown on empty state):
    - `"How many PTO days do I have left?"`
    - `"Explain the deductions on my February payslip"`
    - `"What is the sick leave medical certificate policy?"`
  - **Message thread**:
    - User bubbles right-aligned (Aubergine tint).
    - AI bubbles left-aligned, rendered with `flutter_markdown` (bold, lists, inline amounts).
    - **Source citation chip** under each AI answer, e.g. `Source: Regular Salary Rule Engine` or `Policy: Leave Handbook §3.2`.
    - Typing indicator with three-dot shimmer while the endpoint responds.
  - **Input bar**: pill text field *"Ask anything about HR policy, salary, or leave…"* with mic icon and Aubergine send button.
  - **Two response modes must be rendered differently** (the API returns `mode`):
    - `mode: ANSWERED` $\to$ normal markdown bubble + citation chip + a subtle footer link *"Not what you needed? Ask HR"*.
    - `mode: ESCALATED` $\to$ render an **Escalation Card** instead of a normal answer:
      - Amber-tinted card, 🙋 icon, headline *"Forwarded to your HR team"*.
      - Ticket chip: `ESC/2026/0001` (monospace) + category pill (`Leave Policy`).
      - Body: *"I don't have a verified answer for that, so I've sent it to HR. You'll be notified as soon as they reply."*
      - SLA line: *"Expected reply within 8 hours"* with a live countdown.
      - Action: `[ Track this question → ]` opening Screen 7.3.
    - When the backend short-circuits via semantic dedup, render a normal answer bubble with a **teal "Human verified" badge** and *"Previously answered by HR (ESC/2026/0007)"*.
- **On Click & Navigation Actions**:
  - Tap starter chip $\to$ pre-fills and sends the question.
  - Tap send $\to$ `POST /api/v1/ai/assistant { prompt }`; JWT identifies the employee, so personal-data answers never leak across users.
  - Tap a source citation chip $\to$ deep-links to the underlying record (e.g. the specific payslip or the policy document viewer).
  - Tap **"Ask HR instead"** on any answer $\to$ `POST /api/v1/ai/escalations { prompt }` and swap the bubble for an Escalation Card.
- **Production Edge Cases**:
  - Offline / endpoint error: show a graceful retry card, never a raw stack trace.
  - Empty knowledge base: assistant answers personal-data questions from SQL and clearly states no policy docs are indexed yet.
  - Anti-spam: if the API returns the open-ticket cap error, show a friendly inline notice (*"You already have 5 open questions with HR"*) rather than a generic failure.
  - Guardrail: the client sends only the prompt; it never sends another user's `employee_id`. Scope enforcement lives server-side.

---

### Screen 7.2: Admin / HR Escalation Inbox (Responder Queue)
- **Screen ID**: `SCR_ESCALATION_INBOX`
- **Route**: `/copilot/escalations`
- **Role Visibility**: `HR Manager`, `HR Payroll Manager`, `Admin` only (hidden from `Employee` nav entirely)
- **Visual Design & UX**:
  - AppBar: **Escalation Inbox** with an unread badge fed by `GET /api/v1/notifications`.
  - **Queue KPI strip** (from `/escalations/stats`): `Open (7)` · `Overdue (2)` in red · `Median first reply: 3.2h` · `KB articles created: 14`.
  - Filter chips: `[ All ] [ Unassigned ] [ Mine ] [ Overdue ⏰ ] [ Answered ]` plus a category dropdown.
  - **Ticket cards**, sorted urgent-and-oldest first:
    - Ticket no in mono (`ESC/2026/0001`) + priority stripe down the left edge (Urgent = crimson, High = amber, Normal = slate).
    - Question text, two lines, ellipsised.
    - Asker row: avatar + `Aarav Mehta • Finance`.
    - Category pill (`Leave Policy` blue / `Payroll & Salary` teal / `Tax & Statutory` purple).
    - **Confidence badge**: *"AI confidence 0.31"* — shows judges the gate is real and measured.
    - **SLA countdown chip**: `Due in 5h 12m` (amber under 2h, crimson red once breached).
    - Status pill: `Open` / `Assigned` / `Answered`.
- **On Click & Navigation Actions**:
  - Tap card $\to$ `SCR_ESCALATION_ANSWER` (7.4).
  - Swipe right $\to$ `Assign to me` (`POST /escalations/:id/assign`), card animates into the `Mine` filter.
  - Swipe left $\to$ `Reject` (Admin only) with a reason prompt.
  - Pull-to-refresh re-polls the queue.

---

### Screen 7.3: My Questions (Employee Ticket Tracker)
- **Screen ID**: `SCR_MY_ESCALATIONS`
- **Route**: `/copilot/my-questions`
- **Role Visibility**: All Authenticated — **always scoped to own tickets by the server**
- **Visual Design & UX**:
  - Segmented tabs: `[ Waiting on HR ] [ Answered ]` with a dot indicator on unread replies.
  - Ticket cards: question text, ticket no, submitted-ago timestamp, status pill, and expected-reply countdown while pending.
  - **Answered cards expand inline** to reveal:
    - The HR answer rendered as markdown.
    - Responder attribution: avatar + *"Answered by Sara Khan, HR Manager"* + timestamp.
    - A teal **"Human verified"** badge.
    - Feedback row: `[ 👍 This helped ]` `[ 👎 Still unclear ]` → posts close or reopen.
- **On Click & Navigation Actions**:
  - Tap `👍 This helped` $\to$ `POST /escalations/:id/close`, card collapses with a success check.
  - Tap `👎 Still unclear` $\to$ `POST /escalations/:id/reopen` with an optional note.
  - Tapping a notification for an answered ticket deep-links straight into this screen with that card pre-expanded.
- **Production Edge Cases**:
  - `INTERNAL` thread events must never render here. The API strips them, and the client must not assume otherwise.

---

### Screen 7.4: Answer Composer (Admin Replies Directly)
- **Screen ID**: `SCR_ESCALATION_ANSWER`
- **Route**: `/copilot/escalations/:id`
- **Role Visibility**: Responder roles only
- **Visual Design & UX**:
  - Header: ticket no, priority stripe, SLA countdown, status pill, `Assign to me` action if unassigned.
  - **Context panel (collapsible)** so the responder answers with full context, not blind:
    - The employee's original question, verbatim, in a quoted block.
    - Asker identity card: name, department, job position, manager — tappable through to the Employee 360 form.
    - *Why this escalated*: reason chip (`Low confidence`) + measured score (`0.31`) + the weak chunks that were retrieved.
  - **AI Draft Answer block (the time-saver)**:
    - Pre-filled with `ai_draft_answer` in a dashed-border card labelled *"AI draft — unverified, edit before sending"*.
    - Buttons: `[ Use this draft ]` (copies into the editor) and `[ Discard draft ]`.
  - **Answer editor**: multiline markdown field with a live preview toggle and a character counter.
  - **Internal note field**, clearly separated with a lock icon and the caption *"Only Admin/HR can see this. The employee will never see internal notes."*
  - **Knowledge Base toggle (Stage 4 of the loop)**:
    - Switch, default ON: *"Publish this answer to the Knowledge Base"*.
    - Helper text: *"The assistant will answer this question automatically next time. Turn this off for answers specific to one person."*
  - **Threaded event timeline** at the bottom: created → assigned → commented → answered, with actor avatars and timestamps. `INTERNAL` events carry a lock badge.
- **On Click & Navigation Actions**:
  - `[ Send Answer to Employee ]` (solid Aubergine) $\to$ `POST /escalations/:id/answer { answer_text, publish_to_kb }`.
    - Success state is the demo money shot: a toast reading *"Answer sent to Aarav Mehta • Indexed to Knowledge Base"* plus a small animated flywheel icon.
  - `[ Add Internal Note ]` $\to$ `POST /escalations/:id/comment`.
  - `[ Reject Ticket ]` (Admin only) $\to$ confirmation dialog, then `POST /escalations/:id/reject`.
- **Validation & Guardrails**:
  - `Send Answer` is disabled until the editor holds meaningful content (trimmed length > 10) — no empty replies.
  - Optimistic-lock handling: if another responder answered first, show *"Already answered by Nisha Rao"* and refresh rather than overwriting.
  - Never render an `Answer` action for a ticket in `CLOSED` or `REJECTED` state.

---

## 🏗️ FLUTTER PROJECT DIRECTORY STRUCTURE

To guarantee clean architecture, separation of concerns, and production standards:

```text
lib/
├── core/
│   ├── constants/
│   │   ├── app_colors.dart         # Odoo Aubergine, Teal, HSL semantic tokens
│   │   ├── app_theme.dart          # Light & Dark ThemeData with Glassmorphism
│   │   └── app_typography.dart     # Plus Jakarta Sans text styles
│   ├── navigation/
│   │   ├── app_router.dart         # GoRouter definitions for all 20+ screens
│   │   └── route_guards.dart       # RBAC Role access guard checks
│   ├── network/
│   │   └── api_client.dart         # HTTP / Supabase / Odoo XML-RPC Client
│   └── utils/
│       ├── currency_formatter.dart # ₹ Lakhs & $ currency formatting
│       └── date_utils.dart         # ISO8601 to human Odoo dates
├── features/
│   ├── auth/                       # Phase 0: Auth & User Management
│   │   ├── domain/models/user_model.dart
│   │   ├── presentation/controllers/auth_controller.dart
│   │   └── presentation/screens/login_screen.dart
│   ├── employees/                  # Phase 1: Employees & Contracts
│   │   ├── domain/models/employee_model.dart
│   │   ├── domain/models/contract_model.dart
│   │   ├── domain/models/schedule_model.dart
│   │   └── presentation/screens/
│   │       ├── employee_hub_screen.dart
│   │       ├── employee_form_screen.dart
│   │       ├── schedule_builder_screen.dart
│   │       └── contract_form_screen.dart
│   ├── attendance/                 # Phase 2: Attendance & Punch
│   │   ├── domain/models/attendance_model.dart
│   │   ├── presentation/controllers/attendance_timer_controller.dart
│   │   ├── presentation/widgets/floating_punch_pill.dart
│   │   └── presentation/screens/attendance_list_screen.dart
│   ├── time_off/                   # Phase 3: Leaves & Allocations
│   │   ├── domain/models/leave_request_model.dart
│   │   ├── domain/models/allocation_model.dart
│   │   ├── domain/models/leave_type_model.dart
│   │   └── presentation/screens/
│   │       ├── leave_requests_screen.dart
│   │       ├── allocations_matrix_screen.dart
│   │       └── leave_types_screen.dart
│   ├── payroll/                    # Phase 4 & 5: Payrun, Payslips, Rules
│   │   ├── domain/models/payrun_model.dart
│   │   ├── domain/models/payslip_model.dart
│   │   ├── domain/models/salary_structure_model.dart
│   │   ├── domain/models/salary_rule_model.dart
│   │   ├── domain/engine/salary_computation_engine.dart # Python/Rule Evaluator
│   │   └── presentation/screens/
│   │       ├── payruns_list_screen.dart
│   │       ├── payrun_command_center_screen.dart
│   │       ├── payrun_wizard_sheet.dart
│   │       ├── payslip_detail_screen.dart
│   │       ├── payslip_pdf_viewer_screen.dart
│   │       ├── salary_structures_screen.dart
│   │       └── salary_rule_editor_screen.dart
│   ├── dashboard/                  # Phase 6: Executive Analytics
│   │   ├── presentation/controllers/dashboard_analytics_controller.dart
│   │   ├── presentation/widgets/
│   │   │   ├── kpi_metric_ribbon.dart
│   │   │   ├── department_cost_bar_chart.dart
│   │   │   ├── monthly_salary_trend_chart.dart
│   │   │   ├── payslip_status_donut_chart.dart
│   │   │   └── payroll_alerts_card.dart
│   │   └── presentation/screens/executive_dashboard_screen.dart
│   ├── copilot/                    # Phase 7: AI HR Copilot (Local RAG client)
│   │   ├── domain/models/
│   │   │   ├── chat_message_model.dart
│   │   │   ├── copilot_response_model.dart   # freezed union: Answered | Escalated
│   │   │   └── escalation_model.dart         # ticket + threaded events + SLA
│   │   ├── presentation/controllers/
│   │   │   ├── copilot_controller.dart       # POST /api/v1/ai/assistant
│   │   │   └── escalation_controller.dart    # list / assign / answer / close
│   │   ├── presentation/widgets/
│   │   │   ├── copilot_fab.dart              # global floating launcher
│   │   │   ├── chat_bubble.dart              # markdown answer + source chip
│   │   │   ├── escalation_card.dart          # inline "Forwarded to HR" card
│   │   │   ├── confidence_badge.dart         # shows the measured gate score
│   │   │   ├── sla_countdown_chip.dart       # amber < 2h, red once breached
│   │   │   ├── ai_draft_block.dart           # edit-and-approve draft answer
│   │   │   └── suggested_prompt_chips.dart
│   │   └── presentation/screens/
│   │       ├── copilot_drawer_screen.dart        # 7.1 chat
│   │       ├── escalation_inbox_screen.dart      # 7.2 admin queue
│   │       ├── my_escalations_screen.dart        # 7.3 employee tracker
│   │       └── escalation_answer_screen.dart     # 7.4 answer composer
│   └── notifications/              # In-app feed powering all badge counters
│       ├── domain/models/notification_model.dart
│       ├── presentation/controllers/notification_controller.dart
│       └── presentation/widgets/notification_badge.dart
└── main.dart
```

---

## 🎯 COMPLETE SCREEN-TO-SCREEN NAVIGATION MATRIX

| Trigger Element | Current Screen | Target Destination | Transition Style | Parameters Passed |
| :--- | :--- | :--- | :--- | :--- |
| `Sign In Button` | Login (`0.1`) | Executive Dashboard (`6.1`) | Fade Scale | JWT Token, Role Context |
| `+ New User` | User Directory (`0.2`) | Create User Modal (`0.3`) | Slide Bottom | Mode: Create |
| `Employee Card` | Employee Hub (`1.1`) | Employee 360 Form (`1.2`) | Hero Animation | `employeeId` |
| `Time Off [3] Button` | Employee Form (`1.2`) | Leave Requests (`3.1`) | Push | `filterEmployeeId` |
| `Contracts [2] Button` | Employee Form (`1.2`) | Contracts List (`1.5`) | Push | `filterEmployeeId` |
| `Attendance [14] Button`| Employee Form (`1.2`) | Attendance Logs (`2.2`) | Push | `filterEmployeeId` |
| `Navbar Punch Icon` | Any Screen | Quick Punch Modal (`2.1`) | Wolt Modal Sheet | Current User ID |
| `Approve Leave Button` | Leave Requests (`3.1`) | Leave Requests (`3.1`) | In-Place Update | `requestId`, `status: Approved` |
| `+ New Payrun` | Payruns Hub (`4.2`) | Payrun Wizard Sheet (`4.1`) | Modal Bottom Sheet | Initial Step: 1 |
| `Continue (Step 1)` | Payrun Wizard (`4.1`) | Payrun Wizard (Step 2) | Horizontal Slide | `structureId`, `dateRange` |
| `Create Payrun` | Payrun Wizard (`4.1`) | Payrun Command Center (`4.3`)| Push Replacement | New `payrunId` |
| `Compute All` | Payrun Command (`4.3`) | Payrun Command (`4.3`) | Shimmer Loading | `payrunId` |
| `Payslip Row Click` | Payrun Command (`4.3`) | Payslip Detail (`4.5`) | Push | `payslipId` |
| `Print Payslip Button` | Payslip Detail (`4.5`) | PDF Viewer Screen (`4.6`) | Push | `payslipId`, Render Data |
| `Salary Structure Row` | Structure List (`5.1`) | Structure Detail (`5.2`) | Push | `structureId` |
| `Salary Rule Row` | Structure Detail (`5.2`) | Rule Python Editor (`5.4`) | Push | `ruleId` |
| `Payroll Alert Pill` | Dashboard (`6.1`) | Payruns / Employee Hub | Deep Link Filter | Alert query string |
| `Copilot FAB` | Any Screen | AI Copilot Drawer (`7.1`) | Wolt Modal Sheet | JWT (self `employee_id`) |
| `Source Citation Chip` | AI Copilot (`7.1`) | Payslip / Policy Doc | Deep Link | `payslipId` / `docId` |
| `Ask HR Instead` | AI Copilot (`7.1`) | AI Copilot (`7.1`) | In-Place → Escalation Card | `prompt`, `conversationId` |
| `Track this question →` | Escalation Card (`7.1`) | My Questions (`7.3`) | Push | `escalationId` |
| `Nav Badge (Escalations)` | Any Screen (Admin/HR) | Escalation Inbox (`7.2`) | Push | Queue filter: `Unassigned` |
| `Ticket Card` | Escalation Inbox (`7.2`) | Answer Composer (`7.4`) | Push | `escalationId` |
| `Swipe → Assign to me` | Escalation Inbox (`7.2`) | Escalation Inbox (`7.2`) | In-Place Update | `escalationId`, `assigneeId` |
| `Send Answer to Employee` | Answer Composer (`7.4`) | Escalation Inbox (`7.2`) | Pop + Toast | `answerText`, `publishToKb` |
| `Answered Notification` | Any Screen (Employee) | My Questions (`7.3`) | Deep Link | `escalationId` (card pre-expanded) |

---

## 🏆 Hackathon Winning Polish & Evaluation Checklist
- [x] **100% SVG Fidelity**: Every screen, menu, smart button, and note from `HRMS OXP - 24 hours.excalidraw.svg` implemented.
- [x] **Zero Hardcoded Data**: All KPI cards, charts, and metrics dynamically aggregate from real relational models (Employees, Contracts, Attendances, Leaves, Payruns).
- [x] **Micro-Interactions**: Haptic feedback on button clicks, shimmer loading states on data fetch, and spring transitions.
- [x] **Odoo 18 Design Authenticity**: Signature Aubergine (`#714B67`) & Teal (`#017E84`) aesthetics with dark mode glassmorphism.
- [x] **Enterprise Validation**: Guardrails preventing overlapping running contracts, duplicate payslips, and negative leave balances.
- [x] **Mobile Optimization**: Pull-to-refresh, swipe-to-approve, responsive sliver app bars, and adaptive bottom sheets.
- [x] **AI HR Copilot (Local RAG)**: Hybrid PostgreSQL + `pgvector` assistant answering personal-data and policy questions with source citations, scoped per employee — the standout differentiator (Phase 7).
- [x] **Human-in-the-Loop Escalation**: The bot refuses on low confidence instead of hallucinating, routes the question to the right Admin/HR role with an SLA clock, the human answers directly, the employee is notified, and the verified answer is indexed so the assistant answers it itself next time — a closed learning loop with zero model training.
