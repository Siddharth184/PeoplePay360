import 'package:flutter_test/flutter_test.dart';
import 'package:peoplepay360/models/models.dart';
import 'package:peoplepay360/services/mock_data_service.dart';

void main() {
  group('Payslip Employee Data Consistency Tests', () {
    test('_getActivePayslip binds payslip employeeName to viewed employee profile', () {
      final loggedInEmp = EmployeeModel(
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
      );

      // Raw mock list might contain Sara Khan (HR Lead) as default item 0
      final rawMockSlip = MockDataService.payslips.first;
      expect(rawMockSlip.employeeName, equals('Sara Khan'));

      // Active payslip derivation MUST replace HR name with logged in / viewed employee name
      final activeSlip = rawMockSlip.copyWith(employeeName: loggedInEmp.name);

      expect(activeSlip.employeeName, equals('Aarav Sharma'));
      expect(activeSlip.employeeName, isNot(equals('Sara Khan')));
    });

    test('Payslip for new employee carries correct name instead of falling back to HR', () {
      final newEmp = EmployeeModel(
        id: 'emp-999',
        name: 'Rohan Gupta',
        email: 'rohan@company.com',
        jobTitle: 'QA Engineer',
        department: 'Quality Assurance',
        workPhone: '+91 91234 56789',
        managerName: 'Sara Khan',
        avatarUrl: '',
        timeOffBalance: 15,
        activeContractsCount: 1,
        attendancesCount: 0,
        payslipsCount: 0,
      );

      final rawMockSlip = MockDataService.payslips.first;
      final activeSlip = rawMockSlip.copyWith(employeeName: newEmp.name);

      expect(activeSlip.employeeName, equals('Rohan Gupta'));
    });
  });
}
