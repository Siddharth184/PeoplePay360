import 'package:flutter_test/flutter_test.dart';
import 'package:peoplepay360/services/api_client.dart';

void main() {
  group('Dynamic Access Authorization & RBAC Matrix Real-time Verification', () {
    setUp(() {
      ApiClient.clearSession();
    });

    test('1. Initial Session as EMPLOYEE enforces strict self-service bounds', () {
      ApiClient.setSession(
        accessToken: 'token-emp',
        userId: 'u-emp',
        email: 'rohan.desai@oxp.com',
        role: 'EMPLOYEE',
        employeeId: 'emp-01',
        employeeName: 'Rohan Desai',
      );

      expect(ApiClient.activeRole, equals('EMPLOYEE'));
      expect(ApiClient.isEmployee, isTrue);
      expect(ApiClient.isAdmin, isFalse);
      expect(ApiClient.isRoleHrManager, isFalse);
      expect(ApiClient.isRoleHrPayrollManager, isFalse);
      expect(ApiClient.isRoleHrPayrollUser, isFalse);

      // Capability checks
      expect(ApiClient.hasPayrollAccess, isFalse);
      expect(ApiClient.hasPayrollConfigReadAccess, isFalse);
      expect(ApiClient.hasPayrollConfigWriteAccess, isFalse);
      expect(ApiClient.hasHrAccess, isFalse);
      expect(ApiClient.hasTimeOffApprovalAccess, isFalse);
      expect(ApiClient.hasAttendanceLedgerAccess, isFalse);
      expect(ApiClient.hasContractsAccess, isFalse);
      expect(ApiClient.hasUserManagementAccess, isFalse);
    });

    test('2. Dynamically updating role to HR_MANAGER immediately unlocks HR modules without side-effects', () {
      // Start as Employee
      ApiClient.setSession(
        accessToken: 'token-dynamic',
        userId: 'u-user1',
        email: 'user1@oxp.com',
        role: 'EMPLOYEE',
      );
      expect(ApiClient.hasHrAccess, isFalse);

      // Dynamically promote user to HR_MANAGER (e.g. via User Management RBAC edit)
      ApiClient.currentUserRole = 'HR_MANAGER';

      expect(ApiClient.activeRole, equals('HR_MANAGER'));
      expect(ApiClient.isRoleHrManager, isTrue);

      // HR Capabilities unlocked
      expect(ApiClient.hasHrAccess, isTrue);
      expect(ApiClient.hasTimeOffApprovalAccess, isTrue);
      expect(ApiClient.hasAttendanceLedgerAccess, isTrue);
      expect(ApiClient.hasContractsAccess, isTrue);

      // Payroll & Admin remain strictly locked per Odoo spec Page 3
      expect(ApiClient.hasPayrollAccess, isFalse);
      expect(ApiClient.hasPayrollConfigWriteAccess, isFalse);
      expect(ApiClient.hasUserManagementAccess, isFalse);
    });

    test('3. Dynamically updating role to HR_PAYROLL_USER unlocks Payroll view while keeping Config Write locked', () {
      ApiClient.setSession(
        accessToken: 'token-dynamic',
        userId: 'u-user2',
        email: 'user2@oxp.com',
        role: 'HR_MANAGER',
      );

      // Dynamically switch role to HR_PAYROLL_USER
      ApiClient.currentUserRole = 'HR_PAYROLL_USER';

      expect(ApiClient.activeRole, equals('HR_PAYROLL_USER'));
      expect(ApiClient.isRoleHrPayrollUser, isTrue);

      expect(ApiClient.hasPayrollAccess, isTrue);
      expect(ApiClient.hasPayrollConfigReadAccess, isTrue);
      expect(ApiClient.hasPayrollConfigWriteAccess, isFalse);
      expect(ApiClient.hasHrAccess, isTrue);
      expect(ApiClient.hasUserManagementAccess, isFalse);
    });

    test('4. Dynamically updating role to HR_PAYROLL_MANAGER unlocks Full Payroll Computation & Config Editing', () {
      ApiClient.setSession(
        accessToken: 'token-dynamic',
        userId: 'u-user3',
        email: 'user3@oxp.com',
        role: 'HR_PAYROLL_USER',
      );

      // Promote to HR_PAYROLL_MANAGER
      ApiClient.currentUserRole = 'HR_PAYROLL_MANAGER';

      expect(ApiClient.activeRole, equals('HR_PAYROLL_MANAGER'));
      expect(ApiClient.isRoleHrPayrollManager, isTrue);

      expect(ApiClient.hasPayrollAccess, isTrue);
      expect(ApiClient.hasPayrollConfigReadAccess, isTrue);
      expect(ApiClient.hasPayrollConfigWriteAccess, isTrue);
      expect(ApiClient.hasHrAccess, isTrue);
      expect(ApiClient.hasUserManagementAccess, isFalse);
    });

    test('5. Dynamically updating role to ADMIN unlocks Root Control & User Management', () {
      ApiClient.setSession(
        accessToken: 'token-dynamic',
        userId: 'u-admin',
        email: 'admin@oxp.com',
        role: 'EMPLOYEE',
      );

      // Promote to ADMIN
      ApiClient.currentUserRole = 'ADMIN';

      expect(ApiClient.activeRole, equals('ADMIN'));
      expect(ApiClient.isAdmin, isTrue);

      expect(ApiClient.hasPayrollAccess, isTrue);
      expect(ApiClient.hasPayrollConfigReadAccess, isTrue);
      expect(ApiClient.hasPayrollConfigWriteAccess, isTrue);
      expect(ApiClient.hasHrAccess, isTrue);
      expect(ApiClient.hasTimeOffApprovalAccess, isTrue);
      expect(ApiClient.hasAttendanceLedgerAccess, isTrue);
      expect(ApiClient.hasContractsAccess, isTrue);
      expect(ApiClient.hasUserManagementAccess, isTrue);
    });

    test('6. Session reset cleanly locks all permissions', () {
      ApiClient.setSession(
        accessToken: 'token-admin',
        userId: 'u-admin',
        email: 'admin@oxp.com',
        role: 'ADMIN',
      );
      expect(ApiClient.isAdmin, isTrue);

      // User logs out / clears session
      ApiClient.clearSession();

      expect(ApiClient.isAuthenticated, isFalse);
      expect(ApiClient.activeRole, equals('EMPLOYEE'));
      expect(ApiClient.hasUserManagementAccess, isFalse);
      expect(ApiClient.hasPayrollAccess, isFalse);
    });
  });
}
