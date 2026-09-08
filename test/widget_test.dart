// This is a basic Flutter widget test.
//
// To perform an interaction with a widget in your test, use the WidgetTester
// utility in the flutter_test package. For example, you can send tap and scroll
// gestures. You can also use WidgetTester to find child widgets in the widget
// tree, read text, and verify that the values of widget properties are correct.

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

import 'package:my_first_app/app.dart';
import 'package:my_first_app/core/di/service_locator.dart';
import 'package:my_first_app/models/expense_entry.dart';
import 'package:my_first_app/viewmodels/expense_view_model.dart';
import 'package:my_first_app/views/budget_estimator_screen.dart';

void main() {
  testWidgets('App shows login screen', (WidgetTester tester) async {
    await setupDependencies();
    await tester.pumpWidget(const ExpenseTrackerApp());
    await tester.pump();

    expect(find.text('Construction Expense Tracker'), findsOneWidget);
    expect(find.text('Email'), findsOneWidget);
    expect(find.text('Name'), findsOneWidget);
  });

  testWidgets('Budget estimator shows default categories and SFT cost', (WidgetTester tester) async {
    final vm = serviceLocator<ExpenseViewModel>();
    vm.addSite('Site A');
    vm.addCategory('Bricks');
    vm.addCategory('Steel');
    vm.addExpense(
      ExpenseEntry(
        id: 'e1',
        category: 'Bricks',
        amount: 50000,
        description: 'Brick supply',
        site: 'Site A',
        date: DateTime.now(),
      ),
    );
    vm.addExpense(
      ExpenseEntry(
        id: 'e2',
        category: 'Steel',
        amount: 75000,
        description: 'Steel supply',
        site: 'Site A',
        date: DateTime.now(),
      ),
    );

    await tester.pumpWidget(
      MaterialApp(
        home: BudgetEstimatorScreen(viewModel: vm),
      ),
    );
    await tester.pumpAndSettle();

    expect(find.text('Budget Estimator'), findsOneWidget);
    expect(find.text('Bricks'), findsOneWidget);
    expect(find.text('Steel'), findsOneWidget);
    expect(find.text('500'), findsOneWidget);
    expect(find.text('750'), findsOneWidget);
    expect(find.text('Grand Total'), findsOneWidget);
  });
}
