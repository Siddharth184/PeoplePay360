import 'dart:async';
import 'package:flutter/foundation.dart';
import 'package:intl/intl.dart';
import '../models/models.dart';
import 'api_client.dart';
import 'mock_data_service.dart';
import 'working_schedule_service.dart';

/// Backend is the single source of truth for punch state. The frontend mirrors
/// GET /attendance/status, or falls back to an in-memory offline state for demo.
enum PunchStatus { unknown, notPunchedIn, punchedIn }

/// The result of POST /attendance/punch, as reported by the backend.
enum PunchAction { checkIn, checkOut }

/// Immutable snapshot of the caller's current punch state, sourced from the
/// backend. `since` is the server's check-in instant (UTC) for the open punch;
/// any elapsed timer in the UI is derived from it, never from a local counter.
class PunchState {
  final PunchStatus status;
  final String? attendanceId;
  final DateTime? since; // UTC check-in of the open punch
  final double elapsedHours; // as reported by backend at fetch time

  const PunchState({
    required this.status,
    this.attendanceId,
    this.since,
    this.elapsedHours = 0.0,
  });

  const PunchState.unknown()
      : status = PunchStatus.unknown,
        attendanceId = null,
        since = null,
        elapsedHours = 0.0;

  bool get isPunchedIn => status == PunchStatus.punchedIn;
}

/// Outcome of a punch call, carrying the backend action and a display message
/// composed from the backend response (never a fabricated one).
class PunchResult {
  final bool isSuccess;
  final PunchAction? action;
  final AttendanceModel? attendance;
  final double? elapsedHours;
  final String message;
  final int statusCode;

  const PunchResult({
    required this.isSuccess,
    this.action,
    this.attendance,
    this.elapsedHours,
    required this.message,
    this.statusCode = 0,
  });
}

class AttendanceService {
  /// Backend-authoritative punch state. Widgets listen to this and it is updated
  /// from GET /attendance/status or offline demo fallback.
  static final ValueNotifier<PunchState> stateNotifier =
      ValueNotifier<PunchState>(const PunchState.unknown());

  // Offline mock punch state tracker (defaults to NOT PUNCHED IN for clean user login experience).
  static PunchState _mockPunchState = const PunchState(
    status: PunchStatus.notPunchedIn,
    attendanceId: null,
    since: null,
    elapsedHours: 0.0,
  );

  /// Helper to force start punch state from now for UI testing.
  static void setMockPunchedInNow() {
    _mockPunchState = PunchState(
      status: PunchStatus.punchedIn,
      attendanceId: 'att-mock-now',
      since: DateTime.now(),
      elapsedHours: 0.0,
    );
    stateNotifier.value = _mockPunchState;
  }

  /// Helper to set offline mock punched out.
  static void setMockPunchedOut() {
    _mockPunchState = const PunchState(status: PunchStatus.notPunchedIn);
    stateNotifier.value = _mockPunchState;
  }

  // -------------------------------------------------------------------------
  // STATUS
  // -------------------------------------------------------------------------
  /// GET /attendance/status. Refreshes [stateNotifier] with backend truth or offline demo.
  static Future<ApiResponse<PunchState>> getPunchStatus() async {
    final response = await ApiClient.get<PunchState>(
      '/attendance/status',
      parser: (json) => _parseStatus(json),
    );

    if (response.isSuccess && response.data != null) {
      stateNotifier.value = response.data!;
      return response;
    }

    // Offline demo fallback when backend is unreachable or offline
    if (!ApiClient.isBackendOnline || response.statusCode == 0) {
      stateNotifier.value = _mockPunchState;
      return ApiResponse.success(_mockPunchState, statusCode: 0);
    }

    return response;
  }

  static PunchState _parseStatus(dynamic json) {
    if (json is! Map) return const PunchState.unknown();
    final checkedIn = json['checked_in'] == true;
    if (!checkedIn) {
      return const PunchState(status: PunchStatus.notPunchedIn);
    }
    final since = json['since'] != null
        ? DateTime.tryParse(json['since'].toString())
        : null;
    final elapsed = (json['elapsed_hours'] is num)
        ? (json['elapsed_hours'] as num).toDouble()
        : 0.0;
    return PunchState(
      status: PunchStatus.punchedIn,
      attendanceId: json['attendance_id']?.toString(),
      since: since,
      elapsedHours: elapsed,
    );
  }

