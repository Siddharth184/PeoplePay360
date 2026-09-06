import 'package:flutter_test/flutter_test.dart';
import 'package:peoplepay360/services/api_client.dart';
import 'package:peoplepay360/services/attendance_service.dart';
import 'package:peoplepay360/services/mock_data_service.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  group('HR Attendance Manual Correction & Sync Tests', () {
    setUp(() {
      // Set offline mode for testing mock data service sync
      ApiClient.isBackendOnline = false;
    });

    test('HR editing existing attendance record updates MockDataService and Ledger sync', () async {
      // 1. Pick initial record att-01
      final initialRecord = MockDataService.attendances.firstWhere((a) => a.id == 'att-01');
      expect(initialRecord.id, equals('att-01'));
      final targetEmpId = initialRecord.employeeId ?? 'emp-001';

      // 2. Perform HR manual correction: update check-in to 09:00 AM and check-out to 18:00 PM (9.0 worked hours)
      final now = DateTime.now();
      final checkInTime = DateTime(now.year, now.month, now.day, 9, 0).toUtc().toIso8601String();
      final checkOutTime = DateTime(now.year, now.month, now.day, 18, 0).toUtc().toIso8601String();
      const auditNote = 'HR adjusted check-out time per shift log';

      final res = await AttendanceService.upsertManualAttendance(
        employeeId: targetEmpId,
        checkIn: checkInTime,
        checkOut: checkOutTime,
        status: 'PRESENT',
        auditNotes: auditNote,
        attendanceId: 'att-01',
      );

      // 3. Verify upsert result
      expect(res.isSuccess, isTrue);
      expect(res.data, isNotNull);

      final updated = res.data!;
      expect(updated.id, equals('att-01'));
      expect(updated.workedHours, equals(8.0));
      expect(updated.status, equals('PRESENT'));
      expect(updated.isManualEdit, isTrue);
      expect(updated.auditNotes, equals(auditNote));

      // 4. Verify Ledger sync via getAttendances()
      final ledgerRes = await AttendanceService.getAttendances();
      expect(ledgerRes.isSuccess, isTrue);
      final syncedRecord = ledgerRes.data!.firstWhere((a) => a.id == 'att-01');
      expect(syncedRecord.workedHours, equals(8.0));
      expect(syncedRecord.isManualEdit, isTrue);
      expect(syncedRecord.auditNotes, equals(auditNote));
    });

    test('HR creating new manual attendance record inserts into ledger', () async {
      final now = DateTime.now();
      final checkInTime = DateTime(now.year, now.month, now.day, 8, 30).toUtc().toIso8601String();
      final checkOutTime = DateTime(now.year, now.month, now.day, 17, 30).toUtc().toIso8601String();
      const auditNote = 'Manual entry for missed badge tap';

      final res = await AttendanceService.upsertManualAttendance(
        employeeId: 'emp-004', // Sara Khan
        checkIn: checkInTime,
        checkOut: checkOutTime,
        status: 'PRESENT',
        auditNotes: auditNote,
      );

      expect(res.isSuccess, isTrue);
      expect(res.data, isNotNull);

      final newRecord = res.data!;
      expect(newRecord.employeeId, equals('emp-004'));
      expect(newRecord.workedHours, equals(8.0));
      expect(newRecord.isManualEdit, isTrue);
      expect(newRecord.auditNotes, equals(auditNote));

      // Verify it is inserted into MockDataService attendances
      final ledgerRes = await AttendanceService.getAttendances();
      final match = ledgerRes.data!.where((a) => a.id == newRecord.id);
      expect(match.isNotEmpty, isTrue);
    });
  });
}
