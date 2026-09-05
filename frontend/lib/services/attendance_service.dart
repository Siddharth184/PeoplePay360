import '../models/models.dart';
import 'api_client.dart';
import 'mock_data_service.dart';

class AttendanceService {
  static Future<ApiResponse<Map<String, dynamic>>> punch({
    String? employeeId,
    String? note,
  }) async {
    final body = <String, dynamic>{};
    if (employeeId != null && employeeId.isNotEmpty) body['employee_id'] = employeeId;
    if (note != null && note.isNotEmpty) body['note'] = note;

    final response = await ApiClient.post<Map<String, dynamic>>(
      '/attendance/punch',
      body: body,
      parser: (json) => json as Map<String, dynamic>,
    );

    if (response.isSuccess && response.data != null) {
      return response;
    }

    if (!ApiClient.isBackendOnline || response.statusCode == 0) {
      final now = DateTime.now();
      final hr = now.hour % 12 == 0 ? 12 : now.hour % 12;
      final ampm = now.hour >= 12 ? 'PM' : 'AM';
      final timeStr = "${hr.toString().padLeft(2, '0')}:${now.minute.toString().padLeft(2, '0')} $ampm";
      
      return ApiResponse.success({
        'action': 'CHECK_IN',
        'elapsed_hours': 0.1,
        'time_str': timeStr,
        'attendance': {
          'id': 'att_local_${now.millisecondsSinceEpoch}',
          'employee_name': MockDataService.currentEmployee.name,
          'check_in': now.toIso8601String(),
          'worked_hours': 0.0,
          'status': 'PRESENT',
        }
      });
    }

    return response;
  }

  static Future<ApiResponse<Map<String, dynamic>>> getPunchStatus() async {
    final response = await ApiClient.get<Map<String, dynamic>>(
      '/attendance/status',
      parser: (json) => json as Map<String, dynamic>,
    );

    if (response.isSuccess && response.data != null) {
      return response;
    }

    if (!ApiClient.isBackendOnline || response.statusCode == 0) {
      return ApiResponse.success({
        'checked_in': false,
        'since': null,
        'elapsed_hours': 0.0,
      });
    }

    return response;
  }

  static Future<ApiResponse<List<AttendanceModel>>> getAttendanceLogs({
    String? employeeId,
    String? dateStart,
    String? dateEnd,
    int limit = 100,
    int offset = 0,
  }) async {
    final query = <String, dynamic>{
      'limit': limit,
      'offset': offset,
    };
    if (employeeId != null && employeeId.isNotEmpty) query['employee_id'] = employeeId;
    if (dateStart != null && dateStart.isNotEmpty) query['date_start'] = dateStart;
    if (dateEnd != null && dateEnd.isNotEmpty) query['date_end'] = dateEnd;

    final response = await ApiClient.get<List<AttendanceModel>>(
      '/attendance',
      queryParams: query,
      parser: (json) {
        if (json is List) {
          return json.map((e) => AttendanceModel.fromJson(e as Map<String, dynamic>)).toList();
        }
        return [];
      },
    );

    if (response.isSuccess && response.data != null && response.data!.isNotEmpty) {
      return response;
    }

    if (!ApiClient.isBackendOnline || response.statusCode == 0) {
      return ApiResponse.success(MockDataService.attendances);
    }

    return response;
  }

  static Future<ApiResponse<AttendanceModel>> upsertManualAttendance(Map<String, dynamic> data) async {
    return await ApiClient.post<AttendanceModel>(
      '/attendance/manual',
      body: data,
      parser: (json) => AttendanceModel.fromJson(json as Map<String, dynamic>),
    );
  }
}