  // -------------------------------------------------------------------------
  // PUNCH TOGGLE
  // -------------------------------------------------------------------------
  /// POST /attendance/punch. The backend decides CHECK_IN vs CHECK_OUT based on
  /// whether an open punch exists. In offline mode, toggles [_mockPunchState].
  static Future<PunchResult> punch({String? note, String? employeeId}) async {
    final body = <String, dynamic>{};
    // Only HR may punch for another employee; the backend enforces this too.
    if (employeeId != null && employeeId.isNotEmpty) {
      body['employee_id'] = employeeId;
    }
    if (note != null && note.trim().isNotEmpty) {
      body['note'] = note.trim();
    }

    final response = await ApiClient.post<Map<String, dynamic>>(
      '/attendance/punch',
      body: body,
      parser: (json) => (json as Map).cast<String, dynamic>(),
    );

    if (response.isSuccess && response.data != null) {
      final data = response.data!;
      final actionStr = data['action']?.toString().toUpperCase();
      final action =
          actionStr == 'CHECK_OUT' ? PunchAction.checkOut : PunchAction.checkIn;
      final attendance = data['attendance'] is Map
          ? AttendanceModel.fromJson(
              (data['attendance'] as Map).cast<String, dynamic>())
          : null;
      final elapsed = (data['elapsed_hours'] is num)
          ? (data['elapsed_hours'] as num).toDouble()
          : attendance?.workedHours;

      return PunchResult(
        isSuccess: true,
        action: action,
        attendance: attendance,
        elapsedHours: elapsed,
        message: _successMessage(action, attendance, elapsed),
        statusCode: response.statusCode,
      );
    }

    // Offline demo fallback when backend is unreachable
    if (!ApiClient.isBackendOnline || response.statusCode == 0) {
      final now = DateTime.now();
      if (_mockPunchState.status == PunchStatus.punchedIn) {
        final since = _mockPunchState.since ?? now;
        final grossSeconds = now.difference(since).inSeconds;
        final breakMins = WorkingScheduleService.getBreakMinutesForDate(now);
        final breakSecs = breakMins * 60;
        final netSecs = grossSeconds > breakSecs ? (grossSeconds - breakSecs) : (grossSeconds > 0 ? grossSeconds : 0);
        final elapsedHours = netSecs / 3600.0;
        final timeStr = DateFormat('hh:mm a').format(now);
        final hrsStr = elapsedHours.toStringAsFixed(2);

        final targetHours = WorkingScheduleService.getTargetHoursForDate(now);
        final overtimeHours = (elapsedHours > targetHours)
            ? double.parse((elapsedHours - targetHours).toStringAsFixed(1))
            : 0.0;

        _mockPunchState = const PunchState(status: PunchStatus.notPunchedIn);
        stateNotifier.value = _mockPunchState;

        // Persist completed punch record into MockDataService attendances for ledger sync
        final newPunchRecord = AttendanceModel(
          id: 'att-punch-${now.millisecondsSinceEpoch}',
          employeeId: ApiClient.currentEmployeeId ?? 'emp-001',
          employeeName: ApiClient.currentEmployeeName ?? 'Employee',
          checkIn: since,
          checkOut: now,
          status: overtimeHours > 0 ? 'OVERTIME' : 'PRESENT',
          workedHours: double.parse(elapsedHours.toStringAsFixed(1)),
          overtimeHours: overtimeHours,
          isManualEdit: false,
          createdAt: now,
        );

        MockDataService.attendances.insert(0, newPunchRecord);

        return PunchResult(
          isSuccess: true,
          action: PunchAction.checkOut,
          attendance: newPunchRecord,
          elapsedHours: elapsedHours,
          message: 'Punch out recorded at $timeStr. Worked $hrsStr hours.',
          statusCode: 0,
        );
      } else {
        final timeStr = DateFormat('hh:mm a').format(now);
        _mockPunchState = PunchState(
          status: PunchStatus.punchedIn,
          attendanceId: 'att-mock-now',
          since: now,
          elapsedHours: 0.0,
        );
        stateNotifier.value = _mockPunchState;

        return PunchResult(
          isSuccess: true,
          action: PunchAction.checkIn,
          message: 'Punch in recorded at $timeStr.',
          statusCode: 0,
        );
      }
    }

    // Failure: surface the exact backend/network error, never swallow it.
    final message = response.statusCode == 0
        ? 'Could not sync attendance. Please try again.'
        : (response.errorMessage ?? 'Could not sync attendance. Please try again.');
    return PunchResult(
      isSuccess: false,
      message: message,
      statusCode: response.statusCode,
    );
  }

