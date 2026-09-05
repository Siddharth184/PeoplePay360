import '../models/models.dart';
import 'api_client.dart';

class SalaryStructureService {
  /// GET /salary-structures
  static Future<ApiResponse<List<SalaryStructureModel>>> getStructures() async {
    final response = await ApiClient.get<List<SalaryStructureModel>>(
      '/salary-structures',
      parser: (json) {
        if (json is List) {
          return json
              .whereType<Map<String, dynamic>>()
              .map((e) => SalaryStructureModel.fromJson(e))
              .toList();
        }
        return [];
      },
    );

    if (response.isSuccess && response.data != null) {
      return response;
    }

    if (!ApiClient.isBackendOnline || response.statusCode == 0) {
      return ApiResponse.success(<SalaryStructureModel>[]);
    }

    return response;
  }

  /// GET /salary-structures/{structureId}
  static Future<ApiResponse<SalaryStructureModel>> getStructureDetail(String structureId) async {
    final response = await ApiClient.get<SalaryStructureModel>(
      '/salary-structures/$structureId',
      parser: (json) => SalaryStructureModel.fromJson(json as Map<String, dynamic>),
    );

    if (response.isSuccess && response.data != null) {
      return response;
    }

    // No mock fallback — return the error response as-is

    return response;
  }

  /// POST /salary-structures
  static Future<ApiResponse<SalaryStructureModel>> createStructure(Map<String, dynamic> payload) async {
    return await ApiClient.post<SalaryStructureModel>(
      '/salary-structures',
      body: payload,
      parser: (json) => SalaryStructureModel.fromJson(json as Map<String, dynamic>),
    );
  }

  /// PATCH /salary-structures/{structureId}
  static Future<ApiResponse<SalaryStructureModel>> updateStructure(String structureId, Map<String, dynamic> payload) async {
    return await ApiClient.patch<SalaryStructureModel>(
      '/salary-structures/$structureId',
      body: payload,
      parser: (json) => SalaryStructureModel.fromJson(json as Map<String, dynamic>),
    );
  }

  /// DELETE /salary-structures/{structureId}
  static Future<ApiResponse<Map<String, dynamic>>> deleteStructure(String structureId) async {
    return await ApiClient.delete<Map<String, dynamic>>(
      '/salary-structures/$structureId',
      parser: (json) => (json is Map<String, dynamic>) ? json : {},
    );
  }

  /// POST /salary-structures/{structureId}/rules
  static Future<ApiResponse<SalaryRuleModel>> createRule(String structureId, Map<String, dynamic> payload) async {
    return await ApiClient.post<SalaryRuleModel>(
      '/salary-structures/$structureId/rules',
      body: payload,
      parser: (json) => SalaryRuleModel.fromJson(json as Map<String, dynamic>),
    );
  }

  /// PATCH /salary-structures/rules/{ruleId}
  static Future<ApiResponse<SalaryRuleModel>> updateRule(String ruleId, Map<String, dynamic> payload) async {
    return await ApiClient.patch<SalaryRuleModel>(
      '/salary-structures/rules/$ruleId',
      body: payload,
      parser: (json) => SalaryRuleModel.fromJson(json as Map<String, dynamic>),
    );
  }

  /// DELETE /salary-structures/rules/{ruleId}
  static Future<ApiResponse<Map<String, dynamic>>> deleteRule(String ruleId) async {
    return await ApiClient.delete<Map<String, dynamic>>(
      '/salary-structures/rules/$ruleId',
      parser: (json) => (json is Map<String, dynamic>) ? json : {},
    );
  }

  /// POST /salary-structures/validate-python-rule
  static Future<ApiResponse<PythonRuleValidationResponseModel>> validatePythonRule(String pythonCode) async {
    return await ApiClient.post<PythonRuleValidationResponseModel>(
      '/salary-structures/validate-python-rule',
      body: {'python_code': pythonCode},
      parser: (json) => PythonRuleValidationResponseModel.fromJson(json as Map<String, dynamic>),
    );
  }

  /// POST /salary-structures/simulate
  static Future<ApiResponse<RuleSimulationResponseModel>> simulateStructure(Map<String, dynamic> payload) async {
    return await ApiClient.post<RuleSimulationResponseModel>(
      '/salary-structures/simulate',
      body: payload,
      parser: (json) => RuleSimulationResponseModel.fromJson(json as Map<String, dynamic>),
    );
  }
}
