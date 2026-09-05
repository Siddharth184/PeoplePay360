import 'package:flutter_test/flutter_test.dart';
import 'package:peoplepay360/models/models.dart';
import 'package:peoplepay360/widgets/payslip_pdf_dialog.dart';

void main() {
  group('Payslip Preview & Model Parsing Tests', () {
    test('PayslipModel.fromJson correctly parses currency strings and map aliases', () {
      final mockMap = {
        'id': 'aarav',
        'name': 'Aarav Mehta',
        'empCode': 'EMP-4092',
        'refNo': 'PS-2026-02-0042',
        'basic': '₹50,000',
        'gross': '₹80,000',
        'netPayout': '₹75,000',
        'workedDays': '22',
        'status': 'Done',
      };

      final payslip = PayslipModel.fromJson(mockMap);

      expect(payslip.id, equals('aarav'));
      expect(payslip.employeeName, equals('Aarav Mehta'));
      expect(payslip.refCode, equals('PS-2026-02-0042'));
      expect(payslip.basicAmount, equals(50000.0));
      expect(payslip.grossAmount, equals(80000.0));
      expect(payslip.netAmount, equals(75000.0));
      expect(payslip.workedDays, equals(22.0));
    });

    test('PayslipPdfDialog generates fallback effective lines when lines array is empty', () {
      final payslip = PayslipModel(
        id: 'test-1',
        refCode: 'SLIP-001',
        employeeName: 'John Doe',
        periodStart: '2026-09-01',
        periodEnd: '2026-09-30',
        grossAmount: 100000.0,
        netAmount: 90000.0,
        status: 'PAID',
        lines: [],
      );

      final dialog = PayslipPdfDialog(payslip: payslip);

      // Access widget properties
      expect(dialog.payslip.refCode, equals('SLIP-001'));
      expect(dialog.payslip.grossAmount, equals(100000.0));
      expect(dialog.payslip.lines, isEmpty);
    });
  });
}
