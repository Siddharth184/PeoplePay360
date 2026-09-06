class EmployeeModel {
  final String id;
  final String name;
  final String email;
  final String jobTitle;
  final String department;
  final String workPhone;
  final String managerName;
  final String avatarUrl;
  final int timeOffBalance;
  final int activeContractsCount;
  final int attendancesCount;
  final int payslipsCount;
  final String? badgeId;
  final String? employeeType;
  final String? status;
  final String? dateOfJoining;
  final String? bankName;
  final String? bankAccountNumber;
  final String? workLocation;

  EmployeeModel({
    required this.id,
    required this.name,
    required this.email,
    required this.jobTitle,
    required this.department,
    required this.workPhone,
    required this.managerName,
    required this.avatarUrl,
    required this.timeOffBalance,
    required this.activeContractsCount,
    required this.attendancesCount,
    required this.payslipsCount,
    this.badgeId,
    this.employeeType,
    this.status,
    this.dateOfJoining,
    this.bankName,
    this.bankAccountNumber,
    this.workLocation,
  });

  factory EmployeeModel.fromJson(Map<String, dynamic> json) {
    return EmployeeModel(
      id: json['id']?.toString() ?? '',
      name: json['name']?.toString() ?? '',
      email: json['work_email']?.toString() ?? json['email']?.toString() ?? '',
      jobTitle: json['job_position']?.toString() ?? json['job_position_name']?.toString() ?? json['jobTitle']?.toString() ?? 'Staff',
      department: json['department']?.toString() ?? json['department_name']?.toString() ?? json['department']?.toString() ?? 'General',
      workPhone: json['phone']?.toString() ?? json['workPhone']?.toString() ?? '',
      managerName: json['manager_name']?.toString() ?? json['managerName']?.toString() ?? 'Sara Khan',
      avatarUrl: json['avatar_url']?.toString() ?? json['avatarUrl']?.toString() ?? '',
      timeOffBalance: json['time_off_balance'] is num ? (json['time_off_balance'] as num).toInt() : (json['timeOffBalance'] ?? 14),
      activeContractsCount: json['active_contracts_count'] is num ? (json['active_contracts_count'] as num).toInt() : (json['activeContractsCount'] ?? 1),
      attendancesCount: json['attendances_count'] is num ? (json['attendances_count'] as num).toInt() : (json['attendancesCount'] ?? 20),
      payslipsCount: json['payslips_count'] is num ? (json['payslips_count'] as num).toInt() : (json['payslipsCount'] ?? 12),
      badgeId: json['badge_id']?.toString(),
      employeeType: json['employee_type']?.toString(),
      status: json['status']?.toString(),
      dateOfJoining: json['date_of_joining']?.toString(),
      bankName: json['bank_name']?.toString(),
      bankAccountNumber: json['bank_account_number']?.toString(),
      workLocation: json['work_location']?.toString() ?? json['workLocation']?.toString() ?? 'Bengaluru HQ',
    );
  }

  Map<String, dynamic> toJson() {
    return {
      'id': id,
      'name': name,
      'work_email': email,
      'job_position': jobTitle,
      'job_position_name': jobTitle,
      'department': department,
      'department_name': department,
      'phone': workPhone,
      'manager_name': managerName,
      'avatar_url': avatarUrl,
      'badge_id': badgeId,
      'employee_type': employeeType,
      'status': status,
    };
  }

  EmployeeModel copyWith({
    String? id,
    String? name,
    String? email,
    String? jobTitle,
    String? department,
    String? workPhone,
    String? managerName,
    String? avatarUrl,
    int? timeOffBalance,
    int? activeContractsCount,
    int? attendancesCount,
    int? payslipsCount,
    String? badgeId,
    String? employeeType,
    String? status,
    String? dateOfJoining,
    String? bankName,
    String? bankAccountNumber,
  }) {
    return EmployeeModel(
      id: id ?? this.id,
      name: name ?? this.name,
      email: email ?? this.email,
      jobTitle: jobTitle ?? this.jobTitle,
      department: department ?? this.department,
      workPhone: workPhone ?? this.workPhone,
      managerName: managerName ?? this.managerName,
      avatarUrl: avatarUrl ?? this.avatarUrl,
      timeOffBalance: timeOffBalance ?? this.timeOffBalance,
      activeContractsCount: activeContractsCount ?? this.activeContractsCount,
      attendancesCount: attendancesCount ?? this.attendancesCount,
      payslipsCount: payslipsCount ?? this.payslipsCount,
      badgeId: badgeId ?? this.badgeId,
      employeeType: employeeType ?? this.employeeType,
      status: status ?? this.status,
      dateOfJoining: dateOfJoining ?? this.dateOfJoining,
      bankName: bankName ?? this.bankName,
      bankAccountNumber: bankAccountNumber ?? this.bankAccountNumber,
    );
  }
}

class WorkingScheduleModel {
  final String id;
  final String name;
  final int averageHoursPerWeek;
  final int daysPerWeek;
  final String timezone;

