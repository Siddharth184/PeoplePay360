import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:peoplepay360/screens/payroll_config_screen.dart';
import 'package:peoplepay360/services/api_client.dart';
import 'package:peoplepay360/services/mock_data_service.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  setUp(() {
    ApiClient.currentUserRole = 'HR_PAYROLL_MANAGER';
    ApiClient.isBackendOnline = false;
  });

  group('PayrollConfigScreen Salary Structure Assignment Board', () {
    testWidgets('renders screen title and assignment section without overflow', (tester) async {
      tester.view.physicalSize = const Size(400, 900);
      tester.view.devicePixelRatio = 1.0;
      addTearDown(tester.view.resetPhysicalSize);
      addTearDown(tester.view.resetDevicePixelRatio);

      await tester.pumpWidget(
        const MaterialApp(
          home: PayrollConfigScreen(),
        ),
      );

      await tester.pumpAndSettle();

      expect(find.textContaining('Payroll Rules & Structure'), findsOneWidget);
      expect(find.text('Employee Payroll & Package Assignment'), findsOneWidget);

      // Verify no overflow errors occurred
      expect(tester.takeException(), isNull);
    });

    testWidgets('search filter narrows employee list', (tester) async {
      tester.view.physicalSize = const Size(800, 1000);
      tester.view.devicePixelRatio = 1.0;
      addTearDown(tester.view.resetPhysicalSize);

      await tester.pumpWidget(
        const MaterialApp(
          home: PayrollConfigScreen(),
        ),
      );

      await tester.pumpAndSettle();

      final searchField = find.byType(TextField).first;
      await tester.enterText(searchField, 'Nikhil');
      await tester.pumpAndSettle();

      expect(find.textContaining('Nikhil'), findsWidgets);
    });

    testWidgets('read-only user sees Read-Only notice and cannot trigger edits', (tester) async {
      ApiClient.currentUserRole = 'HR_PAYROLL_USER';

      await tester.pumpWidget(
        const MaterialApp(
          home: PayrollConfigScreen(),
        ),
      );

      await tester.pumpAndSettle();

      expect(find.text('Read-Only'), findsOneWidget);
      expect(find.text('New Structure'), findsNothing);
    });
  });
}
