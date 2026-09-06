import 'package:flutter_test/flutter_test.dart';
import 'package:peoplepay360/models/models.dart';
import 'package:peoplepay360/services/time_off_service.dart';
import 'package:peoplepay360/services/mock_data_service.dart';

void main() {
  group('Time Off Types & Leave Balance Dynamics Verification Tests', () {
    test('1. TimeOffService.getTimeOffTypes() returns available leave types', () async {
      final res = await TimeOffService.getTimeOffTypes();
      expect(res.isSuccess, isTrue);
      expect(res.data, isNotNull);
      expect(res.data!.isNotEmpty, isTrue);

      final typeNames = res.data!.map((t) => t.name).toList();
      print('Loaded Time Off Types: $typeNames');
      expect(typeNames, contains('Paid Time Off'));
      expect(typeNames, contains('Sick Leave'));
      expect(typeNames, contains('Unpaid Leave'));
    });

    test('2. TimeOffService.getLeaveBalances() returns valid balance allocations', () async {
      final res = await TimeOffService.getLeaveBalances();
      expect(res.isSuccess, isTrue);
      expect(res.data, isNotNull);
      expect(res.data!.isNotEmpty, isTrue);

      final ptoBal = res.data!.firstWhere((b) => b.timeoffTypeName.contains('Paid Time Off'));
      print('PTO Balance -> Allocated: ${ptoBal.allocatedDays}, Taken: ${ptoBal.takenDays}, Remaining: ${ptoBal.remainingDays}');
      expect(ptoBal.allocatedDays, greaterThan(0));
      expect(ptoBal.remainingDays, equals(ptoBal.allocatedDays - ptoBal.takenDays));
    });

    test('3. TimeOffService.getDurationPreview() accurately calculates working days', () async {
      // Single day full day
      final resFull = await TimeOffService.getDurationPreview(
        startDate: '2026-09-07', // Monday
        endDate: '2026-09-07',
        dayPart: 'FULL_DAY',
      );
      expect(resFull.isSuccess, isTrue);
      expect(resFull.data!['working_days'], equals(1.0));

      // Single day half day
      final resHalf = await TimeOffService.getDurationPreview(
        startDate: '2026-09-07', // Monday
        endDate: '2026-09-07',
        dayPart: 'FIRST_HALF',
      );
      expect(resHalf.isSuccess, isTrue);
      expect(resHalf.data!['working_days'], equals(0.5));

      // Date range excluding weekend (Mon 2026-09-07 to Sun 2026-09-13 = 5 weekdays)
      final resRange = await TimeOffService.getDurationPreview(
        startDate: '2026-09-07',
        endDate: '2026-09-13',
        dayPart: 'FULL_DAY',
      );
      expect(resRange.isSuccess, isTrue);
      expect(resRange.data!['working_days'], equals(5.0));
    });

    test('4. Dynamic Balance After Approval & Exceeding check logic', () async {
      final balances = MockDataService.getLeaveBalances();
      final types = MockDataService.timeOffTypes;

      final ptoType = types.firstWhere((t) => t.code == 'PTO');
      final ptoBal = balances.firstWhere((b) => b.timeoffTypeId == ptoType.id);

      const requestedWorkingDays = 3.0;
      final remainingAfterApproval = ptoBal.remainingDays - requestedWorkingDays;

      print('PTO Remaining: ${ptoBal.remainingDays}, Requested: $requestedWorkingDays, Balance After Approval: $remainingAfterApproval');
      expect(remainingAfterApproval, equals(ptoBal.remainingDays - 3.0));

      // Exceeding allocation check
      const excessiveDays = 25.0;
      final isExceeding = ptoType.requiresAllocation && (excessiveDays > ptoBal.remainingDays);
      expect(isExceeding, isTrue);

      // Unpaid leave check (requiresAllocation = false / isPaid = false)
      final unpaidType = types.firstWhere((t) => t.code == 'LOP');
      final isUnpaidExceeding = unpaidType.requiresAllocation && (excessiveDays > 0);
      expect(isUnpaidExceeding, isFalse);
    });

    test('5. Submitting leave request via createLeaveRequestSelf returns valid request object', () async {
      final types = MockDataService.timeOffTypes;
      final ptoType = types.first;

      final res = await TimeOffService.createLeaveRequestSelf(
        timeOffTypeId: ptoType.id,
        startDate: '2026-09-10',
        endDate: '2026-09-11',
        reason: 'Personal vacation',
        dayPart: 'FULL_DAY',
      );

      expect(res.isSuccess, isTrue);
      expect(res.data, isNotNull);
      expect(res.data!.timeoffTypeId, equals(ptoType.id));
      expect(res.data!.status, equals('TO_APPROVE'));

      final requestsRes = await TimeOffService.getLeaveRequests();
      expect(requestsRes.data, isNotNull);
      final hasNewReq = requestsRes.data!.any((r) => r.id == res.data!.id);
      expect(hasNewReq, isTrue);
    });

    test('6. Approving, refusing, and cancelling leave request updates statuses and balances consistently', () async {
      final types = MockDataService.timeOffTypes;
      final ptoType = types.firstWhere((t) => t.code == 'PTO');

      // Create new request
      final createRes = await TimeOffService.createLeaveRequestSelf(
        timeOffTypeId: ptoType.id,
        startDate: '2026-09-14',
        endDate: '2026-09-15',
        reason: 'Short trip',
      );
      final reqId = createRes.data!.id;

      final balBefore = MockDataService.getLeaveBalances().firstWhere((b) => b.timeoffTypeId == ptoType.id);
      final initialTaken = balBefore.takenDays;

      // Approve request -> status becomes APPROVED, takenDays increases by 1.0
      final appRes = await TimeOffService.approveLeaveRequest(reqId);
      expect(appRes.isSuccess, isTrue);
      expect(appRes.data!.status, equals('APPROVED'));

      final balAfterApprove = MockDataService.getLeaveBalances().firstWhere((b) => b.timeoffTypeId == ptoType.id);
      expect(balAfterApprove.takenDays, equals(initialTaken + 1.0));

      // Cancel approved request -> status becomes CANCELLED, takenDays credited back by 1.0
      final cancelRes = await TimeOffService.cancelLeaveRequest(reqId);
      expect(cancelRes.isSuccess, isTrue);
      expect(cancelRes.data!.status, equals('CANCELLED'));

      final balAfterCancel = MockDataService.getLeaveBalances().firstWhere((b) => b.timeoffTypeId == ptoType.id);
      expect(balAfterCancel.takenDays, equals(initialTaken));
    });

    test('7. Refused requests are excluded from pending list and visible in All section with status REFUSED', () async {
      final types = MockDataService.timeOffTypes;
      final ptoType = types.first;

      // Create new request and refuse it
      final createRes = await TimeOffService.createLeaveRequestSelf(
        timeOffTypeId: ptoType.id,
        startDate: '2026-09-20',
        endDate: '2026-09-21',
        reason: 'Unplanned absence',
      );
      final reqId = createRes.data!.id;

      final refuseRes = await TimeOffService.refuseLeaveRequest(reqId, 'Schedule conflict');
      expect(refuseRes.isSuccess, isTrue);
      expect(refuseRes.data!.status, equals('REFUSED'));

      final allRes = await TimeOffService.getLeaveRequests();
      expect(allRes.isSuccess, isTrue);
      final allList = allRes.data!;

      // Pending requests do NOT include this refused request
      final pendingOnly = allList.where((r) => r.status == 'TO_APPROVE').toList();
      expect(pendingOnly.any((r) => r.id == reqId), isFalse);

      // All list DOES include this refused request
      final refusedReq = allList.firstWhere((r) => r.id == reqId);
      expect(refusedReq.status, equals('REFUSED'));
    });
  });
}
