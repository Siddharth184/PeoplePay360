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

    if (response.isSuccess && response.data != null) {
      return response;
    }

    if (!ApiClient.isBackendOnline || response.statusCode == 0 || !response.isSuccess) {
      List<TimeOffRequestModel> list = List.from(MockDataService.timeOffRequests);
      if (employeeId != null && employeeId.isNotEmpty) {
        list = list.where((r) => r.employeeId == employeeId || r.employeeId == null).toList();
      }
      if (status != null && status.isNotEmpty) {
        final normStatus = status == 'PENDING' ? 'TO_APPROVE' : status;
        list = list.where((r) => r.status == normStatus).toList();
      }
      if (timeOffTypeId != null && timeOffTypeId.isNotEmpty) {
        list = list.where((r) => r.timeoffTypeId == timeOffTypeId).toList();
      }
      return ApiResponse.success(list);
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

  static Future<ApiResponse<TimeOffRequestModel>> createLeaveRequestSelf({
    required String timeOffTypeId,
    required String startDate,
    required String endDate,
    String? reason,
    String? dayPart,
  }) async {
    final body = <String, dynamic>{
      'timeoff_type_id': timeOffTypeId,
      'start_date': startDate,
      'end_date': endDate,
      if (reason != null && reason.isNotEmpty) 'reason': reason,
      if (dayPart != null && dayPart.isNotEmpty) 'day_part': dayPart,
    };
    final response = await ApiClient.post<TimeOffRequestModel>(
      '/timeoff/requests',
      body: body,
      parser: (json) => TimeOffRequestModel.fromJson(json as Map<String, dynamic>),
    );

    if (response.isSuccess && response.data != null) {
      return response;
    }

    if (!ApiClient.isBackendOnline || response.statusCode == 0 || !response.isSuccess) {
      TimeOffTypeModel? matchedType;
      try {
        matchedType = MockDataService.timeOffTypes.firstWhere((t) => t.id == timeOffTypeId);
      } catch (_) {}

      final days = (dayPart == 'FIRST_HALF' || dayPart == 'SECOND_HALF') ? 0.5 : 1.0;

      final mockReq = TimeOffRequestModel(
        id: 'req-${DateTime.now().millisecondsSinceEpoch}',
        employeeId: ApiClient.currentEmployeeId ?? 'emp-001',
        employeeName: ApiClient.currentEmployeeName ?? 'Aarav Mehta',
        timeoffTypeId: timeOffTypeId,
        typeName: matchedType?.name ?? 'Paid Time Off',
        startDate: startDate,
        endDate: endDate,
        daysCount: days,
        status: 'TO_APPROVE',
        reason: reason ?? 'Personal Leave',
        createdAt: DateTime.now().toIso8601String(),
      );

      MockDataService.timeOffRequests.insert(0, mockReq);
      return ApiResponse.success(mockReq);
    }

    return response;
  }

  static Future<ApiResponse<TimeOffRequestModel>> createLeaveRequestOnBehalf({
    required String timeOffTypeId,
    required String startDate,
    required String endDate,
    required String employeeId,
    String? reason,
    String? dayPart,
  }) async {
    final body = <String, dynamic>{
      'timeoff_type_id': timeOffTypeId,
      'start_date': startDate,
      'end_date': endDate,
      'employee_id': employeeId,
      if (reason != null && reason.isNotEmpty) 'reason': reason,
      if (dayPart != null && dayPart.isNotEmpty) 'day_part': dayPart,
    };
    final response = await ApiClient.post<TimeOffRequestModel>(
      '/timeoff/requests',
      body: body,
      parser: (json) => TimeOffRequestModel.fromJson(json as Map<String, dynamic>),
    );

    if (response.isSuccess && response.data != null) {
      return response;
    }

    if (!ApiClient.isBackendOnline || response.statusCode == 0 || !response.isSuccess) {
      TimeOffTypeModel? matchedType;
      try {
        matchedType = MockDataService.timeOffTypes.firstWhere((t) => t.id == timeOffTypeId);
      } catch (_) {}

      String empName = 'Employee';
      final match = MockDataService.allEmployees.where((e) => e.id == employeeId);
      if (match.isNotEmpty) empName = match.first.name;

      final days = (dayPart == 'FIRST_HALF' || dayPart == 'SECOND_HALF') ? 0.5 : 1.0;

      final mockReq = TimeOffRequestModel(
        id: 'req-${DateTime.now().millisecondsSinceEpoch}',
        employeeId: employeeId,
        employeeName: empName,
        timeoffTypeId: timeOffTypeId,
        typeName: matchedType?.name ?? 'Paid Time Off',
        startDate: startDate,
        endDate: endDate,
        daysCount: days,
        status: 'TO_APPROVE',
        reason: reason ?? 'Leave granted by HR',
        createdAt: DateTime.now().toIso8601String(),
      );

      MockDataService.timeOffRequests.insert(0, mockReq);
      return ApiResponse.success(mockReq);
    }

    return response;
  }

  static Future<ApiResponse<TimeOffRequestModel>> approveLeaveRequest(String id) async {
    final response = await ApiClient.post<TimeOffRequestModel>(
      '/timeoff/requests/$id/approve',
      parser: (json) => TimeOffRequestModel.fromJson(json as Map<String, dynamic>),
    );

    if (response.isSuccess && response.data != null) {
      return response;
    }

    if (!ApiClient.isBackendOnline || response.statusCode == 0 || !response.isSuccess) {
      final idx = MockDataService.timeOffRequests.indexWhere((r) => r.id == id);
      if (idx >= 0) {
        final old = MockDataService.timeOffRequests[idx];
        final updated = TimeOffRequestModel(
          id: old.id,
          employeeId: old.employeeId,
          employeeName: old.employeeName,
          timeoffTypeId: old.timeoffTypeId,
          typeName: old.typeName,
          startDate: old.startDate,
          endDate: old.endDate,
          daysCount: old.daysCount,
          status: 'APPROVED',
          reason: old.reason,
          approverEmployeeId: ApiClient.currentEmployeeId ?? 'emp-004',
          createdAt: old.createdAt,
        );
        MockDataService.timeOffRequests[idx] = updated;
        MockDataService.updateLeaveBalance(old.timeoffTypeId ?? '', old.typeName, old.daysCount);
        return ApiResponse.success(updated);
      }
    }

    return response;
  }

  static Future<ApiResponse<TimeOffRequestModel>> refuseLeaveRequest(String id, String reason) async {
    final response = await ApiClient.post<TimeOffRequestModel>(
      '/timeoff/requests/$id/refuse',
      body: {'reason': reason},
      parser: (json) => TimeOffRequestModel.fromJson(json as Map<String, dynamic>),
    );

    if (response.isSuccess && response.data != null) {
      return response;
    }

    if (!ApiClient.isBackendOnline || response.statusCode == 0 || !response.isSuccess) {
      final idx = MockDataService.timeOffRequests.indexWhere((r) => r.id == id);
      if (idx >= 0) {
        final old = MockDataService.timeOffRequests[idx];
        final updated = TimeOffRequestModel(
          id: old.id,
          employeeId: old.employeeId,
          employeeName: old.employeeName,
          timeoffTypeId: old.timeoffTypeId,
          typeName: old.typeName,
          startDate: old.startDate,
          endDate: old.endDate,
          daysCount: old.daysCount,
          status: 'REFUSED',
          reason: reason.isNotEmpty ? reason : old.reason,
          approverEmployeeId: ApiClient.currentEmployeeId ?? 'emp-004',
          createdAt: old.createdAt,
        );
        MockDataService.timeOffRequests[idx] = updated;
        return ApiResponse.success(updated);
      }
    }

    return response;
  }

  static Future<ApiResponse<TimeOffRequestModel>> cancelLeaveRequest(String id) async {
    final response = await ApiClient.post<TimeOffRequestModel>(
      '/timeoff/requests/$id/cancel',
      parser: (json) => TimeOffRequestModel.fromJson(json as Map<String, dynamic>),
    );

    if (response.isSuccess && response.data != null) {
      return response;
    }

    if (!ApiClient.isBackendOnline || response.statusCode == 0 || !response.isSuccess) {
      final idx = MockDataService.timeOffRequests.indexWhere((r) => r.id == id);
      if (idx >= 0) {
        final old = MockDataService.timeOffRequests[idx];
        if (old.status == 'APPROVED') {
          MockDataService.updateLeaveBalance(old.timeoffTypeId ?? '', old.typeName, -old.daysCount);
        }
        final updated = TimeOffRequestModel(
          id: old.id,
          employeeId: old.employeeId,
          employeeName: old.employeeName,
          timeoffTypeId: old.timeoffTypeId,
          typeName: old.typeName,
          startDate: old.startDate,
          endDate: old.endDate,
          daysCount: old.daysCount,
          status: 'CANCELLED',
          reason: old.reason,
          createdAt: old.createdAt,
        );
        MockDataService.timeOffRequests[idx] = updated;
        return ApiResponse.success(updated);
      }
    }

    return response;
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

    return ApiResponse.success(MockDataService.timeOffTypes);
  }

  static Future<ApiResponse<List<LeaveAllocationModel>>> getLeaveAllocations({String? employeeId}) async {
    final query = <String, dynamic>{};
    if (employeeId != null && employeeId.isNotEmpty) query['employee_id'] = employeeId;

    return await ApiClient.get<List<LeaveAllocationModel>>(
      '/timeoff/allocations',
      queryParams: query,
      parser: (json) {
        if (json is List) {
          return json.map((e) => LeaveAllocationModel.fromJson(e as Map<String, dynamic>)).toList();
        }
        return [];
      },
    );
  }

  static Future<ApiResponse<List<LeaveBalanceModel>>> getLeaveBalances({String? employeeId}) async {
    final query = <String, dynamic>{};
    if (employeeId != null && employeeId.isNotEmpty) query['employee_id'] = employeeId;

    final response = await ApiClient.get<List<LeaveBalanceModel>>(
      '/timeoff/balance',
      queryParams: query,
      parser: (json) {
        if (json is List) {
          return json.map((e) => LeaveBalanceModel.fromJson(e as Map<String, dynamic>)).toList();
        }
        return [];
      },
    );

    if (response.isSuccess && response.data != null && response.data!.isNotEmpty) {
      return response;
    }

    return ApiResponse.success(MockDataService.getLeaveBalances(employeeId));
  }

  static Future<ApiResponse<Map<String, dynamic>>> getDurationPreview({
    required String startDate,
    required String endDate,
    String? employeeId,
    String? dayPart,
  }) async {
    final query = <String, dynamic>{
      'start_date': startDate,
      'end_date': endDate,
    };
    if (employeeId != null && employeeId.isNotEmpty) query['employee_id'] = employeeId;
    if (dayPart != null && dayPart.isNotEmpty) query['day_part'] = dayPart;

    final response = await ApiClient.get<Map<String, dynamic>>(
      '/timeoff/requests/duration-preview',
      queryParams: query,
      parser: (json) => json as Map<String, dynamic>,
    );

    if (response.isSuccess && response.data != null && response.data!['working_days'] != null) {
      return response;
    }

    // Dynamic client-side calculation fallback
    try {
      final start = DateTime.parse(startDate);
      final end = DateTime.parse(endDate);
      if (end.isBefore(start)) {
        return ApiResponse.success({'working_days': 1.0});
      }
      double totalDays = 0;
      for (var d = start; !d.isAfter(end); d = d.add(const Duration(days: 1))) {
        if (d.weekday != DateTime.saturday && d.weekday != DateTime.sunday) {
          totalDays += 1.0;
        }
      }
      if (start.year == end.year && start.month == end.month && start.day == end.day) {
        if (dayPart == 'FIRST_HALF' || dayPart == 'SECOND_HALF') {
          totalDays = 0.5;
        }
      }
      return ApiResponse.success({'working_days': totalDays > 0 ? totalDays : 1.0});
    } catch (_) {
      return ApiResponse.success({'working_days': 1.0});
    }
  }

  static Future<ApiResponse<LeaveAllocationModel>> createAllocation(Map<String, dynamic> data) async {
    return await ApiClient.post<LeaveAllocationModel>(
      '/timeoff/allocations',
      body: data,
      parser: (json) => LeaveAllocationModel.fromJson(json as Map<String, dynamic>),
    );
  }

  static Future<ApiResponse<LeaveAllocationModel>> updateAllocation(String id, Map<String, dynamic> data) async {
    return await ApiClient.patch<LeaveAllocationModel>(
      '/timeoff/allocations/$id',
      body: data,
      parser: (json) => LeaveAllocationModel.fromJson(json as Map<String, dynamic>),
    );
  }
}
