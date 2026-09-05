import 'package:flutter_test/flutter_test.dart';
import 'package:peoplepay360/main.dart';

void main() {
  testWidgets('PeoplePay 360 app smoke test', (WidgetTester tester) async {
    await tester.pumpWidget(const PeoplePay360App());
    expect(find.text('PeoplePay 360'), findsOneWidget);
  });
}
