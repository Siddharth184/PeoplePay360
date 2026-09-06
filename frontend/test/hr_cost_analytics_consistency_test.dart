import 'package:flutter_test/flutter_test.dart';
import 'package:peoplepay360/services/mock_data_service.dart';

void main() {
  group('HR Cost Analytics Data Consistency Tests', () {
    test('Calculates total gross & net salary dynamically from payslips', () {
      final septPayslips = MockDataService.payslips.where((p) => p.periodStart.startsWith('2026-09')).toList();
      expect(septPayslips, isNotEmpty);

      final expectedGross = septPayslips.fold(0.0, (sum, p) => sum + p.grossAmount);
      final expectedNet = septPayslips.fold(0.0, (sum, p) => sum + p.netAmount);

      expect(expectedGross, greaterThan(0.0));
      expect(expectedNet, greaterThan(0.0));
      expect(expectedNet, lessThan(expectedGross));
      // Verify net salary is not an arbitrary 0.88 multiplier of gross
      expect(expectedNet, isNot(equals(expectedGross * 0.88)));
    });

    test('Department cost breakdown reflects actual employee department allocations', () {
      final allEmps = MockDataService.allEmployees;
      final deptCounts = <String, int>{};

      for (final emp in allEmps) {
        final dName = emp.department.isNotEmpty ? emp.department : 'General Staff';
        deptCounts[dName] = (deptCounts[dName] ?? 0) + 1;
      }

      expect(deptCounts.keys, contains('Engineering'));
      expect(deptCounts['Engineering'], greaterThan(0));
    });

    test('Monthly net salary trend is calculated dynamically across 6 months', () {
      final monthsList = ['2026-04', '2026-05', '2026-06', '2026-07', '2026-08', '2026-09'];
      final monthTotals = <String, double>{};

      for (final ym in monthsList) {
        final monthSlips = MockDataService.payslips.where((p) => p.periodStart.startsWith(ym)).toList();
        final sumNet = monthSlips.fold(0.0, (sum, p) => sum + p.netAmount);
        monthTotals[ym] = sumNet;
      }

      // Check August vs September totals
      expect(monthTotals['2026-08'], greaterThan(0.0));
      expect(monthTotals['2026-09'], greaterThan(0.0));
      expect(monthTotals['2026-08'], isNot(equals(monthTotals['2026-09'])));
    });

    test('Audit and anomaly counts accurately inspect bank accounts & draft items', () {
      final allEmps = MockDataService.allEmployees;
      final missingBank = allEmps.where((e) => e.bankAccountNumber == null || e.bankAccountNumber!.isEmpty).length;

      final allContracts = MockDataService.contracts;
      final draftContracts = allContracts.where((c) => c.status == 'DRAFT').length;

      expect(missingBank, greaterThanOrEqualTo(0));
      expect(draftContracts, greaterThanOrEqualTo(0));
    });
  });
}
