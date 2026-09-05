import 'api_client.dart';

class DashboardService {
  static Future<ApiResponse<Map<String, dynamic>>> getMetrics({
    String? dateStart,
    String? dateEnd,
    String? payrunId,
    String? departmentId,
    String? employeeType,
    String? companyName,
  }) async {
    final query = <String, dynamic>{};
    if (dateStart != null && dateStart.isNotEmpty) query['date_start'] = dateStart;
    if (dateEnd != null && dateEnd.isNotEmpty) query['date_end'] = dateEnd;
    if (payrunId != null && payrunId.isNotEmpty) query['payrun_id'] = payrunId;
    if (departmentId != null && departmentId.isNotEmpty) query['department_id'] = departmentId;
    if (employeeType != null && employeeType.isNotEmpty) query['employee_type'] = employeeType;
    if (companyName != null && companyName.isNotEmpty) query['company_name'] = companyName;

    return await ApiClient.get<Map<String, dynamic>>(
      '/dashboard/metrics',
      queryParams: query,
      parser: (json) => json as Map<String, dynamic>,
    );
  }

  static Future<ApiResponse<Map<String, dynamic>>> getFilterOptions() async {
    return await ApiClient.get<Map<String, dynamic>>(
      '/dashboard/filters',
      parser: (json) => json as Map<String, dynamic>,
    );
  }

  static Future<ApiResponse<List<Map<String, dynamic>>>> getDepartmentCosts({
    String? dateStart,
    String? dateEnd,
    String? payrunId,
  }) async {
    final query = <String, dynamic>{};
    if (dateStart != null && dateStart.isNotEmpty) query['date_start'] = dateStart;
    if (dateEnd != null && dateEnd.isNotEmpty) query['date_end'] = dateEnd;
    if (payrunId != null && payrunId.isNotEmpty) query['payrun_id'] = payrunId;

    return await ApiClient.get<List<Map<String, dynamic>>>(
      '/dashboard/department-costs',
      queryParams: query,
      parser: (json) {
        if (json is List) {
          return json.map((e) => e as Map<String, dynamic>).toList();
        }
        return [];
      },
    );
  }

  static Future<ApiResponse<List<Map<String, dynamic>>>> getPayrollTrend({int months = 6}) async {
    return await ApiClient.get<List<Map<String, dynamic>>>(
      '/dashboard/payroll-trend',
      queryParams: {'months': months},
      parser: (json) {
        if (json is List) {
          return json.map((e) => e as Map<String, dynamic>).toList();
        }
        return [];
      },
    );
  }
}
