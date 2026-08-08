import 'package:flutter/material.dart';

import 'core/di/service_locator.dart';
import 'services/expense_cloud_store.dart';
import 'viewmodels/expense_view_model.dart';
import 'views/expense_home_page.dart';
import 'views/login_screen.dart';

class ExpenseTrackerApp extends StatefulWidget {
  const ExpenseTrackerApp({super.key});

  @override
  State<ExpenseTrackerApp> createState() => _ExpenseTrackerAppState();
}

class _ExpenseTrackerAppState extends State<ExpenseTrackerApp> {
  bool _isAuthenticated = false;

  @override
  void initState() {
    super.initState();
    _isAuthenticated = serviceLocator<ExpenseCloudStore>().isEnabled;
  }

  void _handleLoginSuccess() {
    setState(() {
      _isAuthenticated = true;
    });
  }

  void _handleLogout() {
    setState(() {
      _isAuthenticated = false;
    });
  }

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
      home: _isAuthenticated
          ? ExpenseHomePage(
              viewModel: serviceLocator<ExpenseViewModel>(),
              onLogout: _handleLogout,
            )
          : LoginScreen(onLoginSuccess: _handleLoginSuccess),
    );
  }
}
