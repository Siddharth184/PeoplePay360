import 'dart:async';
import 'package:flutter/foundation.dart';
import 'package:intl/intl.dart';
import '../models/models.dart';
import 'api_client.dart';
import 'mock_data_service.dart';

enum PunchRequestType { punchIn, punchOut, breakStart, breakEnd }

enum PunchStatus {
  notPunchedIn,
  pendingPunchIn,
  punchedIn,
  pendingBreak,
  onBreak,
  pendingPunchOut,
  punchedOut,
}

class PunchRequestRecord {
  final String id;
  final String employeeId;
  final String employeeName;
  final String employeeDept;
  final String employeeAvatar;
  final PunchRequestType type;
  final DateTime requestedAt;
  final String requestedTimeString;
  final String requestedDateString;
  final String location;
  final String workMode;
  final String reason;
  String status; // 'PENDING', 'APPROVED', 'REJECTED'
  String? approvedBy;
  DateTime? approvedAt;
  String? approvedTimeString;
  String? approvedDateString;
  String? rejectionReason;

  PunchRequestRecord({
    required this.id,
    required this.employeeId,
    required this.employeeName,
    required this.employeeDept,
    required this.employeeAvatar,
    required this.type,
    required this.requestedAt,
    required this.requestedTimeString,
    required this.requestedDateString,
    required this.location,
    required this.workMode,
    required this.reason,
    this.status = 'PENDING',
    this.approvedBy,
    this.approvedAt,
    this.approvedTimeString,
    this.approvedDateString,
    this.rejectionReason,
  });

  String get typeLabel {
    switch (type) {
      case PunchRequestType.punchIn:
        return 'Punch In';
      case PunchRequestType.punchOut:
        return 'Punch Out';
      case PunchRequestType.breakStart:
        return 'Start Break';
      case PunchRequestType.breakEnd:
        return 'End Break';
    }
  }
}

class PunchState {
  final PunchStatus status;
  final PunchRequestRecord? activeApprovedRequest;
  final PunchRequestRecord? pendingRequest;
  final int elapsedSeconds;
  final List<PunchRequestRecord> allRequests;

  const PunchState({
    required this.status,
    this.activeApprovedRequest,
    this.pendingRequest,
    required this.elapsedSeconds,
    required this.allRequests,
  });

  PunchState copyWith({
    PunchStatus? status,
    PunchRequestRecord? activeApprovedRequest,
    PunchRequestRecord? pendingRequest,
    int? elapsedSeconds,
    List<PunchRequestRecord>? allRequests,
    bool clearPending = false,
  }) {
    return PunchState(
      status: status ?? this.status,
      activeApprovedRequest: activeApprovedRequest ?? this.activeApprovedRequest,
      pendingRequest: clearPending ? null : (pendingRequest ?? this.pendingRequest),
      elapsedSeconds: elapsedSeconds ?? this.elapsedSeconds,
      allRequests: allRequests ?? this.allRequests,
    );
  }
}

class AttendanceService {
  static Timer? _sessionTimer;

  static final List<PunchRequestRecord> _initialRequests = [
    PunchRequestRecord(
      id: 'REQ-2026-0811',
      employeeId: 'EMP-4076',
      employeeName: 'Rohan Patel',
      employeeDept: 'Engineering',
      employeeAvatar: 'https://images.unsplash.com/photo-1534528741775-53994a69daeb?w=150',
      type: PunchRequestType.punchIn,
      requestedAt: DateTime.now().subtract(const Duration(minutes: 25)),
      requestedTimeString: DateFormat('hh:mm a').format(DateTime.now().subtract(const Duration(minutes: 25))),
      requestedDateString: DateFormat('dd-MMM-yyyy').format(DateTime.now()),
      location: 'Mumbai HQ (Floor 4 • Wi-Fi: OXP-Corp-5G)',
      workMode: 'Office HQ',
      reason: 'Regular morning engineering shift check-in',
      status: 'PENDING',
    ),
    PunchRequestRecord(
      id: 'REQ-2026-0810',
      employeeId: 'EMP-99201',
      employeeName: 'Aarav Mehta',
      employeeDept: 'Finance & Accounts',
      employeeAvatar: 'https://lh3.googleusercontent.com/aida-public/AB6AXuBdEf-4m50kA9OQg_t2t8GxE1b98fcDAfowAdYJ8MlFe2-FodUaYVIicVZP9sfZvbbS-7awB34cXKZKWL7nf1l2EblaMBQ2oWhPKulk2tSVM6fSnwK0dl4fjR5bIXjGgLrM_ZSM2ZaI-D0wXBsAzBEAizPLuUXKKNlRRR1JqN8TkQ-p35yGHlZw-2Q3FctrECb8YUVdxSXIPddbzmTKEdV9NUCFqtMm8LV7NmbemGjgyWI3FKQXQiKS',
      type: PunchRequestType.punchIn,
      requestedAt: DateTime.now().subtract(const Duration(hours: 6, minutes: 56)),
      requestedTimeString: '09:05 AM',
      requestedDateString: DateFormat('dd-MMM-yyyy').format(DateTime.now()),
      location: 'Mumbai HQ (Wi-Fi: OXP-Corp-5G)',
      workMode: 'Office HQ',
      reason: 'Payroll processing shift punch',
      status: 'APPROVED',
      approvedBy: 'Sara Khan (HR Lead)',
      approvedAt: DateTime.now().subtract(const Duration(hours: 6, minutes: 55)),
      approvedTimeString: '09:05 AM',
      approvedDateString: DateFormat('dd-MMM-yyyy').format(DateTime.now()),
    ),
  ];

