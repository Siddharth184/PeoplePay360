import '../models/models.dart';

/// Offline / demo fallback data.
///
/// Every service falls back to this catalogue when the FastAPI backend is
/// unreachable (see the `!ApiClient.isBackendOnline` branches). The data is
/// intentionally rich and internally consistent (employees, contracts,
/// attendance, leave and payroll all reference the same people) so the UI
/// looks fully populated during a demo even with no backend running.
class MockDataService {
  static final EmployeeModel adminEmployee = EmployeeModel(
    id: 'emp-admin',
    name: 'Admin User',
    email: 'admin@oxp.com',
    jobTitle: 'System Administrator & IT Director',
    department: 'Executive Management',
    workPhone: '+91 98765 00001',
    managerName: 'Board of Directors',
    avatarUrl: '',
    timeOffBalance: 25,
    activeContractsCount: 1,
    attendancesCount: 22,
    payslipsCount: 12,
    badgeId: 'ADM-001',
    employeeType: 'Full-time',
    status: 'ACTIVE',
    dateOfJoining: '2020-01-01',
    bankName: 'HDFC Bank',
    bankAccountNumber: '5010-0001-9900',
  );

  static final EmployeeModel hrManagerEmployee = EmployeeModel(
    id: 'emp-004',
    name: 'Sara Khan',
    email: 'sara.khan@oxp.com',
    jobTitle: 'HR Manager & People Director',
    department: 'Human Resources',
    workPhone: '+91 90210 33445',
    managerName: 'Board of Directors',
    avatarUrl: '',
    timeOffBalance: 22,
    activeContractsCount: 1,
    attendancesCount: 23,
    payslipsCount: 12,
    badgeId: 'EMP-4091',
    employeeType: 'Full-time',
    status: 'ACTIVE',
    dateOfJoining: '2021-01-04',
    bankName: 'Axis Bank',
    bankAccountNumber: '7720-5541-0098',
  );

  static final EmployeeModel payrollManagerEmployee = EmployeeModel(
    id: 'emp-005',
    name: 'Vikram Nair',
    email: 'vikram.nair@oxp.com',
    jobTitle: 'Finance Controller & Payroll Lead',
    department: 'Finance & Operations',
    workPhone: '+91 99887 66554',
    managerName: 'Sara Khan',
    avatarUrl: '',
    timeOffBalance: 16,
    activeContractsCount: 1,
    attendancesCount: 21,
    payslipsCount: 12,
    badgeId: 'EMP-4093',
    employeeType: 'Full-time',
    status: 'ACTIVE',
    dateOfJoining: '2022-03-15',
    bankName: 'ICICI Bank',
    bankAccountNumber: '4412-6690-3388',
  );

  static final EmployeeModel payrollUserEmployee = EmployeeModel(
    id: 'emp-001',
    name: 'Aarav Mehta',
    email: 'aarav.mehta@oxp.com',
    jobTitle: 'Payroll Officer',
    department: 'Finance & Tech Ops',
    workPhone: '+91 98765 43210',
    managerName: 'Sara Khan (HR Director)',
    avatarUrl: 'https://images.unsplash.com/photo-1534528741775-53994a69daeb?w=150',
    timeOffBalance: 14,
    activeContractsCount: 1,
    attendancesCount: 22,
    payslipsCount: 12,
    badgeId: 'EMP-4092',
    employeeType: 'Full-time',
    status: 'ACTIVE',
    dateOfJoining: '2024-04-01',
    bankName: 'HDFC Bank',
    bankAccountNumber: '5010-2288-4471',
  );

  static final EmployeeModel regularEmployee = EmployeeModel(
    id: 'emp-007',
    name: 'Rohan Desai',
    email: 'rohan.desai@oxp.com',
    jobTitle: 'Engineering Manager',
    department: 'Engineering',
    workPhone: '+91 98765 77889',
    managerName: 'Sara Khan',
    avatarUrl: '',
    timeOffBalance: 18,
    activeContractsCount: 1,
    attendancesCount: 20,
    payslipsCount: 12,
    badgeId: 'EMP-4095',
    employeeType: 'Full-time',
    status: 'ACTIVE',
    dateOfJoining: '2023-08-01',
    bankName: 'SBI',
    bankAccountNumber: '3391-4455-8822',
  );

  static final EmployeeModel priyaEmployee = EmployeeModel(
    id: 'emp-008',
    name: 'Priya Sharma',
    email: 'priya.sharma@oxp.com',
    jobTitle: 'Senior Software Engineer',
    department: 'Engineering',
    workPhone: '+91 98765 99001',
    managerName: 'Rohan Desai',
    avatarUrl: '',
    timeOffBalance: 16,
    activeContractsCount: 1,
    attendancesCount: 22,
    payslipsCount: 12,
    badgeId: 'EMP-4098',
    employeeType: 'Full-time',
    status: 'ACTIVE',
    dateOfJoining: '2023-01-15',
    bankName: 'HDFC Bank',
    bankAccountNumber: '5010-8822-1199',
  );

  static EmployeeModel currentEmployee = hrManagerEmployee;

  static void switchActiveUser(EmployeeModel emp) {
    currentEmployee = emp;
  }

  static EmployeeModel getEmployeeForUser({String? email, String? role, String? name}) {
    final cleanEmail = (email ?? '').toLowerCase().trim();
    final cleanRole = (role ?? '').toUpperCase().trim();
    final cleanName = (name ?? '').toLowerCase().trim();

    if (cleanEmail.contains('admin') || cleanRole == 'ADMIN' || cleanName.contains('admin')) {
      return adminEmployee;
    }
    if (cleanEmail.contains('sara') || cleanRole == 'HR_MANAGER' || cleanName.contains('sara')) {
      return hrManagerEmployee;
    }
    if (cleanEmail.contains('vikram') || cleanRole == 'HR_PAYROLL_MANAGER' || cleanEmail.contains('payroll_mgr')) {
      return payrollManagerEmployee;
    }
    if (cleanEmail.contains('aarav') || cleanRole == 'HR_PAYROLL_USER' || cleanName.contains('aarav')) {
      return payrollUserEmployee;
    }
    if (cleanEmail.contains('priya') || cleanEmail.contains('sharma') || cleanName.contains('priya')) {
      return priyaEmployee;
    }
    if (cleanEmail.contains('rohan') || cleanName.contains('rohan')) {
      return regularEmployee;
    }

    // Try matching in allEmployees
    for (final emp in allEmployees) {
      if (emp.email.toLowerCase() == cleanEmail || emp.name.toLowerCase() == cleanName) {
        return emp;
      }
    }

    if (cleanRole == 'EMPLOYEE') {
      return priyaEmployee;
    }

    return hrManagerEmployee;
  }

