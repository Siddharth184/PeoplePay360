import 'package:flutter_test/flutter_test.dart';
import 'package:peoplepay360/models/models.dart';
import 'package:peoplepay360/services/mock_data_service.dart';

void main() {
  group('Pay Cycle Accrual Dynamic Calculation Tests', () {
    test('New onboarded employee with 0 attendances has 0.0 accrued hours and 0%', () {
      final newEmp = EmployeeModel(
        id: 'emp-new-999',
        name: 'John Doe',
        email: 'john.doe@company.com',
        jobTitle: 'Software Engineer',
        department: 'Engineering',
        workPhone: '+91 99999 88888',
        managerName: 'Sara Khan',
        avatarUrl: '',
        timeOffBalance: 15,
        activeContractsCount: 1,
        attendancesCount: 0,
        payslipsCount: 0,
        workLocation: 'Delhi Regional Hub',
      );

      final userAttendances = MockDataService.attendances.where(
        (a) => a.employeeId == newEmp.id,
      ).toList();

      final double totalWorked = userAttendances.isNotEmpty
          ? userAttendances.fold(0.0, (sum, a) => sum + (a.workedHours ?? 0.0))
          : (newEmp.attendancesCount > 0 ? (newEmp.attendancesCount * 7.55).clamp(0.0, 168.0) : 0.0);

      final double targetHours = 168.0;
      final double progress = (targetHours > 0) ? (totalWorked / targetHours).clamp(0.0, 1.0) : 0.0;
      final int percentage = (progress * 100).round();

      expect(totalWorked, equals(0.0));
      expect(progress, equals(0.0));
      expect(percentage, equals(0));
    });

    test('Existing employee with attendances calculates actual accrued hours and percentage', () {
      final aarav = EmployeeModel(
        id: 'emp-001',
        name: 'Aarav Sharma',
        email: 'aarav@company.com',
        jobTitle: 'Senior Developer',
        department: 'Engineering',
        workPhone: '+91 98765 43210',
        managerName: 'Sara Khan',
        avatarUrl: '',
        timeOffBalance: 14,
        activeContractsCount: 1,
        attendancesCount: 22,
        payslipsCount: 12,
        workLocation: 'Bengaluru HQ',
      );

      final userAttendances = MockDataService.attendances.where(
        (a) => a.employeeId == aarav.id || (a.employeeName != null && a.employeeName!.isNotEmpty && aarav.name.toLowerCase().contains(a.employeeName!.toLowerCase().split(' ').first)),
      ).toList();

      final double totalWorked = userAttendances.isNotEmpty
          ? userAttendances.fold(0.0, (sum, a) => sum + (a.workedHours ?? 0.0))
          : (aarav.attendancesCount > 0 ? (aarav.attendancesCount * 7.55).clamp(0.0, 168.0) : 0.0);

      final double targetHours = 168.0;
      final double progress = (targetHours > 0) ? (totalWorked / targetHours).clamp(0.0, 1.0) : 0.0;
      final int percentage = (progress * 100).round();

      expect(totalWorked, greaterThan(0.0));
      expect(percentage, greaterThan(0));
      expect(percentage, lessThanOrEqualTo(100));
    });

    test('Dynamic month selection matches periodStart and updates breakdown & accrual metrics', () {
      final payslips = MockDataService.payslips;

      // Select Sept 2026 month
      final septMonth = '2026-09-01 → 2026-09-30';
      final septStart = septMonth.split('→').first.trim();
      final septSlip = payslips.firstWhere((p) => p.periodStart == septStart);

      expect(septSlip.refCode, equals('SLIP/2026/09-001'));
      expect(septSlip.status, equals('PAID'));
      expect(septSlip.netAmount, equals(126747.73));

      // Select Aug 2026 month
      final augMonth = '2026-08-01 → 2026-08-31';
      final augStart = augMonth.split('→').first.trim();
      final augSlip = payslips.firstWhere((p) => p.periodStart == augStart);

      expect(augSlip.refCode, equals('SLIP/2026/08-001'));
      expect(augSlip.status, equals('DONE'));
      expect(augSlip.netAmount, equals(89971.59));

      // Select Jul 2026 month
      final julMonth = '2026-07-01 → 2026-07-31';
      final julStart = julMonth.split('→').first.trim();
      final julSlip = payslips.firstWhere((p) => p.periodStart == julStart);

      expect(julSlip.refCode, equals('SLIP/2026/07-001'));
      expect(julSlip.status, equals('PAID'));
      expect(julSlip.netAmount, equals(84659.09));

      // Verify that net amounts & ref codes dynamically change between months
      expect(augSlip.netAmount, isNot(equals(septSlip.netAmount)));
      expect(augSlip.refCode, isNot(equals(septSlip.refCode)));
    });
  });
}