  static final ValueNotifier<PunchState> stateNotifier = ValueNotifier<PunchState>(
    PunchState(
      status: PunchStatus.punchedIn,
      activeApprovedRequest: _initialRequests[1],
      pendingRequest: null,
      elapsedSeconds: 6 * 3600 + 56 * 60 + 21, // 06:56:21
      allRequests: List.from(_initialRequests),
    ),
  );

  static void _startTimerIfNeeded() {
    _sessionTimer?.cancel();
    _sessionTimer = Timer.periodic(const Duration(seconds: 1), (_) {
      final current = stateNotifier.value;
      if (current.status == PunchStatus.punchedIn) {
        stateNotifier.value = current.copyWith(
          elapsedSeconds: current.elapsedSeconds + 1,
        );
      }
    });
  }

  static void init() {
    _startTimerIfNeeded();
  }

  // --- Employee submits a Punch Request ---
  static Future<PunchRequestRecord> submitPunchRequest({
    required PunchRequestType type,
    required String location,
    required String workMode,
    String? reason,
    String? employeeId,
    String? employeeName,
    String? employeeDept,
    String? employeeAvatar,
  }) async {
    final now = DateTime.now();
    final timeStr = DateFormat('hh:mm a').format(now);
    final dateStr = DateFormat('dd-MMM-yyyy').format(now);
    final reqId = 'REQ-2026-${now.millisecondsSinceEpoch.toString().substring(7)}';

    final empId = employeeId ?? 'EMP-99201';
    final empName = employeeName ?? 'Aarav Mehta';
    final empDept = employeeDept ?? 'Finance & Accounts';
    final empAvatar = employeeAvatar ??
        'https://lh3.googleusercontent.com/aida-public/AB6AXuBdEf-4m50kA9OQg_t2t8GxE1b98fcDAfowAdYJ8MlFe2-FodUaYVIicVZP9sfZvbbS-7awB34cXKZKWL7nf1l2EblaMBQ2oWhPKulk2tSVM6fSnwK0dl4fjR5bIXjGgLrM_ZSM2ZaI-D0wXBsAzBEAizPLuUXKKNlRRR1JqN8TkQ-p35yGHlZw-2Q3FctrECb8YUVdxSXIPddbzmTKEdV9NUCFqtMm8LV7NmbemGjgyWI3FKQXQiKS';

    final req = PunchRequestRecord(
      id: reqId,
      employeeId: empId,
      employeeName: empName,
      employeeDept: empDept,
      employeeAvatar: empAvatar,
      type: type,
      requestedAt: now,
      requestedTimeString: timeStr,
      requestedDateString: dateStr,
      location: location.isNotEmpty ? location : 'Mumbai HQ (Floor 4 • Wi-Fi: OXP-Corp-5G)',
      workMode: workMode.isNotEmpty ? workMode : 'Office HQ',
      reason: (reason != null && reason.isNotEmpty)
          ? reason
          : (type == PunchRequestType.punchIn
              ? 'Shift start check-in request'
              : type == PunchRequestType.punchOut
                  ? 'Shift end check-out request'
                  : 'Break transition request'),
      status: 'PENDING',
    );

    PunchStatus pendingStatus;
    switch (type) {
      case PunchRequestType.punchIn:
        pendingStatus = PunchStatus.pendingPunchIn;
        break;
      case PunchRequestType.punchOut:
        pendingStatus = PunchStatus.pendingPunchOut;
        break;
      case PunchRequestType.breakStart:
      case PunchRequestType.breakEnd:
        pendingStatus = PunchStatus.pendingBreak;
        break;
    }

    final updatedList = [req, ...stateNotifier.value.allRequests];
    stateNotifier.value = stateNotifier.value.copyWith(
      status: pendingStatus,
      pendingRequest: req,
      allRequests: updatedList,
    );

    // Call API in background if online
    try {
      await ApiClient.post<Map<String, dynamic>>(
        '/attendance/request-punch',
        body: {
          'type': type.name,
          'location': req.location,
          'work_mode': req.workMode,
          'reason': req.reason,
          'time': now.toIso8601String(),
        },
      );
    } catch (_) {}

    return req;
  }

