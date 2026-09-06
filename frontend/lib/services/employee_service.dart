import 'package:flutter/foundation.dart';
import '../models/models.dart';
import 'api_client.dart';
import 'mock_data_service.dart';

class EmployeeService {
  /// Reactive ValueNotifier so screens instantly update when employee profile details change
  static final ValueNotifier<EmployeeModel> currentEmployeeNotifier =
      ValueNotifier<EmployeeModel>(MockDataService.currentEmployee);

  static Future<ApiResponse<List<EmployeeModel>>> getEmployees({
    String? search,
    String? departmentId,
    String? status,
    String? employeeType,
    int limit = 100,
    int offset = 0,
  }) async {
    final query = <String, dynamic>{
      'limit': limit,
      'offset': offset,
    };
    if (search != null && search.isNotEmpty) query['search'] = search;
    if (departmentId != null && departmentId.isNotEmpty) query['department_id'] = departmentId;
    if (status != null && status.isNotEmpty) query['status'] = status;
    if (employeeType != null && employeeType.isNotEmpty) query['employee_type'] = employeeType;

    final response = await ApiClient.get<List<EmployeeModel>>(
      '/employees',
      queryParams: query,
      parser: (json) {
        if (json is List) {
          return json.map((e) => EmployeeModel.fromJson(e as Map<String, dynamic>)).toList();
        }
        return [];
      },
    );

    if (response.isSuccess && response.data != null) {
      return response;
    }

    if (!ApiClient.isBackendOnline || response.statusCode == 0) {
      var list = List<EmployeeModel>.from(MockDataService.allEmployees);
      if (search != null && search.isNotEmpty) {
        final q = search.toLowerCase();
        list = list.where((e) => e.name.toLowerCase().contains(q) || e.email.toLowerCase().contains(q) || e.department.toLowerCase().contains(q)).toList();
      }
      return ApiResponse.success(list);
    }

    return response;
  }

  static Future<ApiResponse<EmployeeModel>> getEmployee(String employeeId) async {
    final response = await ApiClient.get<EmployeeModel>(
      '/employees/$employeeId',
      parser: (json) => EmployeeModel.fromJson(json as Map<String, dynamic>),
    );

    if (response.isSuccess && response.data != null) {
      final emp = response.data!;
      if (employeeId == ApiClient.currentEmployeeId || employeeId == MockDataService.currentEmployee.id) {
        currentEmployeeNotifier.value = emp;
      }
      return response;
    }

    if (!ApiClient.isBackendOnline || response.statusCode == 0 || response.statusCode == 400 || response.statusCode == 404) {
      final found = MockDataService.allEmployees.firstWhere(
        (e) => e.id == employeeId,
        orElse: () => MockDataService.currentEmployee,
      );
      if (employeeId == ApiClient.currentEmployeeId || employeeId == MockDataService.currentEmployee.id || employeeId == found.id) {
        currentEmployeeNotifier.value = found;
      }
      return ApiResponse.success(found);
    }

    return response;
  }

  static Future<ApiResponse<EmployeeModel>> createEmployee(Map<String, dynamic> data) async {
    final response = await ApiClient.post<EmployeeModel>(
      '/employees',
      body: data,
      parser: (json) => EmployeeModel.fromJson(json as Map<String, dynamic>),
    );

    if (response.isSuccess && response.data != null) {
      return response;
    }

    if (!ApiClient.isBackendOnline || response.statusCode == 0 || response.statusCode == 400 || response.statusCode == 404) {
      final String empName = data['name']?.toString() ?? 'New Employee';
      final String dept = data['department_name']?.toString() ?? data['department']?.toString() ?? 'General';
      final String job = data['job_position_name']?.toString() ?? data['job_position']?.toString() ?? 'Staff';
      final double wage = (data['wage_monthly'] is num)
          ? (data['wage_monthly'] as num).toDouble()
          : (double.tryParse(data['wage_monthly']?.toString() ?? '') ?? 85000.0);

      final newEmp = EmployeeModel(
        id: 'emp-${DateTime.now().millisecondsSinceEpoch}',
        name: empName,
        email: data['work_email']?.toString() ?? data['email']?.toString() ?? '',
        jobTitle: job,
        department: dept,
        workPhone: data['phone']?.toString() ?? data['workPhone']?.toString() ?? '+91 98765 00099',
        managerName: data['manager_name']?.toString() ?? data['managerName']?.toString() ?? 'Sara Khan',
        avatarUrl: data['avatar_url']?.toString() ?? '',
        timeOffBalance: 14,
        activeContractsCount: 1,
        attendancesCount: 0,
        payslipsCount: 0,
        badgeId: data['badge_id']?.toString() ?? 'EMP-${4000 + MockDataService.allEmployees.length}',
        employeeType: data['employee_type']?.toString() ?? 'Full-time',
        status: data['status']?.toString() ?? 'ACTIVE',
        dateOfJoining: data['date_of_joining']?.toString() ?? '2026-09-01',
        bankName: data['bank_name']?.toString() ?? 'HDFC Bank',
        bankAccountNumber: data['bank_account_number']?.toString() ?? '5010-9941-${1000 + MockDataService.allEmployees.length}',
        workLocation: data['work_location']?.toString() ?? data['workLocation']?.toString() ?? 'Bengaluru HQ',
      );
      MockDataService.allEmployees.insert(0, newEmp);

      final newContract = ContractModel(
        id: 'con-${DateTime.now().millisecondsSinceEpoch}',
        refCode: 'CON/2026/00${50 + MockDataService.contracts.length}',
        employeeName: empName,
        department: dept,
        startDate: data['date_of_joining']?.toString() ?? '2026-09-01',
        wageMonthly: wage,
        status: 'RUNNING',
        structureName: 'Regular Employee Base',
      );
      MockDataService.contracts.insert(0, newContract);

      return ApiResponse.success(newEmp);
    }

    return response;
  }