  WorkingScheduleModel({
    required this.id,
    required this.name,
    required this.averageHoursPerWeek,
    required this.daysPerWeek,
    required this.timezone,
  });

  factory WorkingScheduleModel.fromJson(Map<String, dynamic> json) {
    return WorkingScheduleModel(
      id: json['id']?.toString() ?? '',
      name: json['name']?.toString() ?? '',
      averageHoursPerWeek: (json['hours_per_week'] is num) ? (json['hours_per_week'] as num).toInt() : 40,
      daysPerWeek: json['days_per_week'] is int ? json['days_per_week'] : 5,
      timezone: json['timezone']?.toString() ?? 'Asia/Kolkata',
    );
  }
}

class TimeOffTypeModel {
  final String id;
  final String name;
  final String? code;
  final String unit; // 'DAYS' or 'HOURS'
  final bool requiresAllocation;
  final bool requiresApproval;
  final bool isPaid;
  final String color;
  final String? workEntryType;

  TimeOffTypeModel({
    required this.id,
    required this.name,
    this.code,
    this.unit = 'DAYS',
    this.requiresAllocation = true,
    this.requiresApproval = true,
    this.isPaid = true,
    required this.color,
    this.workEntryType,
  });

  factory TimeOffTypeModel.fromJson(Map<String, dynamic> json) {
    return TimeOffTypeModel(
      id: json['id']?.toString() ?? '',
      name: json['name']?.toString() ?? '',
      code: json['code']?.toString(),
      unit: json['unit']?.toString() ?? 'DAYS',
      requiresAllocation: json['requires_allocation'] ?? json['requiresAllocation'] ?? true,
      requiresApproval: json['requires_approval'] ?? json['requiresApproval'] ?? true,
      isPaid: json['is_paid'] ?? true,
      color: json['display_color']?.toString() ?? json['color']?.toString() ?? '#714B67',
      workEntryType: json['work_entry_type']?.toString(),
    );
  }
}

class LeaveAllocationModel {
  final String id;
  final String employeeId;
  final String? employeeName;
  final String? employeeDepartment;
  final String timeoffTypeId;
  final String? timeoffTypeName;
  final double allocatedDays;
  final double takenDays;
  final double remainingDays;
  final int validityYear;
  final String? validityLabel;
  final String status;
  final String? description;

  LeaveAllocationModel({
    required this.id,
    required this.employeeId,
    this.employeeName,
    this.employeeDepartment,
    required this.timeoffTypeId,
    this.timeoffTypeName,
    required this.allocatedDays,
    required this.takenDays,
    required this.remainingDays,
    required this.validityYear,
    this.validityLabel,
    required this.status,
    this.description,
  });

  factory LeaveAllocationModel.fromJson(Map<String, dynamic> json) {
    final alloc = (json['allocated_days'] is num) ? (json['allocated_days'] as num).toDouble() : 0.0;
    final taken = (json['taken_days'] is num) ? (json['taken_days'] as num).toDouble() : 0.0;
    final rem = (json['remaining_days'] is num) ? (json['remaining_days'] as num).toDouble() : (alloc - taken);
    return LeaveAllocationModel(
      id: json['id']?.toString() ?? '',
      employeeId: json['employee_id']?.toString() ?? '',
      employeeName: json['employee_name']?.toString(),
      employeeDepartment: json['employee_department']?.toString() ?? json['department']?.toString(),
      timeoffTypeId: json['timeoff_type_id']?.toString() ?? '',
      timeoffTypeName: json['timeoff_type_name']?.toString(),
      allocatedDays: alloc,
      takenDays: taken,
      remainingDays: rem,
      validityYear: json['validity_year'] is int ? json['validity_year'] : DateTime.now().year,
      validityLabel: json['validity_label']?.toString(),
      status: json['status']?.toString() ?? 'APPROVED',
      description: json['description']?.toString(),
    );
  }
}

class LeaveBalanceModel {
  final String allocationId;
  final String timeoffTypeId;
  final String timeoffTypeName;
  final String displayColor;
  final String unit;
  final double allocatedDays;
  final double takenDays;
  final double remainingDays;
  final int validityYear;

  LeaveBalanceModel({
    required this.allocationId,
    required this.timeoffTypeId,
    required this.timeoffTypeName,
    required this.displayColor,
    required this.unit,
    required this.allocatedDays,
    required this.takenDays,
    required this.remainingDays,
    required this.validityYear,
  });

