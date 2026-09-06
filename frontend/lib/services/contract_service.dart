import '../models/models.dart';
import 'api_client.dart';
import 'mock_data_service.dart';

class ContractService {
  static Future<ApiResponse<List<ContractModel>>> getContracts({
    String? employeeId,
    String? status,
    int limit = 100,
    int offset = 0,
  }) async {
    final query = <String, dynamic>{
      'limit': limit,
      'offset': offset,
    };
    if (employeeId != null && employeeId.isNotEmpty) query['employee_id'] = employeeId;
    if (status != null && status.isNotEmpty) query['status'] = status;

    final response = await ApiClient.get<List<ContractModel>>(
      '/contracts',
      queryParams: query,
      parser: (json) {
        if (json is List) {
          return json.map((e) => ContractModel.fromJson(e as Map<String, dynamic>)).toList();
        }
        return [];
      },
    );

    if (response.isSuccess && response.data != null) {
      return response;
    }

    if (!ApiClient.isBackendOnline || response.statusCode == 0) {
      return ApiResponse.success(MockDataService.contracts);
    }

    return response;
  }

  static Future<ApiResponse<ContractModel>> getContract(String id) async {
    final response = await ApiClient.get<ContractModel>(
      '/contracts/$id',
      parser: (json) => ContractModel.fromJson(json as Map<String, dynamic>),
    );

    if (response.isSuccess && response.data != null) {
      return response;
    }

    if (!ApiClient.isBackendOnline || response.statusCode == 0) {
      final found = MockDataService.contracts.firstWhere(
        (c) => c.id == id,
        orElse: () => MockDataService.contracts.first,
      );
      return ApiResponse.success(found);
    }

    return response;
  }

  static Future<ApiResponse<ContractModel>> createContract(Map<String, dynamic> data) async {
    return await ApiClient.post<ContractModel>(
      '/contracts',
      body: data,
      parser: (json) => ContractModel.fromJson(json as Map<String, dynamic>),
    );
  }

  static Future<ApiResponse<ContractModel>> updateContract(String id, Map<String, dynamic> data) async {
    return await ApiClient.put<ContractModel>(
      '/contracts/$id',
      body: data,
      parser: (json) => ContractModel.fromJson(json as Map<String, dynamic>),
    );
  }

  static Future<ApiResponse<ContractModel>> terminateContract(String id, String dateEnd) async {
    return await ApiClient.post<ContractModel>(
      '/contracts/$id/terminate',
      body: {'date_end': dateEnd},
      parser: (json) => ContractModel.fromJson(json as Map<String, dynamic>),
    );
  }

  static Future<ApiResponse<Map<String, dynamic>>> reviseCompensation(
    String contractId,
    Map<String, dynamic> body,
  ) async {
    final response = await ApiClient.post<Map<String, dynamic>>(
      '/contracts/$contractId/revise-compensation',
      body: body,
      parser: (json) => (json is Map<String, dynamic>) ? json : {},
    );

    if (response.isSuccess) return response;

    if (!ApiClient.isBackendOnline || response.statusCode == 0 || response.statusCode == 404) {
      final idx = MockDataService.contracts.indexWhere((c) => c.id == contractId);
      if (idx != -1) {
        final old = MockDataService.contracts[idx];
        final newWage = body['new_wage'] != null ? (body['new_wage'] as num).toDouble() : old.wageMonthly;
        final newStructName = body['new_structure_name']?.toString() ?? old.structureName;
        final updated = ContractModel(
          id: old.id,
          refCode: old.refCode,
          employeeName: old.employeeName,
          department: old.department,
          startDate: body['effective_from']?.toString() ?? old.startDate,
          wageMonthly: newWage,
          status: 'RUNNING',
          structureName: newStructName,
        );
        MockDataService.contracts[idx] = updated;
        return ApiResponse.success({
          'previous_wage': old.wageMonthly,
          'new_wage': newWage,
          'effective_from': body['effective_from'],
          'note': 'Contract compensation revised successfully'
        });
      }
    }

    return response;
  }

  static Future<ApiResponse<List<PayrollAssignmentModel>>> getAssignments({
    String? departmentId,
    String? jobPositionId,
    String? salaryStructureId,
    String? search,
    String? status,
  }) async {
    final query = <String, dynamic>{};
    if (departmentId != null && departmentId.isNotEmpty) query['department_id'] = departmentId;
    if (jobPositionId != null && jobPositionId.isNotEmpty) query['job_position_id'] = jobPositionId;
    if (salaryStructureId != null && salaryStructureId.isNotEmpty) query['salary_structure_id'] = salaryStructureId;
    if (search != null && search.isNotEmpty) query['search'] = search;
    if (status != null && status.isNotEmpty) query['status'] = status;

    final response = await ApiClient.get<List<PayrollAssignmentModel>>(
      '/payroll/assignments',
      queryParams: query,
      parser: (json) {
        if (json is List) {
          return json.map((e) => PayrollAssignmentModel.fromJson(e as Map<String, dynamic>)).toList();
        }
        return [];
      },
    );

    if (response.isSuccess && response.data != null) {
      return response;
    }

    if (!ApiClient.isBackendOnline || response.statusCode == 0 || response.statusCode == 404) {
      final assignments = MockDataService.allEmployees.map((emp) {
        final contract = MockDataService.contracts.firstWhere(
          (c) => c.employeeName.toLowerCase().contains(emp.name.toLowerCase().split(' ').first),
          orElse: () => ContractModel(
            id: 'c-${emp.id}',
            refCode: 'CON/2026/001',
            employeeName: emp.name,
            department: emp.department,
            startDate: '2026-01-01',
            wageMonthly: 85000.0,
            status: 'RUNNING',
            structureName: 'Regular Employee Base',
          ),
        );
        return PayrollAssignmentModel(
          employeeId: emp.id,
          badgeId: emp.badgeId ?? 'EMP${emp.id}',
          employeeName: emp.name,
          departmentId: emp.department,
          departmentName: emp.department,
          jobPositionId: emp.jobTitle,
          jobPositionName: emp.jobTitle,
          contractId: contract.id,
          contractReference: contract.refCode,
          contractStatus: contract.status,
          wageMonthly: contract.wageMonthly,
          salaryStructureId: 'struct-01',
          salaryStructureName: contract.structureName ?? 'Regular Employee Base',
          dateStart: contract.startDate,
        );
      }).toList();
      return ApiResponse.success(assignments);
    }

    return response;
  }
}
