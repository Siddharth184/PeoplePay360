import 'package:flutter_test/flutter_test.dart';
import 'package:peoplepay360/services/api_client.dart';
import 'package:peoplepay360/services/attendance_service.dart';
import 'package:peoplepay360/services/working_schedule_service.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  group('Working Schedule & Break Deduction Sync Tests', () {
    setUp(() {
      ApiClient.isBackendOnline = false;
      ApiClient.setSession(
        accessToken: 'test-token',
        userId: 'user-admin',
        email: 'admin@oxp.com',
        role: 'ADMIN',
        employeeId: 'emp-001',
        employeeName: 'Aarav Sharma',
      );
    });

    test('Admin configures custom weekend shift with break duration', () {
      final customShifts = [
        ShiftConfig(day: 'Monday', startTime: '09:00 AM', endTime: '06:00 PM', breakMinutes: 60),
        ShiftConfig(day: 'Tuesday', startTime: '09:00 AM', endTime: '06:00 PM', breakMinutes: 60),
        ShiftConfig(day: 'Wednesday', startTime: '09:00 AM', endTime: '06:00 PM', breakMinutes: 60),
        ShiftConfig(day: 'Thursday', startTime: '09:00 AM', endTime: '06:00 PM', breakMinutes: 60),
        ShiftConfig(day: 'Friday', startTime: '09:00 AM', endTime: '06:00 PM', breakMinutes: 60),
        ShiftConfig(day: 'Saturday', startTime: '09:00 AM', endTime: '05:00 PM', breakMinutes: 60), // 8h gross - 1h break = 7.0h
      ];

      WorkingScheduleService.setActiveShifts(customShifts);

      expect(WorkingScheduleService.activeShifts.length, equals(6));
      final satDate = DateTime(2026, 9, 12); // Saturday
      expect(WorkingScheduleService.getBreakMinutesForDate(satDate), equals(60));
      expect(WorkingScheduleService.getTargetHoursForDate(satDate), equals(7.0));
    });

    test('Admin deleting a shift (clicking X button) updates active shift list', () {
      final initialCount = WorkingScheduleService.activeShifts.length;
      final remainingShifts = WorkingScheduleService.activeShifts.where((s) => s.day != 'Saturday').toList();
      WorkingScheduleService.setActiveShifts(remainingShifts);

      expect(WorkingScheduleService.activeShifts.length, equals(initialCount - 1));
      final satMatch = WorkingScheduleService.activeShifts.where((s) => s.day == 'Saturday');
      expect(satMatch.isEmpty, isTrue);
    });

    test('Punch in and Punch out calculates net worked hours deducting break time with 0 data mismatch', () async {
      // Configure Monday shift: 9:00 AM to 6:00 PM (9 gross hours) with 1h (60m) break -> Net 8.0h
      WorkingScheduleService.setActiveShifts([
        ShiftConfig(day: 'Monday', startTime: '09:00 AM', endTime: '06:00 PM', breakMinutes: 60),
      ]);

      final checkInTime = DateTime(2026, 9, 7, 9, 0).toUtc().toIso8601String();
      final checkOutTime = DateTime(2026, 9, 7, 18, 0).toUtc().toIso8601String();

      // HR / Admin upserts attendance record for employee
      final upsertRes = await AttendanceService.upsertManualAttendance(
        employeeId: 'emp-001',
        checkIn: checkInTime,
        checkOut: checkOutTime,
        status: 'PRESENT',
        auditNotes: 'Shift attendance verified with break deduction',
      );

      expect(upsertRes.isSuccess, isTrue);
      final record = upsertRes.data!;

      // Verify net worked hours: 9h span - 1h break = 8.0h worked
      expect(record.workedHours, equals(8.0));

      // Verify individual employee view & HR/Admin Team Ledger have IDENTICAL data (Zero Mismatch)
      final individualLedgerRes = await AttendanceService.getAttendances(employeeId: 'emp-001');
      expect(individualLedgerRes.isSuccess, isTrue);
      final indRecord = individualLedgerRes.data!.firstWhere((a) => a.id == record.id);
      expect(indRecord.checkInTime, equals(record.checkInTime));
      expect(indRecord.checkOutTime, equals(record.checkOutTime));
      expect(indRecord.workedHours, equals(8.0));

      final teamLedgerRes = await AttendanceService.getAttendances(employeeId: null); // Team view
      expect(teamLedgerRes.isSuccess, isTrue);
      final teamRecord = teamLedgerRes.data!.firstWhere((a) => a.id == record.id);
      expect(teamRecord.checkInTime, equals(record.checkInTime));
      expect(teamRecord.checkOutTime, equals(record.checkOutTime));
      expect(teamRecord.workedHours, equals(8.0));
      expect(teamRecord.workedHours, equals(indRecord.workedHours));
    });
  });
}
