import 'package:flutter_test/flutter_test.dart';
import 'package:peoplepay360/models/models.dart';
import 'package:peoplepay360/services/attendance_service.dart';
import 'package:peoplepay360/services/mock_data_service.dart';
import 'package:peoplepay360/services/working_schedule_service.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  group('Overtime Calculation and Consistency Tests', () {
    test('WorkingScheduleService target hours default to 8.0 for 9am-6pm with 1h break', () {
      final monday = DateTime(2026, 9, 7); // Monday
      final targetHours = WorkingScheduleService.getTargetHoursForDate(monday);
      expect(targetHours, equals(8.0));
    });

    test('upsertManualAttendance calculates overtimeHours when worked hours exceed schedule target', () async {
      // 9:00 AM to 8:00 PM = 11 gross hours. Break = 1h. Net worked = 10 hours.
      // Target = 8 hours. Overtime = 10 - 8 = 2.0 hours.
      final checkIn = DateTime(2026, 9, 7, 9, 0).toUtc().toIso8601String();
      final checkOut = DateTime(2026, 9, 7, 20, 0).toUtc().toIso8601String();

      final res = await AttendanceService.upsertManualAttendance(
        employeeId: 'emp-001',
        checkIn: checkIn,
        checkOut: checkOut,
        status: 'PRESENT',
        auditNotes: 'Overtime shift test',
      );

      expect(res.isSuccess, isTrue);
      expect(res.data, isNotNull);
      final model = res.data!;

      expect(model.workedHours, equals(10.0));
      expect(model.overtimeHours, equals(2.0));
      expect(model.status, equals('OVERTIME'));
    });

    test('MockDataService attendances contain consistent overtime records', () {
      final attendances = MockDataService.attendances;
      final overtimeRecords = attendances.where((a) => a.overtimeHours > 0 || a.status == 'OVERTIME').toList();
      expect(overtimeRecords, isNotEmpty);

      for (final att in overtimeRecords) {
        expect(att.overtimeHours, greaterThan(0));
      }
    });

    test('Custom shift schedule updates target hours and overtime is derived against new schedule', () async {
      // Set custom shift of 6 working hours: 09:00 AM to 04:00 PM (7 gross hours, 1h break = 6h target)
      WorkingScheduleService.setActiveShifts([
        ShiftConfig(day: 'Monday', startTime: '09:00 AM', endTime: '04:00 PM', breakMinutes: 60),
      ]);

      // Check-in at 9:00 AM, Check-out at 6:00 PM (9 gross hours - 1h break = 8 net worked hours)
      // Net worked = 8h. Target = 6h. Overtime = 2.0 hours.
      final checkIn = DateTime(2026, 9, 7, 9, 0).toUtc().toIso8601String();
      final checkOut = DateTime(2026, 9, 7, 18, 0).toUtc().toIso8601String();

      final res = await AttendanceService.upsertManualAttendance(
        employeeId: 'emp-004',
        checkIn: checkIn,
        checkOut: checkOut,
      );

      expect(res.isSuccess, isTrue);
      final model = res.data!;
      expect(model.workedHours, equals(8.0));
      expect(model.overtimeHours, equals(2.0));

      // Reset active shifts to standard default
      WorkingScheduleService.setActiveShifts([
        ShiftConfig(day: 'Monday', startTime: '09:00 AM', endTime: '06:00 PM', breakMinutes: 60),
        ShiftConfig(day: 'Tuesday', startTime: '09:00 AM', endTime: '06:00 PM', breakMinutes: 60),
        ShiftConfig(day: 'Wednesday', startTime: '09:00 AM', endTime: '06:00 PM', breakMinutes: 60),
        ShiftConfig(day: 'Thursday', startTime: '09:00 AM', endTime: '06:00 PM', breakMinutes: 60),
        ShiftConfig(day: 'Friday', startTime: '09:00 AM', endTime: '06:00 PM', breakMinutes: 60),
      ]);
    });
  });
}
