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
  final String code;
  final bool requiresApproval;
  final String color;

  TimeOffTypeModel({
    required this.id,
    required this.name,
    required this.code,
    required this.requiresApproval,
    required this.color,
  });

  factory TimeOffTypeModel.fromJson(Map<String, dynamic> json) {
    return TimeOffTypeModel(
      id: json['id']?.toString() ?? '',
      name: json['name']?.toString() ?? '',
      code: json['code']?.toString() ?? '',
      requiresApproval: json['requires_approval'] ?? true,
      color: json['color']?.toString() ?? '#714B67',
    );
  }
}

class AttendanceModel {
  final String id;
  final String dateStr;
  final String checkInTime;
  final String? checkOutTime;
  final String status; // 'PRESENT', 'LATE', 'ABSENT', 'ON_LEAVE'
  final double workedHours;
  final String? employeeName;
  final String? employeeId;

  AttendanceModel({
    required this.id,
    required this.dateStr,
    required this.checkInTime,
    this.checkOutTime,
    required this.status,
    required this.workedHours,
    this.employeeName,
    this.employeeId,
  });

  factory AttendanceModel.fromJson(Map<String, dynamic> json) {
    String inTime = '--';
    String? outTime;
    String dateStr = '';

    if (json['check_in'] != null) {
      final raw = json['check_in'].toString();
      final dt = DateTime.tryParse(raw);
      if (dt != null) {
        dateStr = "${dt.year}-${dt.month.toString().padLeft(2, '0')}-${dt.day.toString().padLeft(2, '0')}";
        final hr = dt.hour % 12 == 0 ? 12 : dt.hour % 12;
        final ampm = dt.hour >= 12 ? 'PM' : 'AM';
        inTime = "${hr.toString().padLeft(2, '0')}:${dt.minute.toString().padLeft(2, '0')} $ampm";
      } else {
        inTime = raw;
      }
    } else if (json['checkInTime'] != null) {
      inTime = json['checkInTime'].toString();
      dateStr = json['dateStr']?.toString() ?? '';
    }

    if (json['check_out'] != null) {
      final raw = json['check_out'].toString();
      final dt = DateTime.tryParse(raw);
      if (dt != null) {
        final hr = dt.hour % 12 == 0 ? 12 : dt.hour % 12;
        final ampm = dt.hour >= 12 ? 'PM' : 'AM';
        outTime = "${hr.toString().padLeft(2, '0')}:${dt.minute.toString().padLeft(2, '0')} $ampm";
      } else {
        outTime = raw;
      }
    } else if (json['checkOutTime'] != null) {
      outTime = json['checkOutTime'].toString();
    }

    return AttendanceModel(
      id: json['id']?.toString() ?? '',
      dateStr: dateStr.isNotEmpty ? dateStr : (json['dateStr']?.toString() ?? '2026-09-05'),
      checkInTime: inTime,
      checkOutTime: outTime,
      status: json['status']?.toString() ?? 'PRESENT',
      workedHours: (json['worked_hours'] is num)
          ? (json['worked_hours'] as num).toDouble()
          : (json['workedHours'] is num ? (json['workedHours'] as num).toDouble() : 0.0),
      employeeName: json['employee_name']?.toString(),
      employeeId: json['employee_id']?.toString(),
    );
  }
}

class TimeOffRequestModel {
  final String id;
  final String typeName;
  final String startDate;
  final String endDate;
  final double daysCount;
  final String status; // 'APPROVED', 'PENDING', 'REFUSED'
  final String reason;
  final String? employeeName;

  TimeOffRequestModel({
    required this.id,
    required this.typeName,
    required this.startDate,
    required this.endDate,
    required this.daysCount,
    required this.status,
    required this.reason,
    this.employeeName,
  });

