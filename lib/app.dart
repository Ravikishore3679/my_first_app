import 'package:flutter/material.dart';

import 'core/di/service_locator.dart';
import 'core/theme/app_colors.dart';
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
        colorScheme: ColorScheme.fromSeed(
          seedColor: kStonePrimary,
          primary: kStonePrimary,
          secondary: kStoneSecondary,
          surface: kSandSurface,
          onSurface: kStoneText,
        ),
        useMaterial3: true,
        scaffoldBackgroundColor: kSandBackground,
        appBarTheme: const AppBarTheme(
          backgroundColor: kStonePrimary,
          foregroundColor: Colors.white,
        ),
        cardColor: kSandSurface,
        dividerColor: const Color(0xFFE7DCCB),
        inputDecorationTheme: const InputDecorationTheme(
          focusedBorder: OutlineInputBorder(
            borderSide: BorderSide(color: kStonePrimary, width: 1.7),
          ),
          border: OutlineInputBorder(),
          labelStyle: TextStyle(color: kStoneMuted),
        ),
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
