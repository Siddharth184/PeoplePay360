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
  });
}
