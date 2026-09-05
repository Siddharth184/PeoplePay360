import '../models/models.dart';

class MockDataService {
  static EmployeeModel currentEmployee = EmployeeModel(
    id: 'emp-001',
    name: 'Aarav Sharma',
    email: 'aarav.sharma@peoplepay360.io',
    jobTitle: 'Senior Software Architect',
    department: 'Finance & Tech Ops',
    workPhone: '+91 98765 43210',
    managerName: 'Sara Khan (HR Director)',
    avatarUrl: 'https://images.unsplash.com/photo-1534528741775-53994a69daeb?w=150',
    timeOffBalance: 14,
    activeContractsCount: 1,
    attendancesCount: 22,
    payslipsCount: 12,
  );

  static List<EmployeeModel> allEmployees = [
    EmployeeModel(
      id: 'emp-001',
      name: 'Aarav Sharma',
      email: 'aarav.sharma@peoplepay360.io',
      jobTitle: 'Senior Software Architect',
      department: 'Finance & Tech Ops',
      workPhone: '+91 98765 43210',
      managerName: 'Sara Khan',
      avatarUrl: '',
      timeOffBalance: 14,
      activeContractsCount: 1,
      attendancesCount: 22,
      payslipsCount: 12,
    ),
    EmployeeModel(
      id: 'emp-002',
      name: 'Priya Patel',
      email: 'priya.patel@peoplepay360.io',
      jobTitle: 'Lead Payroll Analyst',
      department: 'Finance & Tech Ops',
      workPhone: '+91 98765 12345',
      managerName: 'Sara Khan',
      avatarUrl: '',
      timeOffBalance: 18,
      activeContractsCount: 1,
      attendancesCount: 20,
      payslipsCount: 12,
    ),
    EmployeeModel(
      id: 'emp-003',
      name: 'Rajesh Kumar',
      email: 'rajesh.kumar@peoplepay360.io',
      jobTitle: 'Senior HR Operations Manager',
      department: 'Human Resources',
      workPhone: '+91 98765 67890',
      managerName: 'Sara Khan',
      avatarUrl: '',
      timeOffBalance: 10,
      activeContractsCount: 1,
      attendancesCount: 21,
      payslipsCount: 12,
    ),
  ];

  static List<AttendanceModel> attendances = [
    AttendanceModel(id: 'att-01', dateStr: '2026-09-05', checkInTime: '09:02 AM', checkOutTime: null, status: 'PRESENT', workedHours: 5.5),
    AttendanceModel(id: 'att-02', dateStr: '2026-09-04', checkInTime: '09:15 AM', checkOutTime: '06:10 PM', status: 'LATE', workedHours: 8.5),
    AttendanceModel(id: 'att-03', dateStr: '2026-09-03', checkInTime: '08:58 AM', checkOutTime: '06:00 PM', status: 'PRESENT', workedHours: 9.0),
    AttendanceModel(id: 'att-04', dateStr: '2026-09-02', checkInTime: '09:00 AM', checkOutTime: '05:55 PM', status: 'PRESENT', workedHours: 8.9),
    AttendanceModel(id: 'att-05', dateStr: '2026-09-01', checkInTime: '09:05 AM', checkOutTime: '06:15 PM', status: 'PRESENT', workedHours: 9.1),
    AttendanceModel(id: 'att-06', dateStr: '2026-08-31', checkInTime: '08:55 AM', checkOutTime: '06:02 PM', status: 'PRESENT', workedHours: 9.0),
  ];

  static List<TimeOffRequestModel> timeOffRequests = [
    TimeOffRequestModel(id: 'req-01', typeName: 'Paid Time Off (PTO)', startDate: '2026-09-15', endDate: '2026-09-18', daysCount: 4.0, status: 'PENDING', reason: 'Family Annual Event'),
    TimeOffRequestModel(id: 'req-02', typeName: 'Sick Leave', startDate: '2026-08-10', endDate: '2026-08-10', daysCount: 1.0, status: 'APPROVED', reason: 'Fever & Doctor Visit'),
    TimeOffRequestModel(id: 'req-03', typeName: 'Casual Leave', startDate: '2026-07-01', endDate: '2026-07-02', daysCount: 2.0, status: 'APPROVED', reason: 'Personal errands'),
  ];

  static List<ContractModel> contracts = [
    ContractModel(id: 'con-01', refCode: 'CON/2026/0042', employeeName: 'Aarav Sharma', department: 'Finance & Tech Ops', startDate: '2026-01-01', wageMonthly: 100000.0, status: 'RUNNING'),
    ContractModel(id: 'con-02', refCode: 'CON/2025/0011', employeeName: 'Aarav Sharma', department: 'Software Dev', startDate: '2025-01-01', endDate: '2025-12-31', wageMonthly: 85000.0, status: 'EXPIRED'),
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
    PayslipModel(
      id: 'pay-01',
      refCode: 'PAY/2026/08',
      employeeName: 'Aarav Sharma',
      periodStart: '2026-08-01',
      periodEnd: '2026-08-31',
      grossAmount: 80000.0,
      netAmount: 75000.0,
      status: 'DONE',
      lines: [
        PayslipLineModel(ruleName: 'Basic Salary', ruleCode: 'BASIC', category: 'BASIC', amount: 50000.0),
        PayslipLineModel(ruleName: 'House Rent Allowance', ruleCode: 'HRA', category: 'ALLOWANCE', amount: 20000.0),
        PayslipLineModel(ruleName: 'Standard Allowance', ruleCode: 'STD', category: 'ALLOWANCE', amount: 10000.0),
        PayslipLineModel(ruleName: 'Gross Salary', ruleCode: 'GROSS', category: 'GROSS', amount: 80000.0),
        PayslipLineModel(ruleName: 'Provident Fund', ruleCode: 'PF', category: 'DEDUCTION', amount: -3000.0),
        PayslipLineModel(ruleName: 'Professional Tax', ruleCode: 'PT', category: 'DEDUCTION', amount: -2000.0),
        PayslipLineModel(ruleName: 'Net Salary', ruleCode: 'NET', category: 'NET', amount: 75000.0),
      ],
    ),
    PayslipModel(
      id: 'pay-02',
      refCode: 'PAY/2026/07',
      employeeName: 'Aarav Sharma',
      periodStart: '2026-07-01',
      periodEnd: '2026-07-31',
      grossAmount: 80000.0,
      netAmount: 75000.0,
      status: 'DONE',
      lines: [
        PayslipLineModel(ruleName: 'Basic Salary', ruleCode: 'BASIC', category: 'BASIC', amount: 50000.0),
        PayslipLineModel(ruleName: 'House Rent Allowance', ruleCode: 'HRA', category: 'ALLOWANCE', amount: 20000.0),
        PayslipLineModel(ruleName: 'Standard Allowance', ruleCode: 'STD', category: 'ALLOWANCE', amount: 10000.0),
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
  ];

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
  ];
}
