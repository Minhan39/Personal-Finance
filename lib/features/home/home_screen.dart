import 'dart:async';

import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/material.dart';

import '../../service/fcm_service.dart';
import '../ai_report/financial_ai_report_screen.dart';
import 'tabs/overview_tab.dart';
import 'tabs/profile_tab.dart';
import 'tabs/transactions_tab.dart';
import 'widgets/quick_add_sheet.dart';

/// Signed-in shell: bottom navigation between the home tabs, with a central
/// "+" that opens the quick-add sheet instead of a tab.
class HomeScreen extends StatefulWidget {
  const HomeScreen({super.key});

  @override
  State<HomeScreen> createState() => _HomeScreenState();
}

class _HomeScreenState extends State<HomeScreen> {
  static const _overview = 0;
  static const _transactions = 1;
  static const _add = 2;
  static const _report = 3;

  int _index = _overview;

  /// Per-tab reload counters (overview, transactions). A tab reloads when
  /// its counter changes: on being selected, or after a quick add.
  final _refreshTicks = [0, 0];
  StreamSubscription<User?>? _authSubscription;

  @override
  void initState() {
    super.initState();
    _authSubscription = FirebaseAuth.instance.authStateChanges().listen((
      user,
    ) async {
      if (user == null) return;
      final token = await FcmService.getFcmToken();
      await FcmService.addLog(
        deviceType: 'android',
        fcmToken: token ?? '',
        userId: user.uid,
      );
    });
  }

  @override
  void dispose() {
    _authSubscription?.cancel();
    super.dispose();
  }

  Future<void> _onDestinationSelected(int index) async {
    if (index == _add) {
      await QuickAddSheet.show(context);
      if (mounted) {
        setState(() {
          _refreshTicks[_overview]++;
          _refreshTicks[_transactions]++;
        });
      }
      return;
    }
    setState(() {
      _index = index;
      if (index < _refreshTicks.length) _refreshTicks[index]++;
    });
  }

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;

    return Scaffold(
      body: IndexedStack(
        index: _index > _add ? _index - 1 : _index,
        children: [
          OverviewTab(
            refreshTick: _refreshTicks[_overview],
            onOpenReport: () => _onDestinationSelected(_report),
            onOpenTransactions: () => _onDestinationSelected(_transactions),
          ),
          TransactionsTab(refreshTick: _refreshTicks[_transactions]),
          const FinancialAiReportScreen(embedded: true),
          const ProfileTab(),
        ],
      ),
      bottomNavigationBar: NavigationBar(
        selectedIndex: _index,
        onDestinationSelected: _onDestinationSelected,
        destinations: [
          const NavigationDestination(
            icon: Icon(Icons.home_outlined),
            selectedIcon: Icon(Icons.home),
            label: 'Trang chủ',
          ),
          const NavigationDestination(
            icon: Icon(Icons.swap_vert),
            label: 'Giao dịch',
          ),
          NavigationDestination(
            icon: Container(
              width: 48,
              height: 36,
              decoration: BoxDecoration(
                color: scheme.primary,
                borderRadius: BorderRadius.circular(14),
              ),
              child: Icon(Icons.add, color: scheme.onPrimary),
            ),
            label: 'Thêm',
            tooltip: 'Thêm giao dịch',
          ),
          const NavigationDestination(
            icon: Icon(Icons.pie_chart_outline),
            selectedIcon: Icon(Icons.pie_chart),
            label: 'Báo cáo',
          ),
          const NavigationDestination(
            icon: Icon(Icons.person_outline),
            selectedIcon: Icon(Icons.person),
            label: 'Tài khoản',
          ),
        ],
      ),
    );
  }
}
