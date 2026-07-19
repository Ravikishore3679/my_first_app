// This is a basic Flutter widget test.
//
// To perform an interaction with a widget in your test, use the WidgetTester
// utility in the flutter_test package. For example, you can send tap and scroll
// gestures. You can also use WidgetTester to find child widgets in the widget
// tree, read text, and verify that the values of widget properties are correct.

import 'package:flutter_test/flutter_test.dart';

import 'package:my_first_app/app.dart';
import 'package:my_first_app/core/di/service_locator.dart';

void main() {
  testWidgets('App shows tracker title', (WidgetTester tester) async {
    await setupDependencies();
    await tester.pumpWidget(const ExpenseTrackerApp());
    await tester.pump(const Duration(milliseconds: 600));

    expect(find.text('Construction Expense Tracker'), findsOneWidget);
  });
}