  static List<EmployeeModel> allEmployees = [
    adminEmployee,
    hrManagerEmployee,
    payrollManagerEmployee,
    payrollUserEmployee,
    priyaEmployee,
    regularEmployee,
    EmployeeModel(
      id: 'emp-002',
      name: 'Priya Patel',
      email: 'priya.patel@oxp.com',
      jobTitle: 'Lead Payroll Analyst',
      department: 'Finance & Tech Ops',
      workPhone: '+91 98765 12345',
      managerName: 'Sara Khan',
      avatarUrl: '',
      timeOffBalance: 18,
      activeContractsCount: 1,
      attendancesCount: 20,
      payslipsCount: 12,
      badgeId: 'EMP-002',
      employeeType: 'Full-time',
      status: 'ACTIVE',
      dateOfJoining: '2023-06-12',
      bankName: 'ICICI Bank',
      bankAccountNumber: '6644-7781-2230',
    ),
    EmployeeModel(
      id: 'emp-003',
      name: 'Rajesh Kumar',
      email: 'rajesh.kumar@oxp.com',
      jobTitle: 'Senior HR Operations Manager',
      department: 'Human Resources',
      workPhone: '+91 98765 67890',
      managerName: 'Sara Khan',
      avatarUrl: '',
      timeOffBalance: 10,
      activeContractsCount: 1,
      attendancesCount: 21,
      payslipsCount: 12,
      badgeId: 'EMP-003',
      employeeType: 'Full-time',
      status: 'ACTIVE',
      dateOfJoining: '2022-02-01',
      bankName: 'SBI',
      bankAccountNumber: '3391-0087-5512',
    ),
    EmployeeModel(
      id: 'emp-006',
      name: 'Neha Verma',
      email: 'neha.verma@oxp.com',
      jobTitle: 'UX Designer',
      department: 'Design',
      workPhone: '+91 97654 32109',
      managerName: 'Sara Khan',
      avatarUrl: '',
      timeOffBalance: 16,
      activeContractsCount: 1,
      attendancesCount: 20,
      payslipsCount: 10,
      badgeId: 'EMP-006',
      employeeType: 'Full-time',
      status: 'ACTIVE',
      dateOfJoining: '2024-01-22',
      bankName: 'HDFC Bank',
      bankAccountNumber: '5010-9987-1123',
    ),
    EmployeeModel(
      id: 'emp-007',
      name: 'Mohammed Ali',
      email: 'mohammed.ali@peoplepay360.io',
      jobTitle: 'Sales Executive',
      department: 'Sales',
      workPhone: '+91 96543 21087',
      managerName: 'Rajesh Kumar',
      avatarUrl: '',
      timeOffBalance: 9,
      activeContractsCount: 1,
      attendancesCount: 18,
      payslipsCount: 6,
      badgeId: 'EMP-007',
      employeeType: 'Contract',
      status: 'ACTIVE',
      dateOfJoining: '2025-03-03',
      bankName: 'Yes Bank',
      bankAccountNumber: '8890-2214-6675',
    ),
    EmployeeModel(
      id: 'emp-008',
      name: 'Ananya Reddy',
      email: 'ananya.reddy@peoplepay360.io',
      jobTitle: 'QA Engineer',
      department: 'Engineering',
      workPhone: '+91 95432 10876',
      managerName: 'Aarav Sharma',
      avatarUrl: '',
      timeOffBalance: 15,
      activeContractsCount: 1,
      attendancesCount: 21,
      payslipsCount: 9,
      badgeId: 'EMP-008',
      employeeType: 'Full-time',
      status: 'ACTIVE',
      dateOfJoining: '2024-07-08',
      bankName: 'IDFC First',
      bankAccountNumber: '2231-7788-4409',
    ),
    EmployeeModel(
      id: 'emp-009',
      name: 'Karan Mehta',
      email: 'karan.mehta@peoplepay360.io',
      jobTitle: 'Support Specialist',
      department: 'Customer Support',
      workPhone: '+91 94321 09875',
      managerName: 'Rajesh Kumar',
      avatarUrl: '',
      timeOffBalance: 7,
      activeContractsCount: 1,
      attendancesCount: 17,
      payslipsCount: 5,
      badgeId: 'EMP-009',
      employeeType: 'Full-time',
      status: 'ON_LEAVE',
      dateOfJoining: '2025-05-19',
      bankName: 'SBI',
      bankAccountNumber: '3391-6654-8890',
    ),
  ];

  static List<AttendanceModel>? _attendancesList;