  factory TimeOffRequestModel.fromJson(Map<String, dynamic> json) {
    return TimeOffRequestModel(
      id: json['id']?.toString() ?? '',
      typeName: json['timeoff_type_name']?.toString() ?? json['typeName']?.toString() ?? 'Paid Time Off',
      startDate: json['date_from']?.toString() ?? json['startDate']?.toString() ?? '',
      endDate: json['date_to']?.toString() ?? json['endDate']?.toString() ?? '',
      daysCount: (json['number_of_days'] is num)
          ? (json['number_of_days'] as num).toDouble()
          : (json['daysCount'] is num ? (json['daysCount'] as num).toDouble() : 1.0),
      status: json['status']?.toString() ?? 'PENDING',
      reason: json['name']?.toString() ?? json['reason']?.toString() ?? 'Time off request',
      employeeName: json['employee_name']?.toString(),
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
  final String name;
  final String code;
  final int sequence;
  final String category; // 'BASIC', 'ALLOWANCE', 'GROSS', 'DEDUCTION', 'NET'
  final String computationType; // 'FIXED', 'PERCENTAGE', 'PYTHON_CODE'
  final String pythonCode;
  final double? fixedAmount;
  final double? percentageRate;
  final String? percentageBase;

  SalaryRuleModel({
    required this.id,
    required this.name,
    required this.code,
    required this.sequence,
    required this.category,
    required this.computationType,
    required this.pythonCode,
    this.fixedAmount,
    this.percentageRate,
    this.percentageBase,
  });

  factory SalaryRuleModel.fromJson(Map<String, dynamic> json) {
    return SalaryRuleModel(
      id: json['id']?.toString() ?? '',
      name: json['name']?.toString() ?? '',
      code: json['code']?.toString() ?? '',
      sequence: json['sequence'] is int ? json['sequence'] : 10,
      category: json['category']?.toString() ?? 'BASIC',
      computationType: json['computation_type']?.toString() ?? 'FIXED',
      pythonCode: json['python_code']?.toString() ?? '',
      fixedAmount: json['fixed_amount'] is num ? (json['fixed_amount'] as num).toDouble() : null,
      percentageRate: json['percentage_rate'] is num ? (json['percentage_rate'] as num).toDouble() : null,
      percentageBase: json['percentage_base']?.toString(),
    );
  }
}

class SalaryStructureModel {
  final String id;
  final String name;
  final String reference;
  final String country;
  final List<String> ruleIds;

  SalaryStructureModel({
    required this.id,
    required this.name,
    required this.reference,
    required this.country,
    required this.ruleIds,
  });

  factory SalaryStructureModel.fromJson(Map<String, dynamic> json) {
    return SalaryStructureModel(
      id: json['id']?.toString() ?? '',
      name: json['name']?.toString() ?? '',
      reference: json['code']?.toString() ?? json['reference']?.toString() ?? '',
      country: 'India',
      ruleIds: (json['rules'] is List)
          ? (json['rules'] as List).map((r) => r['id']?.toString() ?? '').toList()
          : [],
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

  factory PayslipLineModel.fromJson(Map<String, dynamic> json) {
    return PayslipLineModel(
      ruleName: json['name']?.toString() ?? json['ruleName']?.toString() ?? '',
      ruleCode: json['code']?.toString() ?? json['ruleCode']?.toString() ?? '',
      category: json['category']?.toString() ?? 'BASIC',
      amount: (json['total'] is num)
          ? (json['total'] as num).toDouble()
          : (json['amount'] is num ? (json['amount'] as num).toDouble() : 0.0),
    );
  }
}

class PayslipModel {
  final String id;
  final String refCode;
  final String employeeName;
  final String periodStart;
  final String periodEnd;
  final double grossAmount;
  final double netAmount;
  final String status; // 'DONE', 'DRAFT', 'CANCELLED'
  final List<PayslipLineModel> lines;

  PayslipModel({
    required this.id,
    required this.refCode,
    required this.employeeName,
    required this.periodStart,
    required this.periodEnd,
    required this.grossAmount,
    required this.netAmount,
    required this.status,
    required this.lines,
  });

  factory PayslipModel.fromJson(Map<String, dynamic> json) {
    final rawLines = json['lines'] as List? ?? [];
    return PayslipModel(
      id: json['id']?.toString() ?? '',
      refCode: json['number']?.toString() ?? json['refCode']?.toString() ?? '',
      employeeName: json['employee_name']?.toString() ?? json['employeeName']?.toString() ?? '',
      periodStart: json['date_from']?.toString() ?? json['periodStart']?.toString() ?? '',
      periodEnd: json['date_to']?.toString() ?? json['periodEnd']?.toString() ?? '',
      grossAmount: (json['gross_wage'] is num)
          ? (json['gross_wage'] as num).toDouble()
          : (json['grossAmount'] is num ? (json['grossAmount'] as num).toDouble() : 0.0),
      netAmount: (json['net_wage'] is num)
          ? (json['net_wage'] as num).toDouble()
          : (json['netAmount'] is num ? (json['netAmount'] as num).toDouble() : 0.0),
      status: json['status']?.toString() ?? 'DONE',
      lines: rawLines.map((l) => PayslipLineModel.fromJson(l as Map<String, dynamic>)).toList(),
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