  // --- HR Approves a Punch Request ---
  static Future<void> approvePunchRequest(
    String requestId, {
    String approverName = 'Sara Khan (HR Lead)',
  }) async {
    final now = DateTime.now();
    final timeStr = DateFormat('hh:mm a').format(now);
    final dateStr = DateFormat('dd-MMM-yyyy').format(now);

    final current = stateNotifier.value;
    final list = List<PunchRequestRecord>.from(current.allRequests);
    final idx = list.indexWhere((r) => r.id == requestId);

    if (idx != -1) {
      final req = list[idx];
      req.status = 'APPROVED';
      req.approvedBy = approverName;
      req.approvedAt = now;
      req.approvedTimeString = timeStr;
      req.approvedDateString = dateStr;

      PunchStatus newStatus = current.status;
      int newElapsed = current.elapsedSeconds;

      if (req.type == PunchRequestType.punchIn) {
        newStatus = PunchStatus.punchedIn;
        newElapsed = 0; // Reset timer for new approved punch in
        _startTimerIfNeeded();
      } else if (req.type == PunchRequestType.punchOut) {
        newStatus = PunchStatus.punchedOut;
      } else if (req.type == PunchRequestType.breakStart) {
        newStatus = PunchStatus.onBreak;
      } else if (req.type == PunchRequestType.breakEnd) {
        newStatus = PunchStatus.punchedIn;
        _startTimerIfNeeded();
      }

      stateNotifier.value = current.copyWith(
        status: newStatus,
        activeApprovedRequest: req,
        elapsedSeconds: newElapsed,
        allRequests: list,
        clearPending: current.pendingRequest?.id == requestId,
      );

      // Call API in background
      try {
        await ApiClient.post<Map<String, dynamic>>(
          '/attendance/requests/$requestId/approve',
          body: {'approver': approverName, 'timestamp': now.toIso8601String()},
        );
      } catch (_) {}
    }
  }

  // --- HR Rejects a Punch Request ---
  static Future<void> rejectPunchRequest(
    String requestId, {
    String reason = 'Invalid geofence or outside permitted shift timings',
  }) async {
    final current = stateNotifier.value;
    final list = List<PunchRequestRecord>.from(current.allRequests);
    final idx = list.indexWhere((r) => r.id == requestId);

    if (idx != -1) {
      final req = list[idx];
      req.status = 'REJECTED';
      req.rejectionReason = reason;

      // Revert status to previous valid state
      PunchStatus revertStatus = PunchStatus.notPunchedIn;
      if (current.activeApprovedRequest != null) {
        if (current.activeApprovedRequest!.type == PunchRequestType.punchIn) {
          revertStatus = PunchStatus.punchedIn;
        } else if (current.activeApprovedRequest!.type == PunchRequestType.breakStart) {
          revertStatus = PunchStatus.onBreak;
        } else if (current.activeApprovedRequest!.type == PunchRequestType.punchOut) {
          revertStatus = PunchStatus.punchedOut;
        }
      }

      stateNotifier.value = current.copyWith(
        status: revertStatus,
        allRequests: list,
        clearPending: current.pendingRequest?.id == requestId,
      );

      // Call API in background
      try {
        await ApiClient.post<Map<String, dynamic>>(
          '/attendance/requests/$requestId/reject',
          body: {'reason': reason},
        );
      } catch (_) {}
    }
  }

  // Legacy compatibility helpers
  static Future<ApiResponse<Map<String, dynamic>>> punch({
    String? employeeId,
    String? note,
  }) async {
    final req = await submitPunchRequest(
      type: stateNotifier.value.status == PunchStatus.punchedIn
          ? PunchRequestType.punchOut
          : PunchRequestType.punchIn,
      location: 'Mumbai HQ (Floor 4 • Wi-Fi: OXP-Corp-5G)',
      workMode: 'Office HQ',
      reason: note,
      employeeId: employeeId,
    );
    return ApiResponse.success({'request_id': req.id, 'status': req.status});
  }

  static Future<ApiResponse<Map<String, dynamic>>> getPunchStatus() async {
    final state = stateNotifier.value;
    return ApiResponse.success({
      'checked_in': state.status == PunchStatus.punchedIn,
      'status': state.status.name,
      'elapsed_hours': state.elapsedSeconds / 3600.0,
      'approved_by': state.activeApprovedRequest?.approvedBy,
      'approved_time': state.activeApprovedRequest?.approvedTimeString,
      'approved_date': state.activeApprovedRequest?.approvedDateString,
    });
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

    return ApiResponse.success(MockDataService.attendances);
  }

  static Future<ApiResponse<AttendanceModel>> upsertManualAttendance(Map<String, dynamic> data) async {
    return await ApiClient.post<AttendanceModel>(
      '/attendance/manual',
      body: data,
      parser: (json) => AttendanceModel.fromJson(json as Map<String, dynamic>),
    );
  }
}