  /// OFFLINE DEMO ONLY. Never shown when the backend is reachable.
  /// Dates are generated relative to "today" so the offline sample always looks
  /// current instead of being pinned to a fixed calendar day.
  static List<AttendanceModel> get attendances {
    if (_attendancesList != null) return _attendancesList!;
    final now = DateTime.now();
    DateTime dayAt(int daysAgo, int hour, int minute) {
      final d = now.subtract(Duration(days: daysAgo));
      return DateTime(d.year, d.month, d.day, hour, minute);
    }
    DateTime exactDate(int y, int m, int d, int h, int min) {
      return DateTime(y, m, d, h, min);
    }

    _attendancesList = [
      // Base dynamic relative records for existing tests
      AttendanceModel(id: 'att-01', checkIn: dayAt(1, 9, 2), checkOut: dayAt(1, 18, 0), status: 'PRESENT', workedHours: 8.9, overtimeHours: 0.9, employeeName: 'Aarav Sharma', employeeId: 'emp-001'),
      AttendanceModel(id: 'att-02', checkIn: dayAt(2, 9, 15), checkOut: dayAt(2, 18, 10), status: 'LATE', workedHours: 8.5, overtimeHours: 0.5, employeeName: 'Aarav Sharma', employeeId: 'emp-001'),
      AttendanceModel(id: 'att-03', checkIn: dayAt(3, 8, 58), checkOut: dayAt(3, 18, 0), status: 'PRESENT', workedHours: 9.0, overtimeHours: 1.0, employeeName: 'Aarav Sharma', employeeId: 'emp-001'),
      AttendanceModel(id: 'att-04', checkIn: dayAt(4, 9, 0), checkOut: dayAt(4, 17, 55), status: 'PRESENT', workedHours: 8.9, overtimeHours: 0.9, employeeName: 'Aarav Sharma', employeeId: 'emp-001'),
      AttendanceModel(id: 'att-05', checkIn: dayAt(5, 9, 5), checkOut: dayAt(5, 18, 15), status: 'PRESENT', workedHours: 9.1, overtimeHours: 1.1, employeeName: 'Aarav Sharma', employeeId: 'emp-001'),
      AttendanceModel(id: 'att-06', checkIn: dayAt(6, 8, 55), checkOut: dayAt(6, 18, 2), status: 'PRESENT', workedHours: 9.0, overtimeHours: 1.0, employeeName: 'Aarav Sharma', employeeId: 'emp-001'),
      AttendanceModel(id: 'att-07', checkIn: dayAt(1, 9, 20), checkOut: dayAt(1, 18, 20), status: 'LATE', workedHours: 9.0, overtimeHours: 1.0, employeeName: 'Priya Patel', employeeId: 'emp-002'),
      AttendanceModel(id: 'att-08', checkIn: dayAt(1, 8, 45), checkOut: dayAt(1, 17, 45), status: 'PRESENT', workedHours: 9.0, overtimeHours: 1.0, employeeName: 'Vikram Singh', employeeId: 'emp-005'),
      AttendanceModel(id: 'att-11', checkIn: dayAt(1, 9, 1), checkOut: dayAt(1, 18, 5), status: 'PRESENT', workedHours: 9.0, overtimeHours: 1.0, employeeName: 'Neha Verma', employeeId: 'emp-006'),
      AttendanceModel(id: 'att-12', checkIn: dayAt(1, 8, 50), checkOut: dayAt(1, 17, 45), status: 'PRESENT', workedHours: 8.9, overtimeHours: 0.9, employeeName: 'Ananya Reddy', employeeId: 'emp-008'),
      AttendanceModel(id: 'att-13', checkIn: dayAt(1, 9, 32), checkOut: dayAt(1, 18, 40), status: 'LATE', workedHours: 9.1, overtimeHours: 1.1, employeeName: 'Rajesh Kumar', employeeId: 'emp-003'),
      AttendanceModel(id: 'att-14', checkIn: dayAt(2, 8, 40), checkOut: dayAt(2, 17, 50), status: 'PRESENT', workedHours: 9.2, overtimeHours: 1.2, employeeName: 'Sara Khan', employeeId: 'emp-004'),

      // September 2026 Multi-Employee Records
      AttendanceModel(id: 'att-sep-01', checkIn: exactDate(2026, 9, 1, 9, 0), checkOut: exactDate(2026, 9, 1, 18, 0), status: 'PRESENT', workedHours: 8.0, overtimeHours: 0.0, employeeName: 'Aarav Sharma', employeeId: 'emp-001'),
      AttendanceModel(id: 'att-sep-02', checkIn: exactDate(2026, 9, 2, 9, 15), checkOut: exactDate(2026, 9, 2, 18, 10), status: 'LATE', workedHours: 7.9, overtimeHours: 0.0, employeeName: 'Aarav Sharma', employeeId: 'emp-001'),
      AttendanceModel(id: 'att-sep-03', checkIn: exactDate(2026, 9, 3, 8, 55), checkOut: exactDate(2026, 9, 3, 18, 30), status: 'PRESENT', workedHours: 8.5, overtimeHours: 0.5, employeeName: 'Aarav Sharma', employeeId: 'emp-001'),
      AttendanceModel(id: 'att-sep-04', checkIn: exactDate(2026, 9, 4, 9, 0), checkOut: exactDate(2026, 9, 4, 13, 0), status: 'HALF_DAY', workedHours: 4.0, overtimeHours: 0.0, employeeName: 'Aarav Sharma', employeeId: 'emp-001'),
      AttendanceModel(id: 'att-sep-05', checkIn: exactDate(2026, 9, 7, 9, 5), checkOut: exactDate(2026, 9, 7, 18, 0), status: 'PRESENT', workedHours: 7.9, overtimeHours: 0.0, employeeName: 'Aarav Sharma', employeeId: 'emp-001'),
      AttendanceModel(id: 'att-sep-06', checkIn: null, checkOut: null, status: 'LEAVE', workedHours: 0.0, overtimeHours: 0.0, auditNotes: 'Paid Time Off', employeeName: 'Aarav Sharma', employeeId: 'emp-001'),

      // August 2026 Multi-Employee Records
      AttendanceModel(id: 'att-aug-01', checkIn: exactDate(2026, 8, 3, 9, 0), checkOut: exactDate(2026, 8, 3, 18, 0), status: 'PRESENT', workedHours: 8.0, overtimeHours: 0.0, employeeName: 'Aarav Sharma', employeeId: 'emp-001'),
      AttendanceModel(id: 'att-aug-02', checkIn: exactDate(2026, 8, 4, 9, 25), checkOut: exactDate(2026, 8, 4, 18, 15), status: 'LATE', workedHours: 7.8, overtimeHours: 0.0, employeeName: 'Aarav Sharma', employeeId: 'emp-001'),
      AttendanceModel(id: 'att-aug-03', checkIn: exactDate(2026, 8, 5, 8, 50), checkOut: exactDate(2026, 8, 5, 19, 0), status: 'PRESENT', workedHours: 9.1, overtimeHours: 1.1, employeeName: 'Aarav Sharma', employeeId: 'emp-001'),
      AttendanceModel(id: 'att-aug-04', checkIn: null, checkOut: null, status: 'LEAVE', workedHours: 0.0, overtimeHours: 0.0, auditNotes: 'Sick Leave', employeeName: 'Aarav Sharma', employeeId: 'emp-001'),
      AttendanceModel(id: 'att-aug-05', checkIn: exactDate(2026, 8, 11, 9, 0), checkOut: exactDate(2026, 8, 11, 18, 0), status: 'PRESENT', workedHours: 8.0, overtimeHours: 0.0, employeeName: 'Aarav Sharma', employeeId: 'emp-001'),
      AttendanceModel(id: 'att-aug-06', checkIn: exactDate(2026, 8, 12, 9, 30), checkOut: exactDate(2026, 8, 12, 18, 30), status: 'LATE', workedHours: 8.0, overtimeHours: 0.0, employeeName: 'Aarav Sharma', employeeId: 'emp-001'),

      // July 2026 Multi-Employee Records
      AttendanceModel(id: 'att-jul-01', checkIn: null, checkOut: null, status: 'LEAVE', workedHours: 0.0, overtimeHours: 0.0, auditNotes: 'Compensatory Off', employeeName: 'Aarav Sharma', employeeId: 'emp-001'),
      AttendanceModel(id: 'att-jul-02', checkIn: exactDate(2026, 7, 2, 8, 55), checkOut: exactDate(2026, 7, 2, 18, 0), status: 'PRESENT', workedHours: 8.0, overtimeHours: 0.0, employeeName: 'Aarav Sharma', employeeId: 'emp-001'),
      AttendanceModel(id: 'att-jul-03', checkIn: exactDate(2026, 7, 3, 9, 0), checkOut: exactDate(2026, 7, 3, 18, 0), status: 'PRESENT', workedHours: 8.0, overtimeHours: 0.0, employeeName: 'Aarav Sharma', employeeId: 'emp-001'),

      // Priya Patel (emp-002) Multi-Month Records
      AttendanceModel(id: 'att-pri-01', checkIn: exactDate(2026, 9, 1, 9, 10), checkOut: exactDate(2026, 9, 1, 18, 15), status: 'LATE', workedHours: 8.0, overtimeHours: 0.0, employeeName: 'Priya Patel', employeeId: 'emp-002'),
      AttendanceModel(id: 'att-pri-02', checkIn: exactDate(2026, 9, 2, 8, 50), checkOut: exactDate(2026, 9, 2, 18, 0), status: 'PRESENT', workedHours: 8.1, overtimeHours: 0.1, employeeName: 'Priya Patel', employeeId: 'emp-002'),
      AttendanceModel(id: 'att-pri-03', checkIn: exactDate(2026, 8, 1, 9, 0), checkOut: exactDate(2026, 8, 1, 18, 0), status: 'PRESENT', workedHours: 8.0, overtimeHours: 0.0, employeeName: 'Priya Patel', employeeId: 'emp-002'),

      // Rajesh Kumar (emp-003) Multi-Month Records
      AttendanceModel(id: 'att-raj-01', checkIn: exactDate(2026, 9, 1, 9, 25), checkOut: exactDate(2026, 9, 1, 18, 30), status: 'LATE', workedHours: 8.0, overtimeHours: 0.0, employeeName: 'Rajesh Kumar', employeeId: 'emp-003'),
      AttendanceModel(id: 'att-raj-02', checkIn: exactDate(2026, 9, 2, 8, 55), checkOut: exactDate(2026, 9, 2, 18, 0), status: 'PRESENT', workedHours: 8.0, overtimeHours: 0.0, employeeName: 'Rajesh Kumar', employeeId: 'emp-003'),

      // Sara Khan (emp-004) Multi-Month Records
      AttendanceModel(id: 'att-sar-01', checkIn: exactDate(2026, 9, 1, 8, 45), checkOut: exactDate(2026, 9, 1, 18, 0), status: 'PRESENT', workedHours: 8.2, overtimeHours: 0.2, employeeName: 'Sara Khan', employeeId: 'emp-004'),
      AttendanceModel(id: 'att-sar-02', checkIn: exactDate(2026, 8, 1, 8, 40), checkOut: exactDate(2026, 8, 1, 18, 0), status: 'PRESENT', workedHours: 8.3, overtimeHours: 0.3, employeeName: 'Sara Khan', employeeId: 'emp-004'),
    ];
    return _attendancesList!;
  }

