import '../models/models.dart';
import 'api_client.dart';
import 'mock_data_service.dart';

class PayrunService {
  static Future<ApiResponse<List<Map<String, dynamic>>>> getPayruns({
    int limit = 50,
    int offset = 0,
  }) async {
    final query = <String, dynamic>{
      'limit': limit,
      'offset': offset,
    };

    final response = await ApiClient.get<List<Map<String, dynamic>>>(
      '/payruns',
      queryParams: query,
      parser: (json) {
        if (json is List) {
          return json.map((e) => e as Map<String, dynamic>).toList();
        }
        return [];
      },
    );

    if (response.isSuccess && response.data != null && response.data!.isNotEmpty) {
      return response;
    }

    if (!ApiClient.isBackendOnline || response.statusCode == 0) {
      return ApiResponse.success([
        {
          'id': 'payrun_demo_01',
          'name': 'February 2026 Payrun',
          'date_start': '2026-02-01',
          'date_end': '2026-02-28',
          'status': 'CONFIRMED',
          'total_employees': 42,
          'total_cost': 4200000.0,
          'total_net': 3150000.0,
        }
      ]);
    }

    return response;
  }

  static Future<ApiResponse<Map<String, dynamic>>> getPayrun(String id) async {
    return await ApiClient.get<Map<String, dynamic>>(
      '/payruns/$id',
      parser: (json) => json as Map<String, dynamic>,
    );
  }

  static Future<ApiResponse<Map<String, dynamic>>> computeWizardDraft({
    required String name,
    required String dateStart,
    required String dateEnd,
    String? salaryStructureId,
  }) async {
    final body = <String, dynamic>{
      'name': name,
      'date_start': dateStart,
      'date_end': dateEnd,
    };
    if (salaryStructureId != null && salaryStructureId.isNotEmpty) {
      body['salary_structure_id'] = salaryStructureId;
    }

    return await ApiClient.post<Map<String, dynamic>>(
      '/payruns/wizard/compute',
      body: body,
      parser: (json) => json as Map<String, dynamic>,
    );
  }

  static Future<ApiResponse<Map<String, dynamic>>> executePayrun({
    required String payrunId,
    List<String>? selectedEmployeeIds,
  }) async {
    final body = <String, dynamic>{};
    if (selectedEmployeeIds != null && selectedEmployeeIds.isNotEmpty) {
      body['employee_ids'] = selectedEmployeeIds;
    }

    return await ApiClient.post<Map<String, dynamic>>(
      '/payruns/$payrunId/execute',
      body: body,
      parser: (json) => json as Map<String, dynamic>,
    );
  }

  static Future<ApiResponse<List<PayslipModel>>> getPayslips({
    String? payrunId,
    String? employeeId,
    int limit = 100,
    int offset = 0,
  }) async {
    final query = <String, dynamic>{
      'limit': limit,
      'offset': offset,
    };
    if (payrunId != null && payrunId.isNotEmpty) query['payrun_id'] = payrunId;
    if (employeeId != null && employeeId.isNotEmpty) query['employee_id'] = employeeId;

    final response = await ApiClient.get<List<PayslipModel>>(
      '/payruns/payslips',
      queryParams: query,
      parser: (json) {
        if (json is List) {
          return json.map((e) => PayslipModel.fromJson(e as Map<String, dynamic>)).toList();
        }
        return [];
      },
    );

    if (response.isSuccess && response.data != null && response.data!.isNotEmpty) {
      return response;
    }

    if (!ApiClient.isBackendOnline || response.statusCode == 0) {
      return ApiResponse.success(MockDataService.payslips);
    }

    return response;
  }

  static Future<ApiResponse<PayslipModel>> getPayslip(String id) async {
    final response = await ApiClient.get<PayslipModel>(
      '/payruns/payslips/$id',
      parser: (json) => PayslipModel.fromJson(json as Map<String, dynamic>),
    );

    if (response.isSuccess && response.data != null) {
      return response;
    }

    if (!ApiClient.isBackendOnline || response.statusCode == 0) {
      final found = MockDataService.payslips.firstWhere(
        (p) => p.id == id,
        orElse: () => MockDataService.payslips.first,
      );
      return ApiResponse.success(found);
    }

    return response;
  }
}
