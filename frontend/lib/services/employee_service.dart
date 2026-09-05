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

    if (response.isSuccess && response.data != null && response.data!.isNotEmpty) {
      // Sync MockDataService.allEmployees
      for (final emp in response.data!) {
        final idx = MockDataService.allEmployees.indexWhere((e) => e.id == emp.id);
        if (idx != -1) {
          MockDataService.allEmployees[idx] = emp;
        } else {
          MockDataService.allEmployees.add(emp);
        }
      }
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
      if (employeeId == MockDataService.currentEmployee.id || employeeId == 'emp-001') {
        MockDataService.currentEmployee = emp;
        currentEmployeeNotifier.value = emp;
      }
      final idx = MockDataService.allEmployees.indexWhere((e) => e.id == employeeId);
      if (idx != -1) {
        MockDataService.allEmployees[idx] = emp;
      } else {
        MockDataService.allEmployees.add(emp);
      }
      return response;
    }

    if (!ApiClient.isBackendOnline || response.statusCode == 0) {
      final found = MockDataService.allEmployees.firstWhere(
        (e) => e.id == employeeId,
        orElse: () => MockDataService.currentEmployee,
      );
      if (employeeId == MockDataService.currentEmployee.id || employeeId == 'emp-001') {
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
      MockDataService.allEmployees.insert(0, response.data!);
    } else {
      final newEmp = EmployeeModel(
        id: 'emp-${DateTime.now().millisecondsSinceEpoch}',
        name: data['name']?.toString() ?? 'New Employee',
        email: data['work_email']?.toString() ?? data['email']?.toString() ?? '',
        jobTitle: data['job_position_name']?.toString() ?? data['job_position']?.toString() ?? data['jobTitle']?.toString() ?? 'Staff',
        department: data['department_name']?.toString() ?? data['department']?.toString() ?? 'General',
        workPhone: data['phone']?.toString() ?? data['workPhone']?.toString() ?? '',
        managerName: 'Sara Khan',
        avatarUrl: '',
        timeOffBalance: 14,
        activeContractsCount: 1,
        attendancesCount: 0,
        payslipsCount: 0,
        status: 'ACTIVE',
        employeeType: 'Full-time',
      );
      MockDataService.allEmployees.insert(0, newEmp);
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

    EmployeeModel updated;
    if (response.isSuccess && response.data != null) {
      updated = response.data!;
    } else {
      final existing = MockDataService.allEmployees.firstWhere(
        (e) => e.id == id,
        orElse: () => MockDataService.currentEmployee,
      );
      updated = existing.copyWith(
        name: data['name']?.toString() ?? existing.name,
        jobTitle: data['job_position_name']?.toString() ?? data['job_position']?.toString() ?? data['jobTitle']?.toString() ?? existing.jobTitle,
        department: data['department_name']?.toString() ?? data['department']?.toString() ?? existing.department,
        email: data['work_email']?.toString() ?? data['email']?.toString() ?? existing.email,
        workPhone: data['phone']?.toString() ?? data['workPhone']?.toString() ?? existing.workPhone,
      );
    }

    // Synchronize local caches and reactive listeners
    if (id == MockDataService.currentEmployee.id || id == 'emp-001') {
      MockDataService.currentEmployee = updated;
      currentEmployeeNotifier.value = updated;
    }
    final idx = MockDataService.allEmployees.indexWhere((e) => e.id == id);
    if (idx != -1) {
      MockDataService.allEmployees[idx] = updated;
    } else {
      MockDataService.allEmployees.add(updated);
    }

    return ApiResponse.success(updated);
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