  static List<TimeOffRequestModel> timeOffRequests = [
    TimeOffRequestModel(id: 'req-01', timeoffTypeId: 'tot-01', typeName: 'Paid Time Off', startDate: '2026-09-15', endDate: '2026-09-18', daysCount: 4.0, status: 'TO_APPROVE', reason: 'Family Annual Event', employeeName: 'Aarav Mehta', employeeId: 'emp-001'),
    TimeOffRequestModel(id: 'req-02', timeoffTypeId: 'tot-02', typeName: 'Sick Leave', startDate: '2026-08-10', endDate: '2026-08-10', daysCount: 1.0, status: 'APPROVED', reason: 'Fever & Doctor Visit', employeeName: 'Aarav Mehta', employeeId: 'emp-001'),
    TimeOffRequestModel(id: 'req-03', timeoffTypeId: 'tot-04', typeName: 'Compensatory Off', startDate: '2026-07-01', endDate: '2026-07-02', daysCount: 2.0, status: 'APPROVED', reason: 'Personal errands', employeeName: 'Aarav Mehta', employeeId: 'emp-001'),
    TimeOffRequestModel(id: 'req-04', timeoffTypeId: 'tot-01', typeName: 'Paid Time Off', startDate: '2026-09-22', endDate: '2026-09-26', daysCount: 5.0, status: 'TO_APPROVE', reason: 'Diwali travel to hometown', employeeName: 'Priya Patel', employeeId: 'emp-002'),
    TimeOffRequestModel(id: 'req-05', timeoffTypeId: 'tot-02', typeName: 'Sick Leave', startDate: '2026-09-02', endDate: '2026-09-03', daysCount: 2.0, status: 'APPROVED', reason: 'Viral flu, doctor advised rest', employeeName: 'Vikram Singh', employeeId: 'emp-005'),
    TimeOffRequestModel(id: 'req-06', timeoffTypeId: 'tot-04', typeName: 'Compensatory Off', startDate: '2026-09-12', endDate: '2026-09-12', daysCount: 1.0, status: 'TO_APPROVE', reason: 'Weekend payroll deployment (Aug 30)', employeeName: 'Neha Verma', employeeId: 'emp-006'),
    TimeOffRequestModel(id: 'req-07', timeoffTypeId: 'tot-03', typeName: 'Maternity Leave', startDate: '2026-10-01', endDate: '2026-12-30', daysCount: 90.0, status: 'APPROVED', reason: 'Maternity leave as per policy', employeeName: 'Ananya Reddy', employeeId: 'emp-008'),
    TimeOffRequestModel(id: 'req-08', timeoffTypeId: 'tot-05', typeName: 'Unpaid Leave', startDate: '2026-08-25', endDate: '2026-08-27', daysCount: 3.0, status: 'REFUSED', reason: 'Insufficient balance, LOP requested', employeeName: 'Mohammed Ali', employeeId: 'emp-007'),
  ];

