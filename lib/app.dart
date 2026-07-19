import 'package:flutter/material.dart';

import 'core/di/service_locator.dart';
import 'viewmodels/expense_view_model.dart';
import 'views/expense_home_page.dart';

class ExpenseTrackerApp extends StatelessWidget {
  const ExpenseTrackerApp({super.key});

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: 'Construction Expense Tracker',
      debugShowCheckedModeBanner: false,
      theme: ThemeData(
        colorScheme: ColorScheme.fromSeed(seedColor: const Color(0xFF0E8E7D)),
        useMaterial3: true,
        scaffoldBackgroundColor: const Color(0xFFF4F8F7),
      ),
      home: ExpenseHomePage(
        viewModel: serviceLocator<ExpenseViewModel>(),
      ),
    );
  }
}