  static Future<ApiResponse<EmployeeModel>> updateEmployee(String id, Map<String, dynamic> data) async {
    ApiResponse<EmployeeModel> response = await ApiClient.patch<EmployeeModel>(
      '/employees/$id',
      body: data,
      parser: (json) => EmployeeModel.fromJson(json as Map<String, dynamic>),
    );

    if (!response.isSuccess) {
      response = await ApiClient.put<EmployeeModel>(
        '/employees/$id',
        body: data,
        parser: (json) => EmployeeModel.fromJson(json as Map<String, dynamic>),
      );
    }

    if (response.isSuccess && response.data != null) {
      final updated = response.data!;
      final idx = MockDataService.allEmployees.indexWhere((e) => e.id == id || e.name.toLowerCase() == updated.name.toLowerCase());
      if (idx != -1) {
        MockDataService.allEmployees[idx] = updated;
      }
      if (id == ApiClient.currentEmployeeId || id == MockDataService.currentEmployee.id || updated.id == MockDataService.currentEmployee.id) {
        MockDataService.currentEmployee = updated;
      }
      currentEmployeeNotifier.value = updated;
      return response;
    }

    if (!ApiClient.isBackendOnline || response.statusCode == 0 || response.statusCode == 400 || response.statusCode == 404) {
      final idx = MockDataService.allEmployees.indexWhere((e) => e.id == id || (data['name'] != null && e.name.toLowerCase() == data['name'].toString().toLowerCase()));
      final existing = idx != -1 ? MockDataService.allEmployees[idx] : MockDataService.currentEmployee;
      final updated = existing.copyWith(
        name: data['name']?.toString() ?? existing.name,
        jobTitle: data['job_position_name']?.toString() ?? data['job_position']?.toString() ?? data['jobTitle']?.toString() ?? existing.jobTitle,
        department: data['department_name']?.toString() ?? data['department']?.toString() ?? existing.department,
        email: data['work_email']?.toString() ?? data['email']?.toString() ?? existing.email,
        workPhone: data['phone']?.toString() ?? data['workPhone']?.toString() ?? existing.workPhone,
      );

      if (idx != -1) {
        MockDataService.allEmployees[idx] = updated;
      } else {
        MockDataService.allEmployees.add(updated);
      }
      if (id == ApiClient.currentEmployeeId || id == MockDataService.currentEmployee.id || existing.id == MockDataService.currentEmployee.id) {
        MockDataService.currentEmployee = updated;
      }
      currentEmployeeNotifier.value = updated;

      return ApiResponse.success(updated);
    }

    return response;
  }

  static Future<ApiResponse<List<Map<String, dynamic>>>> getDepartments() async {
    return await ApiClient.get<List<Map<String, dynamic>>>(
      '/employees/departments',
      parser: (json) {
        if (json is List) {
          return json.map((e) => e as Map<String, dynamic>).toList();
        }
        return [];
      },
    );
  }

  static Future<ApiResponse<List<Map<String, dynamic>>>> getPositions() async {
    return await ApiClient.get<List<Map<String, dynamic>>>(
      '/employees/positions',
      parser: (json) {
        if (json is List) {
          return json.map((e) => e as Map<String, dynamic>).toList();
        }
        return [];
      },
    );
  }
}