  /// Leave balances / allocations per employee per leave type.
  /// Kept as maps so screens that render an allocation matrix have data even
  /// without a dedicated model class.
  static List<Map<String, dynamic>> leaveAllocations = [
    {'employeeName': 'Aarav Sharma', 'type': 'Paid Time Off (PTO)', 'allocated': 24.0, 'taken': 10.0, 'remaining': 14.0, 'status': 'APPROVED', 'validity': '2026'},
    {'employeeName': 'Aarav Sharma', 'type': 'Sick Leave', 'allocated': 12.0, 'taken': 4.0, 'remaining': 8.0, 'status': 'APPROVED', 'validity': '2026'},
    {'employeeName': 'Aarav Sharma', 'type': 'Comp Off', 'allocated': 2.0, 'taken': 0.0, 'remaining': 2.0, 'status': 'APPROVED', 'validity': '2026'},
    {'employeeName': 'Priya Patel', 'type': 'Paid Time Off (PTO)', 'allocated': 24.0, 'taken': 6.0, 'remaining': 18.0, 'status': 'APPROVED', 'validity': '2026'},
    {'employeeName': 'Priya Patel', 'type': 'Sick Leave', 'allocated': 12.0, 'taken': 2.0, 'remaining': 10.0, 'status': 'APPROVED', 'validity': '2026'},
    {'employeeName': 'Vikram Singh', 'type': 'Paid Time Off (PTO)', 'allocated': 24.0, 'taken': 12.0, 'remaining': 12.0, 'status': 'APPROVED', 'validity': '2026'},
    {'employeeName': 'Neha Verma', 'type': 'Comp Off', 'allocated': 3.0, 'taken': 1.0, 'remaining': 2.0, 'status': 'PENDING', 'validity': '2026'},
    {'employeeName': 'Ananya Reddy', 'type': 'Maternity Leave', 'allocated': 90.0, 'taken': 0.0, 'remaining': 90.0, 'status': 'APPROVED', 'validity': '2026'},
  ];

  static List<ContractModel> contracts = [
    ContractModel(id: 'con-01', refCode: 'CON/2026/0010', employeeName: 'Sara Khan', department: 'Human Resources', startDate: '2021-01-04', wageMonthly: 125000.0, status: 'RUNNING', structureName: 'Executive Salary Structure'),
    ContractModel(id: 'con-02', refCode: 'CON/2026/0042', employeeName: 'Aarav Mehta', department: 'Finance & Tech Ops', startDate: '2024-04-01', wageMonthly: 100000.0, status: 'RUNNING', structureName: 'Regular Employee Base'),
    ContractModel(id: 'con-02b', refCode: 'CON/2023/0018', employeeName: 'Aarav Mehta', department: 'Finance & Tech Ops', startDate: '2023-04-01', endDate: '2024-03-31', wageMonthly: 85000.0, status: 'EXPIRED', structureName: 'Regular Employee Base'),
    ContractModel(id: 'con-03', refCode: 'CON/2026/0015', employeeName: 'Vikram Nair', department: 'Finance & Operations', startDate: '2022-03-15', wageMonthly: 115000.0, status: 'RUNNING', structureName: 'Executive Salary Structure'),
    ContractModel(id: 'con-04', refCode: 'CON/2026/0022', employeeName: 'Priya Sharma', department: 'Engineering', startDate: '2023-01-15', wageMonthly: 95000.0, status: 'RUNNING', structureName: 'Regular Employee Base'),
    ContractModel(id: 'con-05', refCode: 'CON/2026/0031', employeeName: 'Rohan Desai', department: 'Engineering', startDate: '2023-08-01', wageMonthly: 110000.0, status: 'RUNNING', structureName: 'Executive Salary Structure'),
    ContractModel(id: 'con-06', refCode: 'CON/2026/0043', employeeName: 'Priya Patel', department: 'Finance & Tech Ops', startDate: '2023-06-12', wageMonthly: 92000.0, status: 'RUNNING', structureName: 'Regular Employee Base'),
    ContractModel(id: 'con-07', refCode: 'CON/2026/0028', employeeName: 'Rajesh Kumar', department: 'Human Resources', startDate: '2022-02-01', wageMonthly: 88000.0, status: 'RUNNING', structureName: 'Regular Employee Base'),
    ContractModel(id: 'con-08', refCode: 'CON/2026/0051', employeeName: 'Neha Verma', department: 'Design', startDate: '2024-01-22', wageMonthly: 70000.0, status: 'RUNNING', structureName: 'Regular Employee Base'),
    ContractModel(id: 'con-09', refCode: 'CON/2026/0045', employeeName: 'Mohammed Ali', department: 'Sales', startDate: '2025-03-03', endDate: '2026-08-31', wageMonthly: 55000.0, status: 'EXPIRED', structureName: 'Contractor Base'),
    ContractModel(id: 'con-10', refCode: 'CON/2026/0054', employeeName: 'Ananya Reddy', department: 'Engineering', startDate: '2024-07-08', wageMonthly: 72000.0, status: 'RUNNING', structureName: 'Regular Employee Base'),
    ContractModel(id: 'con-11', refCode: 'CON/2026/0052', employeeName: 'Karan Mehta', department: 'Customer Support', startDate: '2025-05-19', wageMonthly: 48000.0, status: 'DRAFT', structureName: 'Regular Employee Base'),
    ContractModel(id: 'con-12', refCode: 'CON/2026/0001', employeeName: 'Admin User', department: 'Executive Management', startDate: '2020-01-01', wageMonthly: 150000.0, status: 'RUNNING', structureName: 'Executive Salary Structure'),
  ];

