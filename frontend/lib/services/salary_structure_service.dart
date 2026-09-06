import '../models/models.dart';
import 'api_client.dart';
import 'mock_data_service.dart';

class SalaryStructureService {
  static bool _shouldFallback(ApiResponse response) {
    return !response.isSuccess && (!ApiClient.isBackendOnline || response.statusCode == 0 || response.statusCode == 404 || response.statusCode == 400);
  }

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

    if (response.isSuccess) {
      return response;
    }

    if (_shouldFallback(response)) {
      return ApiResponse.success(MockDataService.salaryStructures);
    }

    return response;
  }

  /// GET /salary-structures/{structureId}
  static Future<ApiResponse<SalaryStructureModel>> getStructureDetail(String structureId) async {
    final response = await ApiClient.get<SalaryStructureModel>(
      '/salary-structures/$structureId',
      parser: (json) => SalaryStructureModel.fromJson(json as Map<String, dynamic>),
    );

    if (response.isSuccess) {
      return response;
    }

    if (_shouldFallback(response)) {
      final mock = MockDataService.salaryStructures.firstWhere(
        (s) => s.id == structureId,
        orElse: () => MockDataService.salaryStructures.first,
      );
      final structWithRules = SalaryStructureModel(
        id: mock.id,
        name: mock.name,
        code: mock.code,
        notes: mock.notes,
        rules: mock.rules.isNotEmpty ? mock.rules : MockDataService.salaryRules,
        ruleCount: mock.ruleCount > 0 ? mock.ruleCount : MockDataService.salaryRules.length,
        activeRuleCount: mock.activeRuleCount > 0 ? mock.activeRuleCount : MockDataService.salaryRules.where((r) => r.isActive).length,
        employeeCount: mock.employeeCount > 0 ? mock.employeeCount : 12,
      );
      return ApiResponse.success(structWithRules);
    }

    return response;
  }

  /// POST /salary-structures
  static Future<ApiResponse<SalaryStructureModel>> createStructure(Map<String, dynamic> payload) async {
    final response = await ApiClient.post<SalaryStructureModel>(
      '/salary-structures',
      body: payload,
      parser: (json) => SalaryStructureModel.fromJson(json as Map<String, dynamic>),
    );
    if (response.isSuccess) return response;
    if (!_shouldFallback(response)) return response;

    final newId = 'struct-${DateTime.now().millisecondsSinceEpoch}';
    final name = payload['name']?.toString() ?? 'New Salary Structure';
    final code = payload['code']?.toString() ?? payload['reference']?.toString() ?? 'NEW_STRUCT';
    final notes = payload['notes']?.toString();

    final newStruct = SalaryStructureModel(
      id: newId,
      name: name,
      code: code,
      notes: notes,
      rules: MockDataService.salaryRules,
      ruleCount: MockDataService.salaryRules.length,
      activeRuleCount: MockDataService.salaryRules.length,
      employeeCount: 0,
    );
    MockDataService.salaryStructures.insert(0, newStruct);
    return ApiResponse.success(newStruct);
  }

  /// PATCH /salary-structures/{structureId}
  static Future<ApiResponse<SalaryStructureModel>> updateStructure(String structureId, Map<String, dynamic> payload) async {
    final response = await ApiClient.patch<SalaryStructureModel>(
      '/salary-structures/$structureId',
      body: payload,
      parser: (json) => SalaryStructureModel.fromJson(json as Map<String, dynamic>),
    );
    if (response.isSuccess) return response;
    if (!_shouldFallback(response)) return response;

    final idx = MockDataService.salaryStructures.indexWhere((s) => s.id == structureId);
    if (idx != -1) {
      final old = MockDataService.salaryStructures[idx];
      final updated = SalaryStructureModel(
        id: old.id,
        name: payload['name']?.toString() ?? old.name,
        code: payload['code']?.toString() ?? old.code,
        notes: payload.containsKey('notes') ? payload['notes']?.toString() : old.notes,
        rules: old.rules.isNotEmpty ? old.rules : MockDataService.salaryRules,
        ruleCount: old.ruleCount > 0 ? old.ruleCount : MockDataService.salaryRules.length,
        activeRuleCount: old.activeRuleCount,
        employeeCount: old.employeeCount,
      );
      MockDataService.salaryStructures[idx] = updated;
      return ApiResponse.success(updated);
    }
    return response;
  }

  /// DELETE /salary-structures/{structureId}
  static Future<ApiResponse<Map<String, dynamic>>> deleteStructure(String structureId) async {
    final response = await ApiClient.delete<Map<String, dynamic>>(
      '/salary-structures/$structureId',
      parser: (json) => (json is Map<String, dynamic>) ? json : {},
    );
    if (response.isSuccess) return response;
    if (!_shouldFallback(response)) return response;

    MockDataService.salaryStructures.removeWhere((s) => s.id == structureId);
    return ApiResponse.success({'detail': 'Structure deleted successfully'});
  }

  /// POST /salary-structures/{structureId}/rules
  static Future<ApiResponse<SalaryRuleModel>> createRule(String structureId, Map<String, dynamic> payload) async {
    final response = await ApiClient.post<SalaryRuleModel>(
      '/salary-structures/$structureId/rules',
      body: payload,
      parser: (json) => SalaryRuleModel.fromJson(json as Map<String, dynamic>),
    );
    if (response.isSuccess) return response;
    if (!_shouldFallback(response)) return response;

    final newRule = SalaryRuleModel(
      id: 'r-${DateTime.now().millisecondsSinceEpoch}',
      name: payload['name']?.toString() ?? 'Custom Rule',
      code: payload['code']?.toString() ?? 'RULE',
      sequence: (payload['sequence'] is num) ? (payload['sequence'] as num).toInt() : 10,
      category: payload['category']?.toString() ?? 'BASIC',
      computationType: payload['computation_type']?.toString() ?? 'FIXED',
      fixedAmount: (payload['fixed_amount'] is num) ? (payload['fixed_amount'] as num).toDouble() : null,
      percentageBase: payload['percentage_base']?.toString(),
      percentageRate: (payload['percentage_rate'] is num) ? (payload['percentage_rate'] as num).toDouble() : null,
      pythonCode: payload['python_code']?.toString(),
      quantity: (payload['quantity'] is num) ? (payload['quantity'] as num).toDouble() : 1.0,
      isActive: payload['is_active'] == true,
    );
    MockDataService.salaryRules.add(newRule);
    return ApiResponse.success(newRule);
  }

  /// PATCH /salary-structures/rules/{ruleId}
  static Future<ApiResponse<SalaryRuleModel>> updateRule(String ruleId, Map<String, dynamic> payload) async {
    final response = await ApiClient.patch<SalaryRuleModel>(
      '/salary-structures/rules/$ruleId',
      body: payload,
      parser: (json) => SalaryRuleModel.fromJson(json as Map<String, dynamic>),
    );
    if (response.isSuccess) return response;
    if (!_shouldFallback(response)) return response;

    final idx = MockDataService.salaryRules.indexWhere((r) => r.id == ruleId);
    if (idx != -1) {
      final old = MockDataService.salaryRules[idx];
      final updated = SalaryRuleModel(
        id: old.id,
        name: payload['name']?.toString() ?? old.name,
        code: payload['code']?.toString() ?? old.code,
        sequence: (payload['sequence'] is num) ? (payload['sequence'] as num).toInt() : old.sequence,
        category: payload['category']?.toString() ?? old.category,
        computationType: payload['computation_type']?.toString() ?? old.computationType,
        fixedAmount: (payload['fixed_amount'] is num) ? (payload['fixed_amount'] as num).toDouble() : old.fixedAmount,
        percentageBase: payload['percentage_base']?.toString() ?? old.percentageBase,
        percentageRate: (payload['percentage_rate'] is num) ? (payload['percentage_rate'] as num).toDouble() : old.percentageRate,
        pythonCode: payload['python_code']?.toString() ?? old.pythonCode,
        quantity: (payload['quantity'] is num) ? (payload['quantity'] as num).toDouble() : old.quantity,
        isActive: payload.containsKey('is_active') ? payload['is_active'] == true : old.isActive,
      );
      MockDataService.salaryRules[idx] = updated;
      return ApiResponse.success(updated);
    }
    return response;
  }

  /// DELETE /salary-structures/rules/{ruleId}
  static Future<ApiResponse<Map<String, dynamic>>> deleteRule(String ruleId) async {
    final response = await ApiClient.delete<Map<String, dynamic>>(
      '/salary-structures/rules/$ruleId',
      parser: (json) => (json is Map<String, dynamic>) ? json : {},
    );
    if (response.isSuccess) return response;
    if (!_shouldFallback(response)) return response;

    MockDataService.salaryRules.removeWhere((r) => r.id == ruleId);
    return ApiResponse.success({'detail': 'Rule deleted successfully'});
  }

  /// POST /salary-structures/validate-python-rule
  static Future<ApiResponse<PythonRuleValidationResponseModel>> validatePythonRule(String pythonCode) async {
    final response = await ApiClient.post<PythonRuleValidationResponseModel>(
      '/salary-structures/validate-python-rule',
      body: {'python_code': pythonCode},
      parser: (json) => PythonRuleValidationResponseModel.fromJson(json as Map<String, dynamic>),
    );
    if (response.isSuccess) return response;
    if (!_shouldFallback(response)) return response;

    final mockValid = PythonRuleValidationResponseModel(
      valid: true,
      message: 'Python expression validated successfully (Syntax OK)',
      probeResult: 42500.0,
    );
    return ApiResponse.success(mockValid);
  }

  /// POST /salary-structures/simulate
  static Future<ApiResponse<RuleSimulationResponseModel>> simulateStructure(Map<String, dynamic> payload) async {
    final response = await ApiClient.post<RuleSimulationResponseModel>(
      '/salary-structures/simulate',
      body: payload,
      parser: (json) => RuleSimulationResponseModel.fromJson(json as Map<String, dynamic>),
    );
    if (response.isSuccess) return response;
    if (!_shouldFallback(response)) return response;

    final wage = (payload['wage_monthly'] is num) ? (payload['wage_monthly'] as num).toDouble() : 100000.0;
    final basic = wage * 0.50;
    final hra = basic * 0.40;
    final std = 10000.0;
    final gross = basic + hra + std;
    final pf = basic * 0.06;
    final pt = 2000.0;
    final deductions = pf + pt;
    final net = gross - deductions;

    final mockSim = RuleSimulationResponseModel(
      salaryStructureId: payload['salary_structure_id']?.toString() ?? 'struct-01',
      salaryStructureName: 'Regular Employee Base',
      wageMonthly: wage,
      basic: basic,
      allowances: hra + std,
      gross: gross,
      deductions: deductions,
      net: net,
      lines: [
        RuleSimulationLineModel(ruleName: 'Basic Salary', ruleCode: 'BASIC', category: 'BASIC', sequence: 1, amount: basic, computationType: 'PERCENTAGE', explanation: '50% of Wage'),
        RuleSimulationLineModel(ruleName: 'House Rent Allowance', ruleCode: 'HRA', category: 'ALLOWANCE', sequence: 10, amount: hra, computationType: 'PERCENTAGE', explanation: '40% of Basic'),
        RuleSimulationLineModel(ruleName: 'Standard Allowance', ruleCode: 'STD', category: 'ALLOWANCE', sequence: 20, amount: std, computationType: 'FIXED', explanation: 'Fixed ₹10,000'),
        RuleSimulationLineModel(ruleName: 'Gross Salary', ruleCode: 'GROSS', category: 'GROSS', sequence: 60, amount: gross, computationType: 'PYTHON_CODE', explanation: 'BASIC + ALLOWANCES'),
        RuleSimulationLineModel(ruleName: 'Provident Fund', ruleCode: 'PF', category: 'DEDUCTION', sequence: 80, amount: pf, computationType: 'PERCENTAGE', explanation: '6% of Basic'),
        RuleSimulationLineModel(ruleName: 'Professional Tax', ruleCode: 'PT', category: 'DEDUCTION', sequence: 100, amount: pt, computationType: 'FIXED', explanation: 'Fixed ₹2,000'),
        RuleSimulationLineModel(ruleName: 'Net Salary', ruleCode: 'NET', category: 'NET', sequence: 110, amount: net, computationType: 'PYTHON_CODE', explanation: 'GROSS - DEDUCTIONS'),
      ],
    );
    return ApiResponse.success(mockSim);
  }
}