  factory LeaveBalanceModel.fromJson(Map<String, dynamic> json) {
    return LeaveBalanceModel(
      allocationId: json['allocation_id']?.toString() ?? '',
      timeoffTypeId: json['timeoff_type_id']?.toString() ?? '',
      timeoffTypeName: json['timeoff_type_name']?.toString() ?? '',
      displayColor: json['display_color']?.toString() ?? '#017E84',
      unit: json['unit']?.toString() ?? 'DAYS',
      allocatedDays: (json['allocated_days'] is num) ? (json['allocated_days'] as num).toDouble() : 0.0,
      takenDays: (json['taken_days'] is num) ? (json['taken_days'] as num).toDouble() : 0.0,
      remainingDays: (json['remaining_days'] is num) ? (json['remaining_days'] as num).toDouble() : 0.0,
      validityYear: json['validity_year'] is int ? json['validity_year'] : DateTime.now().year,
    );
  }
}

class AttendanceModel {
  final String id;
  final String? employeeId;
  final String? employeeName;

  /// Raw check-in/out preserved so callers can format, sort or diff without
  /// re-parsing display strings. `checkIn` is always present for a real record.
  final DateTime? checkIn;
  final DateTime? checkOut;

  final String status; // 'PRESENT', 'LATE', 'ABSENT', 'HALF_DAY'
  final double workedHours;
  final double overtimeHours;
  final bool isManualEdit;
  final String? auditNotes;
  final DateTime? createdAt;
  final String? _explicitDateStr;

  AttendanceModel({
    required this.id,
    this.employeeId,
    this.employeeName,
    this.checkIn,
    this.checkOut,
    required this.status,
    required this.workedHours,
    this.overtimeHours = 0.0,
    this.isManualEdit = false,
    this.auditNotes,
    this.createdAt,
    String? dateStr,
  }) : _explicitDateStr = dateStr;

  /// yyyy-MM-dd derived from the check-in instant, or explicit date, or '' when unknown.
  String get dateStr {
    if (_explicitDateStr != null && _explicitDateStr.isNotEmpty) {
      return _explicitDateStr;
    }
    final dt = checkIn;
    if (dt == null) return '';
    return "${dt.year}-${dt.month.toString().padLeft(2, '0')}-${dt.day.toString().padLeft(2, '0')}";
  }

  static String _fmtTime(DateTime dt) {
    final hr = dt.hour % 12 == 0 ? 12 : dt.hour % 12;
    final ampm = dt.hour >= 12 ? 'PM' : 'AM';
    return "${hr.toString().padLeft(2, '0')}:${dt.minute.toString().padLeft(2, '0')} $ampm";
  }

  /// Local-time display of the check-in, or '--' when absent.
  String get checkInTime => checkIn == null ? '--' : _fmtTime(checkIn!.toLocal());

  /// Local-time display of the check-out, or null while the punch is still open.
  String? get checkOutTime => checkOut == null ? null : _fmtTime(checkOut!.toLocal());

  factory AttendanceModel.fromJson(Map<String, dynamic> json) {
    DateTime? parseDt(dynamic v) {
      if (v == null) return null;
      return DateTime.tryParse(v.toString());
    }

    double parseNum(dynamic snake, dynamic camel) {
      if (snake is num) return snake.toDouble();
      if (camel is num) return camel.toDouble();
      return 0.0;
    }

    final rawDate = json['date']?.toString() ?? json['date_str']?.toString() ?? json['dateStr']?.toString();

    return AttendanceModel(
      id: json['id']?.toString() ?? '',
      employeeId: json['employee_id']?.toString() ?? json['employeeId']?.toString(),
      employeeName: json['employee_name']?.toString() ?? json['employeeName']?.toString(),
      checkIn: parseDt(json['check_in'] ?? json['checkIn']),
      checkOut: parseDt(json['check_out'] ?? json['checkOut']),
      status: json['status']?.toString() ?? 'PRESENT',
      workedHours: parseNum(json['worked_hours'], json['workedHours']),
      overtimeHours: parseNum(json['overtime_hours'], json['overtimeHours']),
      isManualEdit: json['is_manual_edit'] == true || json['isManualEdit'] == true,
      auditNotes: json['audit_notes']?.toString() ?? json['auditNotes']?.toString(),
      createdAt: parseDt(json['created_at'] ?? json['createdAt']),
      dateStr: rawDate,
    );
  }
}

class TimeOffRequestModel {
  final String id;
  final String? employeeId;
  final String? employeeName;
  final String? timeoffTypeId;
  final String typeName;
  final String startDate;
  final String endDate;
  final double daysCount;
  final String status; // 'TO_APPROVE', 'APPROVED', 'REFUSED', 'CANCELLED'
  final String reason;
  final String? approverEmployeeId;
  final String? createdAt;

  TimeOffRequestModel({
    required this.id,
    this.employeeId,
    this.employeeName,
    this.timeoffTypeId,
    required this.typeName,
    required this.startDate,
    required this.endDate,
    required this.daysCount,
    required this.status,
    required this.reason,
    this.approverEmployeeId,
    this.createdAt,
  });