  static List<SalaryRuleModel> salaryRules = [
    SalaryRuleModel(id: 'r-1', name: 'Basic Salary', code: 'BASIC', sequence: 1, category: 'BASIC', computationType: 'PERCENTAGE', percentageBase: 'WAGE', percentageRate: 50.0, pythonCode: "result = contract.wage * 0.50"),
    SalaryRuleModel(id: 'r-2', name: 'House Rent Allowance', code: 'HRA', sequence: 10, category: 'ALLOWANCE', computationType: 'PERCENTAGE', percentageBase: 'BASIC', percentageRate: 40.0, pythonCode: "result = categories['BASIC'] * 0.40"),
    SalaryRuleModel(id: 'r-3', name: 'Standard Allowance', code: 'STD', sequence: 20, category: 'ALLOWANCE', computationType: 'FIXED', fixedAmount: 10000.0, pythonCode: "result = 10000.0"),
    SalaryRuleModel(id: 'r-4', name: 'Gross Salary', code: 'GROSS', sequence: 60, category: 'GROSS', computationType: 'PYTHON_CODE', pythonCode: "result = categories['BASIC'] + categories['ALLOWANCE']"),
    SalaryRuleModel(id: 'r-5', name: 'Provident Fund', code: 'PF', sequence: 80, category: 'DEDUCTION', computationType: 'PERCENTAGE', percentageBase: 'BASIC', percentageRate: 6.0, pythonCode: "result = categories['BASIC'] * 0.06"),
    SalaryRuleModel(id: 'r-6', name: 'Professional Tax', code: 'PT', sequence: 100, category: 'DEDUCTION', computationType: 'FIXED', fixedAmount: 2000.0, pythonCode: "result = 2000.0"),
    SalaryRuleModel(id: 'r-7', name: 'Net Salary', code: 'NET', sequence: 110, category: 'NET', computationType: 'PYTHON_CODE', pythonCode: "result = categories['GROSS'] - categories['DEDUCTION']"),
  ];

  static List<PayslipModel> payslips = [
    // Sept 2026
    PayslipModel(
      id: 'pay-09',
      refCode: 'SLIP/2026/09-001',
      employeeName: 'Sara Khan',
      periodStart: '2026-09-01',
      periodEnd: '2026-09-30',
      contractMonthlyWage: 125000.0,
      overtimeHours: 12.0,
      overtimePay: 12784.09,
      extraDays: 2.0,
      extraDaysPay: 11363.64,
      grossAmount: 139147.73,
      netAmount: 126747.73,
      status: 'PAID',
      lines: [
        PayslipLineModel(ruleName: 'Basic Salary', ruleCode: 'BASIC', category: 'BASIC', amount: 85000.0),
        PayslipLineModel(ruleName: 'House Rent Allowance', ruleCode: 'HRA', category: 'ALLOWANCE', amount: 20000.0),
        PayslipLineModel(ruleName: 'Special Allowance', ruleCode: 'SA', category: 'ALLOWANCE', amount: 8500.0),
        PayslipLineModel(ruleName: 'Overtime Earning (1.5x Rate)', ruleCode: 'OT', category: 'ALLOWANCE', amount: 12784.09),
        PayslipLineModel(ruleName: 'Extra Days Payout', ruleCode: 'EXT_DAYS', category: 'ALLOWANCE', amount: 11363.64),
        PayslipLineModel(ruleName: 'Gross Salary', ruleCode: 'GROSS', category: 'GROSS', amount: 139147.73),
        PayslipLineModel(ruleName: 'Provident Fund', ruleCode: 'PF', category: 'DEDUCTION', amount: -10200.0),
        PayslipLineModel(ruleName: 'Professional Tax', ruleCode: 'PT', category: 'DEDUCTION', amount: -2200.0),
        PayslipLineModel(ruleName: 'Net Salary', ruleCode: 'NET', category: 'NET', amount: 126747.73),
      ],
    ),
    // Aug 2026
    PayslipModel(
      id: 'pay-08',
      refCode: 'SLIP/2026/08-001',
      employeeName: 'Aarav Sharma',
      periodStart: '2026-08-01',
      periodEnd: '2026-08-31',
      contractMonthlyWage: 85000.0,
      overtimeHours: 10.0,
      overtimePay: 7244.32,
      extraDays: 2.0,
      extraDaysPay: 7727.27,
      grossAmount: 94971.59,
      netAmount: 89971.59,
      status: 'DONE',
      lines: [
        PayslipLineModel(ruleName: 'Basic Salary', ruleCode: 'BASIC', category: 'BASIC', amount: 50000.0),
        PayslipLineModel(ruleName: 'House Rent Allowance', ruleCode: 'HRA', category: 'ALLOWANCE', amount: 20000.0),
        PayslipLineModel(ruleName: 'Standard Allowance', ruleCode: 'STD', category: 'ALLOWANCE', amount: 10000.0),
        PayslipLineModel(ruleName: 'Overtime Earning (1.5x Rate)', ruleCode: 'OT', category: 'ALLOWANCE', amount: 7244.32),
        PayslipLineModel(ruleName: 'Extra Days Payout', ruleCode: 'EXT_DAYS', category: 'ALLOWANCE', amount: 7727.27),
        PayslipLineModel(ruleName: 'Gross Salary', ruleCode: 'GROSS', category: 'GROSS', amount: 94971.59),
        PayslipLineModel(ruleName: 'Provident Fund', ruleCode: 'PF', category: 'DEDUCTION', amount: -3000.0),
        PayslipLineModel(ruleName: 'Professional Tax', ruleCode: 'PT', category: 'DEDUCTION', amount: -2000.0),
        PayslipLineModel(ruleName: 'Net Salary', ruleCode: 'NET', category: 'NET', amount: 89971.59),
      ],
    ),
    // Jul 2026
    PayslipModel(
      id: 'pay-07',
      refCode: 'SLIP/2026/07-001',
      employeeName: 'Sara Khan',
      periodStart: '2026-07-01',
      periodEnd: '2026-07-31',
      contractMonthlyWage: 85000.0,
      overtimeHours: 8.0,
      overtimePay: 5795.45,
      extraDays: 1.0,
      extraDaysPay: 3863.64,
      grossAmount: 89659.09,
      netAmount: 84659.09,
      status: 'PAID',
      lines: [
        PayslipLineModel(ruleName: 'Basic Salary', ruleCode: 'BASIC', category: 'BASIC', amount: 50000.0),
        PayslipLineModel(ruleName: 'House Rent Allowance', ruleCode: 'HRA', category: 'ALLOWANCE', amount: 20000.0),
        PayslipLineModel(ruleName: 'Special Allowance', ruleCode: 'SA', category: 'ALLOWANCE', amount: 10000.0),
        PayslipLineModel(ruleName: 'Overtime Earning (1.5x Rate)', ruleCode: 'OT', category: 'ALLOWANCE', amount: 5795.45),
        PayslipLineModel(ruleName: 'Extra Days Payout', ruleCode: 'EXT_DAYS', category: 'ALLOWANCE', amount: 3863.64),
        PayslipLineModel(ruleName: 'Gross Salary', ruleCode: 'GROSS', category: 'GROSS', amount: 89659.09),
        PayslipLineModel(ruleName: 'Provident Fund', ruleCode: 'PF', category: 'DEDUCTION', amount: -3000.0),
        PayslipLineModel(ruleName: 'Professional Tax', ruleCode: 'PT', category: 'DEDUCTION', amount: -2000.0),
        PayslipLineModel(ruleName: 'Net Salary', ruleCode: 'NET', category: 'NET', amount: 84659.09),
      ],
    ),
    // Jun 2026
    PayslipModel(
      id: 'pay-06',
      refCode: 'SLIP/2026/06-001',
      employeeName: 'Sara Khan',
      periodStart: '2026-06-01',
      periodEnd: '2026-06-30',
      contractMonthlyWage: 85000.0,
      overtimeHours: 5.0,
      overtimePay: 3622.16,
      extraDays: 0.0,
      extraDaysPay: 0.0,
      grossAmount: 83622.16,
      netAmount: 78622.16,
      status: 'PAID',
      lines: [
        PayslipLineModel(ruleName: 'Basic Salary', ruleCode: 'BASIC', category: 'BASIC', amount: 50000.0),
        PayslipLineModel(ruleName: 'House Rent Allowance', ruleCode: 'HRA', category: 'ALLOWANCE', amount: 20000.0),
        PayslipLineModel(ruleName: 'Special Allowance', ruleCode: 'SA', category: 'ALLOWANCE', amount: 10000.0),
        PayslipLineModel(ruleName: 'Overtime Earning (1.5x Rate)', ruleCode: 'OT', category: 'ALLOWANCE', amount: 3622.16),
        PayslipLineModel(ruleName: 'Gross Salary', ruleCode: 'GROSS', category: 'GROSS', amount: 83622.16),
        PayslipLineModel(ruleName: 'Provident Fund', ruleCode: 'PF', category: 'DEDUCTION', amount: -3000.0),
        PayslipLineModel(ruleName: 'Professional Tax', ruleCode: 'PT', category: 'DEDUCTION', amount: -2000.0),
        PayslipLineModel(ruleName: 'Net Salary', ruleCode: 'NET', category: 'NET', amount: 78622.16),
      ],
    ),
    // Feb 2026
    PayslipModel(
      id: 'pay-02-sk',
      refCode: 'SLIP/2026/02-001',
      employeeName: 'Sara Khan',
      periodStart: '2026-02-01',
      periodEnd: '2026-02-28',
      contractMonthlyWage: 85000.0,
      overtimeHours: 0.0,
      overtimePay: 0.0,
      extraDays: 0.0,
      extraDaysPay: 0.0,
      grossAmount: 80000.0,
      netAmount: 75000.0,
      status: 'CONFIRMED',
      lines: [
        PayslipLineModel(ruleName: 'Basic Salary', ruleCode: 'BASIC', category: 'BASIC', amount: 50000.0),
        PayslipLineModel(ruleName: 'House Rent Allowance', ruleCode: 'HRA', category: 'ALLOWANCE', amount: 20000.0),
        PayslipLineModel(ruleName: 'Special Allowance', ruleCode: 'SA', category: 'ALLOWANCE', amount: 10000.0),
        PayslipLineModel(ruleName: 'Gross Salary', ruleCode: 'GROSS', category: 'GROSS', amount: 80000.0),
        PayslipLineModel(ruleName: 'Provident Fund', ruleCode: 'PF', category: 'DEDUCTION', amount: -3000.0),
        PayslipLineModel(ruleName: 'Professional Tax', ruleCode: 'PT', category: 'DEDUCTION', amount: -2000.0),
        PayslipLineModel(ruleName: 'Net Salary', ruleCode: 'NET', category: 'NET', amount: 75000.0),
      ],
    ),
  ];

