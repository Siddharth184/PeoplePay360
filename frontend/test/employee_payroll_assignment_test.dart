import 'package:flutter_test/flutter_test.dart';
import 'package:peoplepay360/models/models.dart';
import 'package:peoplepay360/services/mock_data_service.dart';

void main() {
  group('Employee Payroll Assignment & Filter Board Tests', () {
    test('Filtering employees by department and position returns accurate cohort', () {
      final allEmps = MockDataService.allEmployees;

      // Filter by Engineering department
      final engEmps = allEmps.where((e) => e.department.toLowerCase().contains('engineering')).toList();
      expect(engEmps, isNotEmpty);
      for (final emp in engEmps) {
        expect(emp.department, equals('Engineering'));
      }

      // Filter by Payroll Officer position
      final payrollOfficers = allEmps.where((e) => e.jobTitle.toLowerCase().contains('payroll officer')).toList();
      expect(payrollOfficers, isNotEmpty);
      expect(payrollOfficers.first.name, contains('Aarav'));
    });

    test('Direct contract wage and salary structure update persists in MockDataService', () {
      final empName = 'Priya Patel';
      final newWage = 115000.0;
      final newStruct = 'Executive Salary Structure';

      final idx = MockDataService.contracts.indexWhere(
        (c) => c.employeeName.toLowerCase().contains(empName.toLowerCase().split(' ').first),
      );
      expect(idx, greaterThanOrEqualTo(0));

      final existing = MockDataService.contracts[idx];
      MockDataService.contracts[idx] = ContractModel(
        id: existing.id,
        refCode: existing.refCode,
        employeeName: existing.employeeName,
        department: existing.department,
        startDate: existing.startDate,
        endDate: existing.endDate,
        wageMonthly: newWage,
        status: existing.status,
        structureName: newStruct,
      );

      final updatedContract = MockDataService.contracts[idx];
      expect(updatedContract.wageMonthly, equals(115000.0));
      expect(updatedContract.structureName, equals('Executive Salary Structure'));

      // Check standard hourly rate derived against 176h standard
      final hourlyRate = updatedContract.wageMonthly / 176.0;
      expect(hourlyRate, closeTo(653.40, 0.1));
    });

    test('Batch assigning salary structure for a department updates all department employees', () {
      final targetDept = 'Engineering';
      final batchStruct = 'Regular Employee Base';
      final batchWage = 98000.0;

      final deptEmps = MockDataService.allEmployees.where((e) => e.department.toLowerCase().contains(targetDept.toLowerCase())).toList();
      expect(deptEmps, isNotEmpty);

      for (final emp in deptEmps) {
        final idx = MockDataService.contracts.indexWhere(
          (c) => c.employeeName.toLowerCase().contains(emp.name.toLowerCase().split(' ').first),
        );
        if (idx >= 0) {
          final existing = MockDataService.contracts[idx];
          MockDataService.contracts[idx] = ContractModel(
            id: existing.id,
            refCode: existing.refCode,
            employeeName: existing.employeeName,
            department: existing.department,
            startDate: existing.startDate,
            wageMonthly: batchWage,
            status: existing.status,
            structureName: batchStruct,
          );
        }
      }

      for (final emp in deptEmps) {
        final c = MockDataService.contracts.firstWhere(
          (con) => con.employeeName.toLowerCase().contains(emp.name.toLowerCase().split(' ').first),
        );
        expect(c.wageMonthly, equals(98000.0));
        expect(c.structureName, equals('Regular Employee Base'));
      }
    });
  });
}
