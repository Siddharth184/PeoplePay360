import '../models/models.dart';
import 'api_client.dart';
import 'mock_data_service.dart';

class ShiftConfig {
  final String day;
  final String startTime;
  final String endTime;
  final int breakMinutes;

  ShiftConfig({
    required this.day,
    this.startTime = '09:00 AM',
    this.endTime = '06:00 PM',
    this.breakMinutes = 60,
  });

  double get calculatedHours {
    final startMin = _parseTimeToMinutes(startTime);
    final endMin = _parseTimeToMinutes(endTime);
    int workMin = endMin - startMin - breakMinutes;
    if (workMin < 0) workMin = 0;
    return workMin / 60.0;
  }

  static int _parseTimeToMinutes(String tStr) {
    try {
      final parts = tStr.trim().split(' ');
      final timeParts = parts[0].split(':');
      int hours = int.parse(timeParts[0]);
      final minutes = int.parse(timeParts[1]);
      if (parts.length > 1 && parts[1].toUpperCase() == 'PM' && hours != 12) hours += 12;
      if (parts.length > 1 && parts[1].toUpperCase() == 'AM' && hours == 12) hours = 0;
      return hours * 60 + minutes;
    } catch (_) {
      return 9 * 60;
    }
  }
}

class WorkingScheduleService {
  static List<ShiftConfig> _activeShifts = [
    ShiftConfig(day: 'Monday', startTime: '09:00 AM', endTime: '06:00 PM', breakMinutes: 60),
    ShiftConfig(day: 'Tuesday', startTime: '09:00 AM', endTime: '06:00 PM', breakMinutes: 60),
    ShiftConfig(day: 'Wednesday', startTime: '09:00 AM', endTime: '06:00 PM', breakMinutes: 60),
    ShiftConfig(day: 'Thursday', startTime: '09:00 AM', endTime: '06:00 PM', breakMinutes: 60),
    ShiftConfig(day: 'Friday', startTime: '09:00 AM', endTime: '06:00 PM', breakMinutes: 60),
  ];

  static List<ShiftConfig> get activeShifts => List.unmodifiable(_activeShifts);

  static void setActiveShifts(List<ShiftConfig> shifts) {
    _activeShifts = List.from(shifts);
  }

  static int getBreakMinutesForDate(DateTime dt) {
    final days = ['Monday', 'Tuesday', 'Wednesday', 'Thursday', 'Friday', 'Saturday', 'Sunday'];
    final dayName = days[dt.weekday - 1];
    final match = _activeShifts.where((s) => s.day.toLowerCase() == dayName.toLowerCase());
    if (match.isNotEmpty) {
      return match.first.breakMinutes;
    }
    return 60;
  }

  static double getTargetHoursForDate(DateTime dt) {
    final days = ['Monday', 'Tuesday', 'Wednesday', 'Thursday', 'Friday', 'Saturday', 'Sunday'];
    final dayName = days[dt.weekday - 1];
    final match = _activeShifts.where((s) => s.day.toLowerCase() == dayName.toLowerCase());
    if (match.isNotEmpty) {
      return match.first.calculatedHours;
    }
    return 8.0;
  }

  static Future<ApiResponse<List<WorkingScheduleModel>>> getSchedules() async {
    final response = await ApiClient.get<List<WorkingScheduleModel>>(
      '/schedules',
      parser: (json) {
        if (json is List) {
          return json
              .whereType<Map<String, dynamic>>()
              .map((e) => WorkingScheduleModel.fromJson(e))
              .toList();
        }
        return [];
      },
    );

    if (response.isSuccess) {
      return response;
    }

    if (!ApiClient.isBackendOnline || response.statusCode == 0) {
      return ApiResponse.success(MockDataService.workingSchedules);
    }

    return response;
  }

  static Future<ApiResponse<WorkingScheduleModel>> createSchedule(Map<String, dynamic> payload) async {
    return await ApiClient.post<WorkingScheduleModel>(
      '/schedules',
      body: payload,
      parser: (json) => WorkingScheduleModel.fromJson(json as Map<String, dynamic>),
    );
  }

  static Future<ApiResponse<WorkingScheduleModel>> updateSchedule(String id, Map<String, dynamic> payload) async {
    return await ApiClient.patch<WorkingScheduleModel>(
      '/schedules/$id',
      body: payload,
      parser: (json) => WorkingScheduleModel.fromJson(json as Map<String, dynamic>),
    );
  }

  static Future<ApiResponse<Map<String, dynamic>>> deleteSchedule(String id) async {
    return await ApiClient.delete<Map<String, dynamic>>(
      '/schedules/$id',
      parser: (json) => (json is Map<String, dynamic>) ? json : {},
    );
  }
}
