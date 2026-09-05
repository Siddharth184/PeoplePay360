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
  });
}

class AttendanceModel {
  final String id;
  final String dateStr;
  final String checkInTime;
  final String? checkOutTime;
  final String status; // 'PRESENT', 'LATE', 'ABSENT', 'ON_LEAVE'
  final double workedHours;

  AttendanceModel({
    required this.id,
    required this.dateStr,
    required this.checkInTime,
    this.checkOutTime,
    required this.status,
    required this.workedHours,
  });
}

class TimeOffRequestModel {
  final String id;
  final String typeName;
  final String startDate;
  final String endDate;
  final double daysCount;
  final String status; // 'APPROVED', 'PENDING', 'REFUSED'
  final String reason;

  TimeOffRequestModel({
    required this.id,
    required this.typeName,
    required this.startDate,
    required this.endDate,
    required this.daysCount,
    required this.status,
    required this.reason,
  });
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

  ContractModel({
    required this.id,
    required this.refCode,
    required this.employeeName,
    required this.department,
    required this.startDate,
    this.endDate,
    required this.wageMonthly,
    required this.status,
  });
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
}