  factory TimeOffRequestModel.fromJson(Map<String, dynamic> json) {
    final start = json['start_date']?.toString() ??
        json['date_from']?.toString() ??
        json['startDate']?.toString() ??
        '';
    final end = json['end_date']?.toString() ??
        json['date_to']?.toString() ??
        json['endDate']?.toString() ??
        '';
    final numDays = (json['duration_days'] is num)
        ? (json['duration_days'] as num).toDouble()
        : ((json['number_of_days'] is num)
            ? (json['number_of_days'] as num).toDouble()
            : (json['daysCount'] is num ? (json['daysCount'] as num).toDouble() : 1.0));

    final rsn = json['reason']?.toString() ?? json['name']?.toString() ?? '';

    return TimeOffRequestModel(
      id: json['id']?.toString() ?? '',
      employeeId: json['employee_id']?.toString(),
      employeeName: json['employee_name']?.toString(),
      timeoffTypeId: json['timeoff_type_id']?.toString(),
      typeName: json['timeoff_type_name']?.toString() ??
          json['typeName']?.toString() ??
          json['leaveType']?.toString() ??
          'Paid Time Off',
      startDate: start,
      endDate: end,
      daysCount: numDays,
      status: json['status']?.toString() ?? 'TO_APPROVE',
      reason: rsn,
      approverEmployeeId: json['approver_employee_id']?.toString(),
      createdAt: json['created_at']?.toString(),
    );
  }
}

class ContractModel {
  final String id;
  final String refCode;
  final String employeeName;
  final String department;
  final String startDate;
  final String? endDate;
  final double wageMonthly;
  final String status; // 'RUNNING', 'EXPIRED', 'DRAFT'
  final String? structureName;

  ContractModel({
    required this.id,
    required this.refCode,
    required this.employeeName,
    required this.department,
    required this.startDate,
    this.endDate,
    required this.wageMonthly,
    required this.status,
    this.structureName,
  });

  factory ContractModel.fromJson(Map<String, dynamic> json) {
    return ContractModel(
      id: json['id']?.toString() ?? '',
      refCode: json['reference']?.toString() ?? json['refCode']?.toString() ?? '',
      employeeName: json['employee_name']?.toString() ?? json['employeeName']?.toString() ?? '',
      department: json['department_name']?.toString() ?? json['department']?.toString() ?? 'Finance',
      startDate: json['date_start']?.toString() ?? json['startDate']?.toString() ?? '',
      endDate: json['date_end']?.toString() ?? json['endDate']?.toString(),
      wageMonthly: (json['wage'] is num)
          ? (json['wage'] as num).toDouble()
          : (json['wageMonthly'] is num ? (json['wageMonthly'] as num).toDouble() : 0.0),
      status: json['status']?.toString() ?? 'RUNNING',
      structureName: json['structure_name']?.toString(),
    );
  }
}

class SalaryRuleModel {
  final String id;
  final String? salaryStructureId;
  final String name;
  final String code;
  final int sequence;
  final String category; // 'BASIC', 'ALLOWANCE', 'GROSS', 'DEDUCTION', 'NET'
  final String computationType; // 'FIXED', 'PERCENTAGE', 'PYTHON_CODE'
  final double? fixedAmount;
  final String? percentageBase;
  final double? percentageRate;
  final String? pythonCode;
  final double quantity;
  final bool isActive;
  final String? createdAt;

  SalaryRuleModel({
    required this.id,
    this.salaryStructureId,
    required this.name,
    required this.code,
    required this.sequence,
    required this.category,
    required this.computationType,
    this.fixedAmount,
    this.percentageBase,
    this.percentageRate,
    this.pythonCode,
    this.quantity = 1.0,
    this.isActive = true,
    this.createdAt,
  });

  factory SalaryRuleModel.fromJson(Map<String, dynamic> json) {
    return SalaryRuleModel(
      id: json['id']?.toString() ?? '',
      salaryStructureId: json['salary_structure_id']?.toString() ?? json['salaryStructureId']?.toString(),
      name: json['name']?.toString() ?? '',
      code: json['code']?.toString() ?? '',
      sequence: json['sequence'] is num ? (json['sequence'] as num).toInt() : 10,
      category: json['category']?.toString() ?? 'BASIC',
      computationType: json['computation_type']?.toString() ?? json['computationType']?.toString() ?? 'FIXED',
      fixedAmount: json['fixed_amount'] is num
          ? (json['fixed_amount'] as num).toDouble()
          : (json['fixedAmount'] is num ? (json['fixedAmount'] as num).toDouble() : null),
      percentageBase: json['percentage_base']?.toString() ?? json['percentageBase']?.toString(),
      percentageRate: json['percentage_rate'] is num
          ? (json['percentage_rate'] as num).toDouble()
          : (json['percentageRate'] is num ? (json['percentageRate'] as num).toDouble() : null),
      pythonCode: json['python_code']?.toString() ?? json['pythonCode']?.toString() ?? '',
      quantity: json['quantity'] is num ? (json['quantity'] as num).toDouble() : 1.0,
      isActive: json['is_active'] is bool ? json['is_active'] as bool : (json['isActive'] is bool ? json['isActive'] as bool : true),
      createdAt: json['created_at']?.toString() ?? json['createdAt']?.toString(),
    );
  }
}

