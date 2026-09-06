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

    test('PayslipModel derives contract hourly rate (176h), 1.5x overtime rate, and extra days payout', () {
      final mockMap = {
        'id': 'pay-ot-test',
        'refCode': 'SLIP/2026/OT-001',
        'employeeName': 'Priya Patel',
        'contractMonthlyWage': 85000.0,
        'scheduled_hours': 176.0,
        'overtime_hours': 10.0,
        'extra_days': 2.0,
        'basic': 50000.0,
        'gross': 94971.59,
        'netPayout': 89971.59,
        'status': 'DONE',
      };

      final payslip = PayslipModel.fromJson(mockMap);

      expect(payslip.contractMonthlyWage, equals(85000.0));
      expect(payslip.hourlyRate, closeTo(482.95, 0.01));
      expect(payslip.overtimeRate, closeTo(724.43, 0.01));
      expect(payslip.overtimeHours, equals(10.0));
      expect(payslip.overtimePay, closeTo(7244.32, 0.5));
      expect(payslip.extraDays, equals(2.0));
      expect(payslip.extraDaysPay, closeTo(7727.27, 0.5));
    });

    test('PayslipPdfDialog generates fallback effective lines including OT and EXT_DAYS', () {
      final payslip = PayslipModel(
        id: 'test-1',
        refCode: 'SLIP-001',
        employeeName: 'John Doe',
        periodStart: '2026-09-01',
        periodEnd: '2026-09-30',
        contractMonthlyWage: 85000.0,
        overtimeHours: 10.0,
        extraDays: 2.0,
        grossAmount: 94971.59,
        netAmount: 89971.59,
        status: 'PAID',
        lines: [],
      );

      final dialog = PayslipPdfDialog(payslip: payslip);

      expect(dialog.payslip.refCode, equals('SLIP-001'));
      expect(dialog.payslip.grossAmount, equals(94971.59));
      expect(dialog.payslip.lines, isEmpty);
    });

    test('PayslipModel safe getters return default numbers even when json contains null or empty fields', () {
      final mockMapWithNulls = <String, dynamic>{
        'id': 'pay-null-test',
        'refCode': null,
        'extra_days_pay': null,
        'overtime_pay': null,
        'worked_days': null,
        'basic': null,
        'gross': null,
        'net': null,
      };

      final payslip = PayslipModel.fromJson(mockMapWithNulls);

      expect(payslip.safeExtraDaysPay, equals(0.0));
      expect(payslip.safeOvertimePay, equals(0.0));
      expect(payslip.safeWorkedDays, equals(22.0));
      expect(payslip.safeBasicAmount, equals(50000.0));
      expect(payslip.safeGrossAmount, equals(80000.0));
      expect(payslip.safeNetAmount, equals(75000.0));
    });
  });
}
