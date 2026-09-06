import 'package:flutter_test/flutter_test.dart';
import 'package:peoplepay360/models/models.dart';
import 'package:peoplepay360/services/employee_service.dart';
import 'package:peoplepay360/services/mock_data_service.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  group('Contract Job Position & Profile Consistency Tests', () {
    test('Updating contract job position updates employee profile title consistently', () async {
      final emp = MockDataService.allEmployees.firstWhere((e) => e.name == 'Rajesh Kumar', orElse: () => MockDataService.allEmployees.first);
      const newJobTitle = 'Senior HR Operations Manager';

      final res = await EmployeeService.updateEmployee(emp.id, {
        'job_position': newJobTitle,
        'job_position_name': newJobTitle,
        'department': 'Human Resources',
      });

      expect(res.isSuccess, isTrue);
      expect(res.data?.jobTitle, equals(newJobTitle));

      final updatedProfile = await EmployeeService.getEmployee(emp.id);
      expect(updatedProfile.data?.jobTitle, equals(newJobTitle));
      expect(EmployeeService.currentEmployeeNotifier.value.jobTitle, equals(newJobTitle));
    });

    test('Updating employee job title reflects across all profile lookups', () async {
      const empId = 'emp-003';
      const updatedTitle = 'Senior HR Operations Lead';

      await EmployeeService.updateEmployee(empId, {
        'job_position': updatedTitle,
        'department': 'Human Resources',
      });

      final empModel = await EmployeeService.getEmployee(empId);
      expect(empModel.data?.jobTitle, equals(updatedTitle));
    });
  });
}
