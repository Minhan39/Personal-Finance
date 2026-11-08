import 'package:flutter/material.dart';
import 'package:personal_finance/features/income/income_dashboard_screen.dart';
import 'package:personal_finance/features/income/income_form_screen.dart';
import 'package:personal_finance/features/income/income_list_screen.dart';
import 'package:personal_finance/features/spending/spending_screen.dart';
import 'package:personal_finance/models/income_model.dart';

import '../features/auth/login_screen.dart';
import '../features/ai_report/financial_ai_report_screen.dart';
import '../features/home/home_screen.dart';
import '../features/save/save_screen.dart';

final routes = {
  '/home': (context) => const HomeScreen(),
  '/save': (context) => const SaveScreen(),
  '/ai-report': (context) => const FinancialAiReportScreen(),
  '/login': (context) => const LoginScreen(),
  '/spending': (context) => const SpendingScreen(),
  '/income': (context) => const IncomeDashboardScreen(),
  '/income/add': (context) => const IncomeFormScreen(),
};

Route<dynamic>? onGenerateRoute(RouteSettings settings) {
  if (settings.name == '/income/list') {
    final args = settings.arguments as Map<String, dynamic>? ?? {};
    final month = args['month'] as int? ?? DateTime.now().month;
    final year = args['year'] as int? ?? DateTime.now().year;

    return MaterialPageRoute(
      builder: (_) => IncomeListScreen(month: month, year: year),
      settings: settings,
    );
  }

  if (settings.name != null && settings.name!.startsWith('/income/edit/')) {
    final income = settings.arguments as IncomeModel?;

    return MaterialPageRoute(
      builder: (_) => IncomeFormScreen(income: income),
      settings: settings,
    );
  }

  return null;
}
