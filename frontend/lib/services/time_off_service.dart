import '../models/models.dart';
import 'api_client.dart';
import 'mock_data_service.dart';

class TimeOffService {
  static Future<ApiResponse<List<TimeOffRequestModel>>> getLeaveRequests({
    String? employeeId,
    String? status,
    String? timeOffTypeId,
    int limit = 100,
    int offset = 0,
  }) async {
    final query = <String, dynamic>{
      'limit': limit,
      'offset': offset,
    };
    if (employeeId != null && employeeId.isNotEmpty) query['employee_id'] = employeeId;
    if (status != null && status.isNotEmpty) query['status'] = status;
    if (timeOffTypeId != null && timeOffTypeId.isNotEmpty) query['timeoff_type_id'] = timeOffTypeId;

    final response = await ApiClient.get<List<TimeOffRequestModel>>(
      '/timeoff/requests',
      queryParams: query,
      parser: (json) {
        if (json is List) {
          return json.map((e) => TimeOffRequestModel.fromJson(e as Map<String, dynamic>)).toList();
        }
        return [];
      },
    );

    if (response.isSuccess && response.data != null && response.data!.isNotEmpty) {
      return response;
    }

    if (!ApiClient.isBackendOnline || response.statusCode == 0) {
      return ApiResponse.success(MockDataService.timeOffRequests);
    }

    return response;
  }

  static Future<ApiResponse<TimeOffRequestModel>> createLeaveRequest(Map<String, dynamic> data) async {
    return await ApiClient.post<TimeOffRequestModel>(
      '/timeoff/requests',
      body: data,
      parser: (json) => TimeOffRequestModel.fromJson(json as Map<String, dynamic>),
    );
  }

  static Future<ApiResponse<TimeOffRequestModel>> approveLeaveRequest(String id) async {
    return await ApiClient.post<TimeOffRequestModel>(
      '/timeoff/requests/$id/approve',
      parser: (json) => TimeOffRequestModel.fromJson(json as Map<String, dynamic>),
    );
  }

  static Future<ApiResponse<TimeOffRequestModel>> refuseLeaveRequest(String id, String reason) async {
    return await ApiClient.post<TimeOffRequestModel>(
      '/timeoff/requests/$id/refuse',
      body: {'reason': reason},
      parser: (json) => TimeOffRequestModel.fromJson(json as Map<String, dynamic>),
    );
  }

  static Future<ApiResponse<List<TimeOffTypeModel>>> getTimeOffTypes() async {
    final response = await ApiClient.get<List<TimeOffTypeModel>>(
      '/timeoff/types',
      parser: (json) {
        if (json is List) {
          return json.map((e) => TimeOffTypeModel.fromJson(e as Map<String, dynamic>)).toList();
        }
        return [];
      },
    );

    if (response.isSuccess && response.data != null && response.data!.isNotEmpty) {
      return response;
    }

    if (!ApiClient.isBackendOnline || response.statusCode == 0) {
      return ApiResponse.success([
        TimeOffTypeModel(id: 'type-1', name: 'Paid Time Off (PTO)', code: 'PTO', requiresApproval: true, color: '#714B67'),
        TimeOffTypeModel(id: 'type-2', name: 'Sick Leave', code: 'SICK', requiresApproval: false, color: '#E06D53'),
        TimeOffTypeModel(id: 'type-3', name: 'Casual Leave', code: 'CASUAL', requiresApproval: true, color: '#008075'),
      ]);
    }

    return response;
  }

  static Future<ApiResponse<List<Map<String, dynamic>>>> getLeaveAllocations({String? employeeId}) async {
    final query = <String, dynamic>{};
    if (employeeId != null && employeeId.isNotEmpty) query['employee_id'] = employeeId;

    return await ApiClient.get<List<Map<String, dynamic>>>(
      '/timeoff/allocations',
      queryParams: query,
      parser: (json) {
        if (json is List) {
          return json.map((e) => e as Map<String, dynamic>).toList();
        }
        return [];
      },
    );
  }
}
