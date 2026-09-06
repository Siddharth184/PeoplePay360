import 'package:flutter_test/flutter_test.dart';
import 'package:peoplepay360/services/employee_service.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  group('New Employee Onboarding Work Location Verification Tests', () {
    test('Selected work location reflects correctly on onboarded employee profile', () async {
      const chosenLocation = 'Delhi Regional Hub';
      const empEmail = 'test.onboard@oxp.com';

      final res = await EmployeeService.createEmployee({
        'name': 'Rohan Sharma',
        'work_email': empEmail,
        'job_position_name': 'DevOps Engineer',
        'department_name': 'Engineering',
        'work_location': chosenLocation,
        'phone': '+91 98765 11223',
      });

      expect(res.isSuccess, isTrue);
      expect(res.data, isNotNull);
      expect(res.data?.workLocation, equals(chosenLocation));

      final profile = await EmployeeService.getEmployee(res.data!.id);
      expect(profile.data?.workLocation, equals(chosenLocation));
    });
  });
}