class SalaryStructureModel {
  final String id;
  final String name;
  final String code;
  final bool isActive;
  final String? notes;
  final String? createdAt;
  final int ruleCount;
  final int activeRuleCount;
  final int employeeCount;
  final List<SalaryRuleModel> rules;

  SalaryStructureModel({
    required this.id,
    required this.name,
    String? code,
    String? reference,
    String? country,
    List<String>? ruleIds,
    this.isActive = true,
    this.notes,
    this.createdAt,
    this.ruleCount = 0,
    this.activeRuleCount = 0,
    this.employeeCount = 0,
    this.rules = const [],
  }) : code = code ?? reference ?? '';

  String get reference => code;
  String get country => 'India';
  List<String> get ruleIds => rules.map((r) => r.id).toList();

  factory SalaryStructureModel.fromJson(Map<String, dynamic> json) {
    final rawRules = json['rules'] as List? ?? [];
    final parsedRules = rawRules
        .whereType<Map<String, dynamic>>()
        .map((r) => SalaryRuleModel.fromJson(r))
        .toList();

    return SalaryStructureModel(
      id: json['id']?.toString() ?? '',
      name: json['name']?.toString() ?? '',
      code: json['code']?.toString() ?? json['reference']?.toString() ?? '',
      isActive: json['is_active'] is bool ? json['is_active'] as bool : (json['isActive'] is bool ? json['isActive'] as bool : true),
      notes: json['notes']?.toString(),
      createdAt: json['created_at']?.toString() ?? json['createdAt']?.toString(),
      ruleCount: json['rule_count'] is num ? (json['rule_count'] as num).toInt() : (json['ruleCount'] is num ? (json['ruleCount'] as num).toInt() : parsedRules.length),
      activeRuleCount: json['active_rule_count'] is num
          ? (json['active_rule_count'] as num).toInt()
          : (json['activeRuleCount'] is num ? (json['activeRuleCount'] as num).toInt() : parsedRules.where((r) => r.isActive).length),
      employeeCount: json['employee_count'] is num
          ? (json['employee_count'] as num).toInt()
          : (json['employeeCount'] is num ? (json['employeeCount'] as num).toInt() : 0),
      rules: parsedRules,
    );
  }
}

class RuleSimulationLineModel {
  final String ruleName;
  final String ruleCode;
  final String category;
  final int sequence;
  final double amount;
  final String computationType;
  final String explanation;

  RuleSimulationLineModel({
    required this.ruleName,
    required this.ruleCode,
    required this.category,
    required this.sequence,
    required this.amount,
    required this.computationType,
    required this.explanation,
  });

  factory RuleSimulationLineModel.fromJson(Map<String, dynamic> json) {
    return RuleSimulationLineModel(
      ruleName: json['rule_name']?.toString() ?? json['ruleName']?.toString() ?? '',
      ruleCode: json['rule_code']?.toString() ?? json['ruleCode']?.toString() ?? '',
      category: json['category']?.toString() ?? 'BASIC',
      sequence: json['sequence'] is num ? (json['sequence'] as num).toInt() : 10,
      amount: json['amount'] is num ? (json['amount'] as num).toDouble() : 0.0,
      computationType: json['computation_type']?.toString() ?? json['computationType']?.toString() ?? 'FIXED',
      explanation: json['explanation']?.toString() ?? '',
    );
  }
}

class RuleSimulationResponseModel {
  final String salaryStructureId;
  final String salaryStructureName;
  final double wageMonthly;
  final double basic;
  final double allowances;
  final double gross;
  final double deductions;
  final double net;
  final List<RuleSimulationLineModel> lines;

  RuleSimulationResponseModel({
    required this.salaryStructureId,
    required this.salaryStructureName,
    required this.wageMonthly,
    required this.basic,
    required this.allowances,
    required this.gross,
    required this.deductions,
    required this.net,
    required this.lines,
  });

  factory RuleSimulationResponseModel.fromJson(Map<String, dynamic> json) {
    final rawLines = json['lines'] as List? ?? [];
    final parsedLines = rawLines
        .whereType<Map<String, dynamic>>()
        .map((l) => RuleSimulationLineModel.fromJson(l))
        .toList();

    return RuleSimulationResponseModel(
      salaryStructureId: json['salary_structure_id']?.toString() ?? json['salaryStructureId']?.toString() ?? '',
      salaryStructureName: json['salary_structure_name']?.toString() ?? json['salaryStructureName']?.toString() ?? '',
      wageMonthly: json['wage_monthly'] is num ? (json['wage_monthly'] as num).toDouble() : 0.0,
      basic: json['basic'] is num ? (json['basic'] as num).toDouble() : 0.0,
      allowances: json['allowances'] is num ? (json['allowances'] as num).toDouble() : 0.0,
      gross: json['gross'] is num ? (json['gross'] as num).toDouble() : 0.0,
      deductions: json['deductions'] is num ? (json['deductions'] as num).toDouble() : 0.0,
      net: json['net'] is num ? (json['net'] as num).toDouble() : 0.0,
      lines: parsedLines,
    );
  }
}

