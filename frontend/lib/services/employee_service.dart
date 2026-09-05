import '../models/models.dart';
import 'api_client.dart';
import 'mock_data_service.dart';

class EmployeeService {
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
      return response;
    }

    if (!ApiClient.isBackendOnline || response.statusCode == 0) {
      var list = MockDataService.allEmployees;
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
      return response;
    }

    if (!ApiClient.isBackendOnline || response.statusCode == 0) {
      final found = MockDataService.allEmployees.firstWhere(
        (e) => e.id == employeeId,
        orElse: () => MockDataService.currentEmployee,
      );
      return ApiResponse.success(found);
    }

    return response;
  }

  static Future<ApiResponse<EmployeeModel>> createEmployee(Map<String, dynamic> data) async {
    return await ApiClient.post<EmployeeModel>(
      '/employees',
      body: data,
      parser: (json) => EmployeeModel.fromJson(json as Map<String, dynamic>),
    );
  }

  static Future<ApiResponse<EmployeeModel>> updateEmployee(String id, Map<String, dynamic> data) async {
    return await ApiClient.put<EmployeeModel>(
      '/employees/$id',
      body: data,
      parser: (json) => EmployeeModel.fromJson(json as Map<String, dynamic>),
    );
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