  static List<EscalationTicketModel> escalationTickets = [
    EscalationTicketModel(
      id: 'esc-01',
      ticketNo: 'ESC/2026/0042',
      questionText: 'Can I carry forward my unused 14 PTO days into Q1 next year?',
      category: 'LEAVE_POLICY',
      status: 'ASSIGNED',
      priority: 'HIGH',
      slaDueAt: '2026-09-06 18:00',
      answerText: null,
      answeredBy: 'Sara Khan (HR Director)',
      retrievalConfidence: 0.38,
    ),
    EscalationTicketModel(
      id: 'esc-02',
      ticketNo: 'ESC/2026/0038',
      questionText: 'Is Professional Tax (PT) calculated on gross or basic salary in Maharashtra?',
      category: 'TAX_STATUTORY',
      status: 'ANSWERED',
      priority: 'NORMAL',
      slaDueAt: '2026-09-04 12:00',
      answerText: 'Professional Tax in Maharashtra is a fixed statutory deduction of ₹2,000/year (₹200/month except February which is ₹300). It is independent of basic salary.',
      answeredBy: 'Priya Patel (Payroll Mgr)',
      retrievalConfidence: 0.41,
    ),
    EscalationTicketModel(
      id: 'esc-03',
      ticketNo: 'ESC/2026/0051',
      questionText: 'What is the notice period for a contract employee resigning mid-term?',
      category: 'CONTRACT',
      status: 'OPEN',
      priority: 'NORMAL',
      slaDueAt: '2026-09-07 10:00',
      answerText: null,
      answeredBy: null,
      retrievalConfidence: 0.29,
    ),
    EscalationTicketModel(
      id: 'esc-04',
      ticketNo: 'ESC/2026/0055',
      questionText: 'My September attendance shows a missed check-out on Sep 5. Will it affect payroll?',
      category: 'ATTENDANCE',
      status: 'OPEN',
      priority: 'HIGH',
      slaDueAt: '2026-09-06 16:00',
      answerText: null,
      answeredBy: null,
      retrievalConfidence: 0.44,
    ),
  ];