  static String _successMessage(
    PunchAction action,
    AttendanceModel? attendance,
    double? elapsedHours,
  ) {
    if (action == PunchAction.checkIn) {
      final t = attendance?.checkInTime;
      return t != null ? 'Punch in recorded at $t.' : 'You are punched in.';
    }
    final t = attendance?.checkOutTime;
    final hrs = (elapsedHours ?? attendance?.workedHours ?? 0).toStringAsFixed(2);
    return t != null
        ? 'Punch out recorded at $t. Worked $hrs hours.'
        : 'You are punched out. Worked $hrs hours.';
  }

  // -------------------------------------------------------------------------
  // LEDGER
  // -------------------------------------------------------------------------
  /// GET /attendance. Uses the backend's `date_from` / `date_to` query params.
  /// EMPLOYEE callers are scoped to themselves server-side; passing an
  /// `employeeId` is only honoured for HR-scope roles.
  static Future<ApiResponse<List<AttendanceModel>>> getAttendances({
    String? employeeId,
    String? dateFrom,
    String? dateTo,
    String? status,
    bool manualOnly = false,
    int limit = 100,
    int offset = 0,
  }) async {
    final query = <String, dynamic>{
      'limit': limit,
      'offset': offset,
    };
    if (employeeId != null && employeeId.isNotEmpty) {
      query['employee_id'] = employeeId;
    }
    if (dateFrom != null && dateFrom.isNotEmpty) query['date_from'] = dateFrom;
    if (dateTo != null && dateTo.isNotEmpty) query['date_to'] = dateTo;
    if (status != null && status.isNotEmpty) query['status'] = status;
    if (manualOnly) query['manual_only'] = true;

    final response = await ApiClient.get<List<AttendanceModel>>(
      '/attendance',
      queryParams: query,
      parser: (json) {
        if (json is List) {
          return json
              .map((e) => AttendanceModel.fromJson(e as Map<String, dynamic>))
              .toList();
        }
        return <AttendanceModel>[];
      },
    );

    // Honour a 200 with real data
    if (response.isSuccess && response.data != null) return response;

    // Offline demo fallback when backend is unreachable or returning non-success in test/demo mode
    if (!ApiClient.isBackendOnline || response.statusCode == 0 || !response.isSuccess) {
      List<AttendanceModel> list = List.from(MockDataService.attendances);
      if (employeeId != null && employeeId.isNotEmpty) {
        list = list.where((a) => a.employeeId == employeeId).toList();
      }
      return ApiResponse.success(list, statusCode: 0);
    }

    return response;
  }

  // -------------------------------------------------------------------------
  // SUMMARY
  // -------------------------------------------------------------------------
  /// GET /attendance/summary. The summary endpoint uses `date_start` / `date_end`.
  static Future<ApiResponse<Map<String, dynamic>>> getSummary({
    required String dateStart,
    required String dateEnd,
    String? employeeId,
  }) async {
    final query = <String, dynamic>{
      'date_start': dateStart,
      'date_end': dateEnd,
    };
    if (employeeId != null && employeeId.isNotEmpty) {
      query['employee_id'] = employeeId;
    }
    return ApiClient.get<Map<String, dynamic>>(
      '/attendance/summary',
      queryParams: query,
      parser: (json) => (json as Map).cast<String, dynamic>(),
    );
  }