class PythonRuleValidationResponseModel {
  final bool valid;
  final String message;
  final double? probeResult;

  PythonRuleValidationResponseModel({
    required this.valid,
    required this.message,
    this.probeResult,
  });

  factory PythonRuleValidationResponseModel.fromJson(Map<String, dynamic> json) {
    return PythonRuleValidationResponseModel(
      valid: json['valid'] == true,
      message: json['message']?.toString() ?? '',
      probeResult: json['probe_result'] is num ? (json['probe_result'] as num).toDouble() : null,
    );
  }
}

class PayslipLineModel {
  final String ruleName;
  final String ruleCode;
  final String category;
  final double amount;

  PayslipLineModel({
    required this.ruleName,
    required this.ruleCode,
    required this.category,
    required this.amount,
  });

  static double safeDouble(dynamic val, [double defaultVal = 0.0]) {
    if (val == null) return defaultVal;
    if (val is num) return val.toDouble();
    final parsed = double.tryParse(val.toString().replaceAll(RegExp(r'[^\d.]'), ''));
    return parsed ?? defaultVal;
  }

  factory PayslipLineModel.fromJson(Map<String, dynamic> json) {
    return PayslipLineModel(
      ruleName: json['name']?.toString() ?? json['ruleName']?.toString() ?? '',
      ruleCode: json['code']?.toString() ?? json['ruleCode']?.toString() ?? '',
      category: json['category']?.toString() ?? 'BASIC',
      amount: safeDouble(json['total'] ?? json['amount'], 0.0),
    );
  }
}

class PayslipModel {
  final String id;
  final String refCode;
  final String employeeName;
  final String periodStart;
  final String periodEnd;
  final double workedDays;
  final double workedHours;
  final double overtimeHours;
  final double scheduledHours;
  final double overtimePay;
  final double extraDays;
  final double extraDaysPay;
  final double contractMonthlyWage;
  final double basicAmount;
  final double grossAmount;
  final double netAmount;
  final String status; // 'DONE', 'DRAFT', 'CANCELLED'
  final List<PayslipLineModel> lines;
  final double? _hourlyRate;
  final double? _overtimeRate;

  static double safeDouble(dynamic val, [double defaultVal = 0.0]) {
    if (val == null) return defaultVal;
    if (val is num) return val.toDouble();
    final parsed = double.tryParse(val.toString().replaceAll(RegExp(r'[^\d.]'), ''));
    return parsed ?? defaultVal;
  }

  double get safeContractMonthlyWage => safeDouble(contractMonthlyWage, 85000.0);
  double get safeScheduledHours => safeDouble(scheduledHours, 176.0);
  double get safeOvertimeHours => safeDouble(overtimeHours, 0.0);
  double get safeOvertimePay => safeDouble(overtimePay, 0.0);
  double get safeExtraDays => safeDouble(extraDays, 0.0);
  double get safeExtraDaysPay => safeDouble(extraDaysPay, 0.0);
  double get safeWorkedDays => safeDouble(workedDays, 22.0);
  double get safeWorkedHours => safeDouble(workedHours, 176.0);
  double get safeBasicAmount => safeDouble(basicAmount, 50000.0);
  double get safeGrossAmount => safeDouble(grossAmount, 80000.0);
  double get safeNetAmount => safeDouble(netAmount, 75000.0);

  double get hourlyRate => _hourlyRate ?? (safeContractMonthlyWage / (safeScheduledHours > 0 ? safeScheduledHours : 176.0));
  double get overtimeRate => _overtimeRate ?? (hourlyRate * 1.5);

  PayslipModel({
    required this.id,
    required this.refCode,
    required this.employeeName,
    required this.periodStart,
    required this.periodEnd,
    this.workedDays = 22.0,
    this.workedHours = 176.0,
    this.overtimeHours = 0.0,
    this.scheduledHours = 176.0,
    this.overtimePay = 0.0,
    this.extraDays = 0.0,
    this.extraDaysPay = 0.0,
    this.contractMonthlyWage = 85000.0,
    double? hourlyRate,
    double? overtimeRate,
    this.basicAmount = 0.0,
    required this.grossAmount,
    required this.netAmount,
    required this.status,
    required this.lines,
  })  : _hourlyRate = hourlyRate,
        _overtimeRate = overtimeRate;

  static double? parseCurrency(dynamic val) {
    if (val == null) return null;
    if (val is num) return val.toDouble();
    final s = val.toString().replaceAll(RegExp(r'[^\d.]'), '');
    return double.tryParse(s);
  }

