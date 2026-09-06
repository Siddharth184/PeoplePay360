import 'package:flutter_test/flutter_test.dart';
import 'package:peoplepay360/models/models.dart';
import 'package:peoplepay360/services/api_client.dart';
import 'package:peoplepay360/services/salary_structure_service.dart';

void main() {
  group('Salary Structure & Rule Schema & Model Tests', () {
    test('SalaryStructureModel correctly deserializes backend snake_case JSON', () {
      final json = {
        'id': 'struct-100',
        'name': 'Regular Staff Base',
        'code': 'BASE_IN',
        'is_active': true,
        'notes': 'Monthly structure',
        'created_at': '2026-01-01T00:00:00Z',
        'rule_count': 5,
        'active_rule_count': 5,
        'employee_count': 10,
        'rules': [
          {
            'id': 'rule-1',
            'salary_structure_id': 'struct-100',
            'name': 'Basic Salary',
            'code': 'BASIC',
            'sequence': 10,
            'category': 'BASIC',
            'computation_type': 'FIXED',
            'fixed_amount': 50000.0,
            'quantity': 1.0,
            'is_active': true,
            'created_at': '2026-01-01T00:00:00Z',
          }
        ]
      };

      final model = SalaryStructureModel.fromJson(json);

      expect(model.id, equals('struct-100'));
      expect(model.name, equals('Regular Staff Base'));
      expect(model.code, equals('BASE_IN'));
      expect(model.isActive, isTrue);
      expect(model.notes, equals('Monthly structure'));
      expect(model.rules.length, equals(1));
      expect(model.rules.first.code, equals('BASIC'));
      expect(model.rules.first.computationType, equals('FIXED'));
      expect(model.rules.first.fixedAmount, equals(50000.0));
    });

    test('SalaryRuleModel correctly deserializes PERCENTAGE & PYTHON_CODE rules', () {
      final percentageJson = {
        'id': 'rule-2',
        'salary_structure_id': 'struct-100',
        'name': 'House Rent Allowance',
        'code': 'HRA',
        'sequence': 20,
        'category': 'ALLOWANCE',
        'computation_type': 'PERCENTAGE',
        'percentage_base': 'BASIC',
        'percentage_rate': 40.0,
        'quantity': 1.0,
        'is_active': true,
      };

      final percentageRule = SalaryRuleModel.fromJson(percentageJson);
      expect(percentageRule.computationType, equals('PERCENTAGE'));
      expect(percentageRule.percentageBase, equals('BASIC'));
      expect(percentageRule.percentageRate, equals(40.0));

      final pythonJson = {
        'id': 'rule-3',
        'salary_structure_id': 'struct-100',
        'name': 'Provident Fund',
        'code': 'PF',
        'sequence': 80,
        'category': 'DEDUCTION',
        'computation_type': 'PYTHON_CODE',
        'python_code': "result = min(categories['BASIC'] * Decimal('0.12'), Decimal('1800'))",
        'quantity': 1.0,
        'is_active': true,
      };

      final pythonRule = SalaryRuleModel.fromJson(pythonJson);
      expect(pythonRule.computationType, equals('PYTHON_CODE'));
      expect(pythonRule.pythonCode, contains("categories['BASIC']"));
    });
  });

  group('Role-Based Access Control (RBAC) Matrix Tests', () {
    test('ADMIN has full read and write access to payroll config', () {
      ApiClient.setSession(
        accessToken: 'mock-token',
        userId: 'admin-1',
        email: 'admin@company.com',
        role: 'ADMIN',
      );

      expect(ApiClient.hasPayrollAccess, isTrue);
      expect(ApiClient.hasPayrollConfigReadAccess, isTrue);
      expect(ApiClient.hasPayrollConfigWriteAccess, isTrue);
    });

    test('HR_PAYROLL_MANAGER has read and write access to payroll config', () {
      ApiClient.setSession(
        accessToken: 'mock-token',
        userId: 'pm-1',
        email: 'payrollmgr@company.com',
        role: 'HR_PAYROLL_MANAGER',
      );

      expect(ApiClient.hasPayrollAccess, isTrue);
      expect(ApiClient.hasPayrollConfigReadAccess, isTrue);
      expect(ApiClient.hasPayrollConfigWriteAccess, isTrue);
    });

    test('HR_PAYROLL_USER has read-only access to payroll config', () {
      ApiClient.setSession(
        accessToken: 'mock-token',
        userId: 'pu-1',
        email: 'payrolluser@company.com',
        role: 'HR_PAYROLL_USER',
      );

      expect(ApiClient.hasPayrollAccess, isTrue);
      expect(ApiClient.hasPayrollConfigReadAccess, isTrue);
      expect(ApiClient.hasPayrollConfigWriteAccess, isFalse);
    });

    test('HR_MANAGER has NO access to payroll config', () {
      ApiClient.setSession(
        accessToken: 'mock-token',
        userId: 'hrm-1',
        email: 'hrmgr@company.com',
        role: 'HR_MANAGER',
      );

      expect(ApiClient.hasPayrollAccess, isFalse);
      expect(ApiClient.hasPayrollConfigReadAccess, isFalse);
      expect(ApiClient.hasPayrollConfigWriteAccess, isFalse);
    });

    test('EMPLOYEE has NO access to payroll config', () {
      ApiClient.setSession(
        accessToken: 'mock-token',
        userId: 'emp-1',
        email: 'emp@company.com',
        role: 'EMPLOYEE',
      );

      expect(ApiClient.hasPayrollAccess, isFalse);
      expect(ApiClient.hasPayrollConfigReadAccess, isFalse);
      expect(ApiClient.hasPayrollConfigWriteAccess, isFalse);
    });
  });

  group('SalaryStructureService Offline Fallback Tests', () {
    final originalBaseUrl = ApiClient.baseUrl;

    setUp(() {
      ApiClient.baseUrl = 'http://127.0.0.1:59999/api/v1';
      ApiClient.isBackendOnline = false;
    });

    tearDown(() {
      ApiClient.baseUrl = originalBaseUrl;
    });

    test('getStructures returns list of structures when offline', () async {
      final res = await SalaryStructureService.getStructures();
      expect(res.isSuccess, isTrue);
      expect(res.data, isNotNull);
      expect(res.data!, isNotEmpty);
    });

    test('getStructureDetail returns detail with rules when offline', () async {
      final res = await SalaryStructureService.getStructureDetail('struct-01');
      expect(res.isSuccess, isTrue);
      expect(res.data, isNotNull);
      expect(res.data!.rules, isNotEmpty);
    });

    test('simulateStructure returns simulation calculation result when offline', () async {
      final payload = {
        'salary_structure_id': 'struct-01',
        'wage_monthly': 100000.0,
        'worked_days': 22.0,
        'expected_days': 22.0,
      };

      final res = await SalaryStructureService.simulateStructure(payload);
      expect(res.isSuccess, isTrue);
      expect(res.data, isNotNull);
      expect(res.data!.wageMonthly, equals(100000.0));
      expect(res.data!.basic, greaterThan(0));
      expect(res.data!.gross, greaterThan(0));
      expect(res.data!.net, greaterThan(0));
      expect(res.data!.lines, isNotEmpty);
    });
  });
}