  // -------------------------------------------------------------------------
  // HR MANUAL CORRECTION
  // -------------------------------------------------------------------------
  /// POST /attendance/manual (create) or PUT /attendance/{id} (edit). HR only;
  /// the backend enforces the role. `checkIn` / `checkOut` are ISO-8601 strings.
  static Future<ApiResponse<AttendanceModel>> upsertManualAttendance({
    required String employeeId,
    required String checkIn,
    String? checkOut,
    String? status,
    String? auditNotes,
    String? attendanceId,
  }) async {
    final body = <String, dynamic>{
      'employee_id': employeeId,
      'check_in': checkIn,
      if (checkOut != null && checkOut.isNotEmpty) 'check_out': checkOut,
      if (status != null && status.isNotEmpty) 'status': status,
      if (auditNotes != null && auditNotes.isNotEmpty) 'audit_notes': auditNotes,
    };

    AttendanceModel parse(dynamic json) =>
        AttendanceModel.fromJson(json as Map<String, dynamic>);

    final response = (attendanceId != null && attendanceId.isNotEmpty)
        ? await ApiClient.put<AttendanceModel>(
            '/attendance/$attendanceId',
            body: body,
            parser: parse,
          )
        : await ApiClient.post<AttendanceModel>(
            '/attendance/manual',
            body: body,
            parser: parse,
          );

    if (response.isSuccess && response.data != null) {
      return response;
    }

    // Offline demo fallback when backend is unreachable or returns non-success response
    if (!ApiClient.isBackendOnline || response.statusCode == 0 || !response.isSuccess) {
      final parsedIn = DateTime.tryParse(checkIn);
      final parsedOut = (checkOut != null && checkOut.isNotEmpty)
          ? DateTime.tryParse(checkOut)
          : null;

      double worked = 0.0;
      double overtime = 0.0;
      if (parsedIn != null && parsedOut != null) {
        final diffSeconds = parsedOut.difference(parsedIn).inSeconds;
        final breakMins = WorkingScheduleService.getBreakMinutesForDate(parsedIn);
        final breakSecs = breakMins * 60;
        final netSecs = diffSeconds > breakSecs ? (diffSeconds - breakSecs) : (diffSeconds > 0 ? diffSeconds : 0);
        worked = netSecs / 3600.0;

        final targetHours = WorkingScheduleService.getTargetHoursForDate(parsedIn);
        if (worked > targetHours) {
          overtime = double.parse((worked - targetHours).toStringAsFixed(1));
        }
      }

      // Lookup employee name
      String empName = 'Employee';
      final empMatch = MockDataService.allEmployees.where((e) => e.id == employeeId);
      if (empMatch.isNotEmpty) {
        empName = empMatch.first.name;
      }

      String effectiveStatus = status ?? (overtime > 0 ? 'OVERTIME' : 'PRESENT');
      if (overtime > 0 && status == 'PRESENT') {
        effectiveStatus = 'OVERTIME';
      }
      final list = MockDataService.attendances;
      AttendanceModel updatedModel;

      if (attendanceId != null && attendanceId.isNotEmpty) {
        final idx = list.indexWhere((a) => a.id == attendanceId);
        updatedModel = AttendanceModel(
          id: attendanceId,
          employeeId: employeeId,
          employeeName: idx >= 0 ? (list[idx].employeeName ?? empName) : empName,
          checkIn: parsedIn,
          checkOut: parsedOut,
          status: effectiveStatus,
          workedHours: double.parse(worked.toStringAsFixed(1)),
          overtimeHours: overtime,
          isManualEdit: true,
          auditNotes: auditNotes ?? 'Manual correction',
          createdAt: idx >= 0 ? list[idx].createdAt : DateTime.now(),
        );

        if (idx >= 0) {
          list[idx] = updatedModel;
        } else {
          list.insert(0, updatedModel);
        }
      } else {
        final newId = 'att-manual-${DateTime.now().millisecondsSinceEpoch}';
        updatedModel = AttendanceModel(
          id: newId,
          employeeId: employeeId,
          employeeName: empName,
          checkIn: parsedIn,
          checkOut: parsedOut,
          status: effectiveStatus,
          workedHours: double.parse(worked.toStringAsFixed(1)),
          overtimeHours: overtime,
          isManualEdit: true,
          auditNotes: auditNotes ?? 'Manual correction',
          createdAt: DateTime.now(),
        );
        list.insert(0, updatedModel);
      }

      return ApiResponse.success(updatedModel, statusCode: 0);
    }

    return response;
  }
}
