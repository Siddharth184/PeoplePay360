import '../models/models.dart';
import 'api_client.dart';
import 'mock_data_service.dart';

class SalaryStructureService {
  static Future<ApiResponse<List<SalaryStructureModel>>> getStructures() async {
    final response = await ApiClient.get<List<SalaryStructureModel>>(
      '/salary-structures',
      parser: (json) {
        if (json is List) {
          return json.map((e) => SalaryStructureModel.fromJson(e as Map<String, dynamic>)).toList();
        }
        return [];
      },
    );

    if (response.isSuccess && response.data != null && response.data!.isNotEmpty) {
      return response;
    }

    if (!ApiClient.isBackendOnline || response.statusCode == 0) {
      return ApiResponse.success([
        SalaryStructureModel(
          id: 'struct-1',
          name: 'Regular Salary',
          reference: 'REG_SALARY',
          country: 'India',
          ruleIds: MockDataService.salaryRules.map((r) => r.id).toList(),
        )
      ]);
    }

    return response;
  }

  static Future<ApiResponse<List<SalaryRuleModel>>> getRules({String? structureId}) async {
    final path = structureId != null ? '/salary-structures/$structureId/rules' : '/salary-structures/rules';
    final response = await ApiClient.get<List<SalaryRuleModel>>(
      path,
      parser: (json) {
        if (json is List) {
          return json.map((e) => SalaryRuleModel.fromJson(e as Map<String, dynamic>)).toList();
        }
        return [];
      },
    );

    if (response.isSuccess && response.data != null && response.data!.isNotEmpty) {
      return response;
    }

    if (!ApiClient.isBackendOnline || response.statusCode == 0) {
      return ApiResponse.success(MockDataService.salaryRules);
    }

    return response;
  }

  static Future<ApiResponse<SalaryRuleModel>> createRule(String structureId, Map<String, dynamic> data) async {
    return await ApiClient.post<SalaryRuleModel>(
      '/salary-structures/$structureId/rules',
      body: data,
      parser: (json) => SalaryRuleModel.fromJson(json as Map<String, dynamic>),
    );
  }

  static Future<ApiResponse<SalaryRuleModel>> updateRule(String ruleId, Map<String, dynamic> data) async {
    return await ApiClient.put<SalaryRuleModel>(
      '/salary-structures/rules/$ruleId',
      body: data,
      parser: (json) => SalaryRuleModel.fromJson(json as Map<String, dynamic>),
    );
  }
}
