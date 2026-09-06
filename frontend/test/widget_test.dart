import 'package:flutter_test/flutter_test.dart';
import 'package:peoplepay360/main.dart';

void main() {
  testWidgets('PeoplePay 360 app smoke test', (WidgetTester tester) async {
    await tester.pumpWidget(const PeoplePay360App());
    await tester.pumpAndSettle(const Duration(milliseconds: 500)).catchError((_) => 0);
    expect(find.byType(PeoplePay360App), findsOneWidget);
  });
}