  static List<WorkingScheduleModel> workingSchedules = [
    WorkingScheduleModel(
      id: 'ws-01',
      name: 'Standard 40 Hours / Week',
      averageHoursPerWeek: 40,
      daysPerWeek: 5,
      timezone: 'Asia/Kolkata',
    ),
    WorkingScheduleModel(
      id: 'ws-02',
      name: 'Night Shift 45 Hours / Week',
      averageHoursPerWeek: 45,
      daysPerWeek: 5,
      timezone: 'Asia/Kolkata',
    ),
    WorkingScheduleModel(
      id: 'ws-03',
      name: 'Part-Time 24 Hours / Week',
      averageHoursPerWeek: 24,
      daysPerWeek: 4,
      timezone: 'Asia/Kolkata',
    ),
    WorkingScheduleModel(
      id: 'ws-04',
      name: 'Hybrid 36 Hours / Week',
      averageHoursPerWeek: 36,
      daysPerWeek: 5,
      timezone: 'Asia/Kolkata',
    ),
  ];

  static List<TimeOffTypeModel> timeOffTypes = [
    TimeOffTypeModel(
      id: 'tot-01',
      name: 'Paid Time Off',
      code: 'PTO',
      requiresApproval: true,
      color: '#0d9488', // odooTeal
    ),
    TimeOffTypeModel(
      id: 'tot-02',
      name: 'Sick Leave',
      code: 'SL',
      requiresApproval: false,
      color: '#e11d48', // odooRed
    ),
    TimeOffTypeModel(
      id: 'tot-03',
      name: 'Maternity Leave',
      code: 'ML',
      requiresApproval: true,
      color: '#57344f', // odooAubergine
    ),
    TimeOffTypeModel(
      id: 'tot-04',
      name: 'Compensatory Off',
      code: 'COMP',
      requiresApproval: true,
      color: '#2563eb', // blue
    ),
    TimeOffTypeModel(
      id: 'tot-05',
      name: 'Unpaid Leave',
      code: 'LOP',
      requiresAllocation: false,
      requiresApproval: true,
      isPaid: false,
      color: '#64748b', // slate
    ),
  ];

  static List<LeaveBalanceModel>? _leaveBalancesList;

  static List<LeaveBalanceModel> getLeaveBalances([String? employeeId]) {
    if (_leaveBalancesList == null) {
      _leaveBalancesList = [
        LeaveBalanceModel(
          allocationId: 'alloc-01',
          timeoffTypeId: 'tot-01',
          timeoffTypeName: 'Paid Time Off',
          displayColor: '#0d9488',
          unit: 'DAYS',
          allocatedDays: 20.0,
          takenDays: 5.0,
          remainingDays: 15.0,
          validityYear: DateTime.now().year,
        ),
        LeaveBalanceModel(
          allocationId: 'alloc-02',
          timeoffTypeId: 'tot-02',
          timeoffTypeName: 'Sick Leave',
          displayColor: '#e11d48',
          unit: 'DAYS',
          allocatedDays: 10.0,
          takenDays: 2.0,
          remainingDays: 8.0,
          validityYear: DateTime.now().year,
        ),
        LeaveBalanceModel(
          allocationId: 'alloc-03',
          timeoffTypeId: 'tot-03',
          timeoffTypeName: 'Maternity Leave',
          displayColor: '#57344f',
          unit: 'DAYS',
          allocatedDays: 90.0,
          takenDays: 0.0,
          remainingDays: 90.0,
          validityYear: DateTime.now().year,
        ),
        LeaveBalanceModel(
          allocationId: 'alloc-04',
          timeoffTypeId: 'tot-04',
          timeoffTypeName: 'Compensatory Off',
          displayColor: '#2563eb',
          unit: 'DAYS',
          allocatedDays: 5.0,
          takenDays: 1.0,
          remainingDays: 4.0,
          validityYear: DateTime.now().year,
        ),
        LeaveBalanceModel(
          allocationId: 'alloc-05',
          timeoffTypeId: 'tot-05',
          timeoffTypeName: 'Unpaid Leave',
          displayColor: '#64748b',
          unit: 'DAYS',
          allocatedDays: 99.0,
          takenDays: 0.0,
          remainingDays: 99.0,
          validityYear: DateTime.now().year,
        ),
      ];
    }
    return _leaveBalancesList!;
  }

  /// Debit or credit leave balance dynamically in memory.
  static void updateLeaveBalance(String timeOffTypeId, String typeName, double deltaTaken) {
    final list = getLeaveBalances();
    final idx = list.indexWhere((b) =>
        (timeOffTypeId.isNotEmpty && b.timeoffTypeId == timeOffTypeId) ||
        b.timeoffTypeName.toLowerCase().contains(typeName.toLowerCase()) ||
        typeName.toLowerCase().contains(b.timeoffTypeName.toLowerCase()));
    if (idx >= 0) {
      final old = list[idx];
      final newTaken = (old.takenDays + deltaTaken) < 0 ? 0.0 : (old.takenDays + deltaTaken);
      final newRemaining = old.allocatedDays - newTaken;
      list[idx] = LeaveBalanceModel(
        allocationId: old.allocationId,
        timeoffTypeId: old.timeoffTypeId,
        timeoffTypeName: old.timeoffTypeName,
        displayColor: old.displayColor,
        unit: old.unit,
        allocatedDays: old.allocatedDays,
        takenDays: double.parse(newTaken.toStringAsFixed(1)),
        remainingDays: double.parse(newRemaining.toStringAsFixed(1)),
        validityYear: old.validityYear,
      );
    }
  }

  static List<SalaryStructureModel> salaryStructures = [
    SalaryStructureModel(
      id: 'struct-01',
      name: 'Regular Employee Base',
      reference: 'BASE-IN',
      country: 'India',
      ruleIds: ['BASIC', 'HRA', 'STD', 'GROSS', 'PF', 'PT', 'NET'],
    ),
    SalaryStructureModel(
      id: 'struct-02',
      name: 'Contractor Base',
      reference: 'CONT-IN',
      country: 'India',
      ruleIds: ['BASIC', 'TDS', 'NET'],
    ),
    SalaryStructureModel(
      id: 'struct-03',
      name: 'Intern Stipend',
      reference: 'INTERN-IN',
      country: 'India',
      ruleIds: ['BASIC', 'NET'],
    ),
  ];
}