  factory PayslipModel.fromJson(Map<String, dynamic> json) {
    final rawLines = json['lines'] as List? ?? [];
    final parsedLines = rawLines.map((l) => PayslipLineModel.fromJson(l as Map<String, dynamic>)).toList();

    double otPay = 0.0;
    double extDaysPay = 0.0;
    for (final l in parsedLines) {
      if (l.ruleCode == 'OT' || l.ruleCode == 'OVERTIME') {
        otPay = l.amount;
      } else if (l.ruleCode == 'EXT_DAYS' || l.ruleCode == 'EXTRA_DAYS') {
        extDaysPay = l.amount;
      }
    }

    final contractWage = safeDouble(json['contract_wage'] ?? json['contractMonthlyWage'] ?? json['baseWage'] ?? json['wageMonthly'], 85000.0);
    final schedHours = safeDouble(json['scheduled_hours'] ?? json['scheduledHours'], 176.0);
    final hRate = safeDouble(json['hourly_rate'] ?? json['hourlyRate'], contractWage / (schedHours > 0 ? schedHours : 176.0));
    final otRate = safeDouble(json['overtime_rate'] ?? json['overtimeRate'], hRate * 1.5);
    final otHours = safeDouble(json['overtime_hours'] ?? json['overtimeHours'], 0.0);

    if (otPay == 0.0) {
      otPay = safeDouble(json['overtime_pay'] ?? json['overtimePay'], otHours > 0 ? double.parse((otHours * otRate).toStringAsFixed(2)) : 0.0);
    }

    final extraD = safeDouble(json['extra_days'] ?? json['extraDays'], 0.0);
    if (extDaysPay == 0.0) {
      final dailyRate = contractWage / 22.0;
      extDaysPay = safeDouble(json['extra_days_pay'] ?? json['extraDaysPay'], extraD > 0 ? double.parse((extraD * dailyRate).toStringAsFixed(2)) : 0.0);
    }

    final parsedEmpName = json['employee_name']?.toString() ??
        json['employeeName']?.toString() ??
        json['name']?.toString() ??
        json['empName']?.toString() ??
        json['emp_name']?.toString() ??
        (json['employee'] is String ? json['employee'].toString() : null) ??
        (json['employee'] is Map ? json['employee']['name']?.toString() : null) ??
        (json['employee_id'] is List && (json['employee_id'] as List).length > 1 ? (json['employee_id'] as List)[1].toString() : null) ??
        '';

    return PayslipModel(
      id: json['id']?.toString() ?? '',
      refCode: json['reference_code']?.toString() ?? json['number']?.toString() ?? json['refCode']?.toString() ?? json['refNo']?.toString() ?? '',
      employeeName: parsedEmpName,
      periodStart: json['date_start']?.toString() ?? json['date_from']?.toString() ?? json['periodStart']?.toString() ?? '',
      periodEnd: json['date_end']?.toString() ?? json['date_to']?.toString() ?? json['periodEnd']?.toString() ?? '',
      workedDays: safeDouble(json['worked_days'] ?? json['workedDays'], 22.0),
      workedHours: safeDouble(json['worked_hours'] ?? json['workedHours'], 176.0),
      overtimeHours: otHours,
      scheduledHours: schedHours,
      overtimePay: otPay,
      extraDays: extraD,
      extraDaysPay: extDaysPay,
      contractMonthlyWage: contractWage,
      hourlyRate: hRate,
      overtimeRate: otRate,
      basicAmount: safeDouble(json['basic_amount'] ?? json['basic'], 50000.0),
      grossAmount: safeDouble(json['gross_amount'] ?? json['gross_wage'] ?? json['grossAmount'] ?? json['gross'] ?? json['grossPayout'], 80000.0),
      netAmount: safeDouble(json['net_amount'] ?? json['net_wage'] ?? json['netAmount'] ?? json['netPayout'] ?? json['net'], 75000.0),
      status: json['status']?.toString() ?? 'DONE',
      lines: parsedLines,
    );
  }

  PayslipModel copyWith({
    String? id,
    String? refCode,
    String? employeeName,
    String? periodStart,
    String? periodEnd,
    double? workedDays,
    double? workedHours,
    double? overtimeHours,
    double? scheduledHours,
    double? overtimePay,
    double? extraDays,
    double? extraDaysPay,
    double? contractMonthlyWage,
    double? hourlyRate,
    double? overtimeRate,
    double? basicAmount,
    double? grossAmount,
    double? netAmount,
    String? status,
    List<PayslipLineModel>? lines,
  }) {
    return PayslipModel(
      id: id ?? this.id,
      refCode: refCode ?? this.refCode,
      employeeName: employeeName ?? this.employeeName,
      periodStart: periodStart ?? this.periodStart,
      periodEnd: periodEnd ?? this.periodEnd,
      workedDays: workedDays ?? this.workedDays,
      workedHours: workedHours ?? this.workedHours,
      overtimeHours: overtimeHours ?? this.overtimeHours,
      scheduledHours: scheduledHours ?? this.scheduledHours,
      overtimePay: overtimePay ?? this.overtimePay,
      extraDays: extraDays ?? this.extraDays,
      extraDaysPay: extraDaysPay ?? this.extraDaysPay,
      contractMonthlyWage: contractMonthlyWage ?? this.contractMonthlyWage,
      hourlyRate: hourlyRate ?? this.hourlyRate,
      overtimeRate: overtimeRate ?? this.overtimeRate,
      basicAmount: basicAmount ?? this.basicAmount,
      grossAmount: grossAmount ?? this.grossAmount,
      netAmount: netAmount ?? this.netAmount,
      status: status ?? this.status,
      lines: lines ?? this.lines,
    );
  }
}

