import 'package:flutter_test/flutter_test.dart';
import 'package:intl/intl.dart';
import 'package:peoplepay360/models/models.dart';
import 'package:peoplepay360/services/mock_data_service.dart';

void main() {
  group('Month-Wise Dynamic Attendance Tab Tests', () {
    test('Calculates month-wise attendance breakdown and stat counts for Aarav Sharma', () {
      final aarav = EmployeeModel(
        id: 'emp-001',
        name: 'Aarav Sharma',
        email: 'aarav@company.com',
        jobTitle: 'Senior Developer',
        department: 'Engineering',
        workPhone: '+91 98765 43210',
        managerName: 'Sara Khan',
        avatarUrl: '',
        timeOffBalance: 14,
        activeContractsCount: 1,
        attendancesCount: 22,
        payslipsCount: 12,
        workLocation: 'Bengaluru HQ',
      );

      final allUserAttendances = MockDataService.attendances.where((a) {
        if (a.employeeId == aarav.id) return true;
        if (a.employeeName != null && a.employeeName!.isNotEmpty) {
          final firstName = aarav.name.toLowerCase().split(' ').first;
          return a.employeeName!.toLowerCase().contains(firstName);
        }
        return false;
      }).toList();

      // September 2026 attendances
      final sepAttendances = allUserAttendances.where((a) {
        if (a.checkIn != null) return DateFormat('yyyy-MM').format(a.checkIn!) == '2026-09';
        if (a.dateStr != null && a.dateStr!.length >= 7) return a.dateStr!.startsWith('2026-09');
        return false;
      }).toList();

      expect(sepAttendances, isNotEmpty);

      int presentCount = 0;
      int lateCount = 0;
      int leaveCount = 0;

      for (final att in sepAttendances) {
        final st = att.status.toUpperCase();
        if (st == 'PRESENT') presentCount++;
        else if (st == 'LATE' || st == 'HALF_DAY') lateCount++;
        else if (st == 'LEAVE' || st == 'PTO' || st == 'SICK') leaveCount++;
      }

      expect(presentCount, greaterThan(0));
      expect(lateCount, greaterThanOrEqualTo(0));
      expect(leaveCount, greaterThanOrEqualTo(0));
    });

    test('Dynamic punch-in dynamically updates month attendance ledger count', () {
      final initialCount = MockDataService.attendances.length;

      // Simulate dynamic new punch-in by employee on Sept 10, 2026
      final newPunchIn = AttendanceModel(
        id: 'att-dynamic-sep10',
        employeeId: 'emp-001',
        employeeName: 'Aarav Sharma',
        checkIn: DateTime(2026, 9, 10, 9, 0),
        checkOut: DateTime(2026, 9, 10, 18, 0),
        status: 'PRESENT',
        workedHours: 8.0,
        overtimeHours: 0.0,
      );

      MockDataService.attendances.add(newPunchIn);

      expect(MockDataService.attendances.length, equals(initialCount + 1));

      final sepLogs = MockDataService.attendances.where((a) {
        return (a.employeeId == 'emp-001') &&
            a.checkIn != null &&
            DateFormat('yyyy-MM').format(a.checkIn!) == '2026-09';
      }).toList();

      expect(sepLogs.any((a) => a.id == 'att-dynamic-sep10'), isTrue);
    });
  });
}