class EscalationTicketModel {
  final String id;
  final String ticketNo;
  final String questionText;
  final String category;
  final String status; // 'OPEN', 'ASSIGNED', 'ANSWERED', 'CLOSED'
  final String priority;
  final String slaDueAt;
  final String? answerText;
  final String? answeredBy;
  final double? retrievalConfidence;

  EscalationTicketModel({
    required this.id,
    required this.ticketNo,
    required this.questionText,
    required this.category,
    required this.status,
    required this.priority,
    required this.slaDueAt,
    this.answerText,
    this.answeredBy,
    this.retrievalConfidence,
  });

  factory EscalationTicketModel.fromJson(Map<String, dynamic> json) {
    return EscalationTicketModel(
      id: json['id']?.toString() ?? '',
      ticketNo: json['ticket_no']?.toString() ?? json['ticketNo']?.toString() ?? '',
      questionText: json['question_text']?.toString() ?? json['questionText']?.toString() ?? '',
      category: json['category']?.toString() ?? 'OTHER',
      status: json['status']?.toString() ?? 'OPEN',
      priority: json['priority']?.toString() ?? 'NORMAL',
      slaDueAt: json['sla_due_at']?.toString() ?? json['slaDueAt']?.toString() ?? '',
      answerText: json['answer_text']?.toString() ?? json['answerText']?.toString(),
      answeredBy: json['answered_by_name']?.toString() ?? json['answeredBy']?.toString(),
      retrievalConfidence: json['retrieval_confidence'] is num
          ? (json['retrieval_confidence'] as num).toDouble()
          : (json['retrievalConfidence'] is num ? (json['retrievalConfidence'] as num).toDouble() : null),
    );
  }
}

class PayrollAssignmentModel {
  final String employeeId;
  final String badgeId;
  final String employeeName;
  final String? departmentId;
  final String? departmentName;
  final String? jobPositionId;
  final String? jobPositionName;
  final String? contractId;
  final String? contractReference;
  final String? contractStatus;
  final double? wageMonthly;
  final String? salaryStructureId;
  final String? salaryStructureName;
  final String? dateStart;
  final String? dateEnd;

  PayrollAssignmentModel({
    required this.employeeId,
    required this.badgeId,
    required this.employeeName,
    this.departmentId,
    this.departmentName,
    this.jobPositionId,
    this.jobPositionName,
    this.contractId,
    this.contractReference,
    this.contractStatus,
    this.wageMonthly,
    this.salaryStructureId,
    this.salaryStructureName,
    this.dateStart,
    this.dateEnd,
  });

  factory PayrollAssignmentModel.fromJson(Map<String, dynamic> json) {
    return PayrollAssignmentModel(
      employeeId: json['employee_id']?.toString() ?? json['employeeId']?.toString() ?? '',
      badgeId: json['badge_id']?.toString() ?? json['badgeId']?.toString() ?? '',
      employeeName: json['employee_name']?.toString() ?? json['employeeName']?.toString() ?? '',
      departmentId: json['department_id']?.toString() ?? json['departmentId']?.toString(),
      departmentName: json['department_name']?.toString() ?? json['departmentName']?.toString(),
      jobPositionId: json['job_position_id']?.toString() ?? json['jobPositionId']?.toString(),
      jobPositionName: json['job_position_name']?.toString() ?? json['jobPositionName']?.toString(),
      contractId: json['contract_id']?.toString() ?? json['contractId']?.toString(),
      contractReference: json['contract_reference']?.toString() ?? json['contractReference']?.toString(),
      contractStatus: json['contract_status']?.toString() ?? json['contractStatus']?.toString(),
      wageMonthly: (json['wage_monthly'] is num)
          ? (json['wage_monthly'] as num).toDouble()
          : (json['wageMonthly'] is num ? (json['wageMonthly'] as num).toDouble() : null),
      salaryStructureId: json['salary_structure_id']?.toString() ?? json['salaryStructureId']?.toString(),
      salaryStructureName: json['salary_structure_name']?.toString() ?? json['salaryStructureName']?.toString(),
      dateStart: json['date_start']?.toString() ?? json['dateStart']?.toString(),
      dateEnd: json['date_end']?.toString() ?? json['dateEnd']?.toString(),
    );
  }
}

