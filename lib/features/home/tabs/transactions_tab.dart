import 'package:flutter/material.dart';

import '../../../service/month_activity_service.dart';
import '../../../shared/helpers/number_helper.dart';
import '../../../shared/ui/ui.dart';
import '../widgets/activity_tile.dart';

/// All incomes and expenses of a month in one timeline.
class TransactionsTab extends StatefulWidget {
  const TransactionsTab({super.key, required this.refreshTick});

  final int refreshTick;

  @override
  State<TransactionsTab> createState() => _TransactionsTabState();
}

class _TransactionsTabState extends State<TransactionsTab> {
  final _service = MonthActivityService();
  int _month = DateTime.now().month;
  int _year = DateTime.now().year;
  MonthActivity? _activity;
  String? _error;
  bool _loading = true;

  @override
  void initState() {
    super.initState();
    _load();
  }

  @override
  void didUpdateWidget(covariant TransactionsTab oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.refreshTick != widget.refreshTick) _load();
  }

  Future<void> _load() async {
    setState(() {
      _loading = true;
      _error = null;
    });
    try {
      final activity = await _service.load(_month, _year);
      if (!mounted) return;
      setState(() => _activity = activity);
    } catch (error) {
      if (!mounted) return;
      setState(
        () => _error = 'Không tải được giao dịch. Kéo xuống để thử lại.',
      );
    } finally {
      if (mounted) setState(() => _loading = false);
    }
  }

  void _selectMonth(int month, int year) {
    setState(() {
      _month = month;
      _year = year;
    });
    _load();
  }

  @override
  Widget build(BuildContext context) {
    final activity = _activity;
    final showingSelected =
        activity != null && activity.month == _month && activity.year == _year;

    return ModuleScaffold(
      title: 'Giao dịch',
      showBack: false,
      onRefresh: _load,
      children: [
        MonthStrip(month: _month, year: _year, onChanged: _selectMonth),
        if (_loading && !showingSelected)
          const Padding(
            padding: EdgeInsets.all(32),
            child: Center(child: CircularProgressIndicator()),
          )
        else if (_error != null && !showingSelected)
          EmptyState(icon: Icons.cloud_off_outlined, title: _error!)
        else if (activity != null) ...[
          _buildTotals(context, activity),
          _buildTimeline(context, activity),
        ],
      ],
    );
  }

  Widget _buildTotals(BuildContext context, MonthActivity activity) {
    final scheme = Theme.of(context).colorScheme;
    return AppCard(
      child: Row(
        children: [
          Expanded(
            child: StatColumn(
              label: 'Thu',
              value: '+${NumberHelper.formatCompact(activity.totalIncome)}',
              valueColor: Colors.green.shade600,
            ),
          ),
          Expanded(
            child: StatColumn(
              label: 'Chi',
              value: '−${NumberHelper.formatCompact(activity.totalExpense)}',
            ),
          ),
          Expanded(
            child: StatColumn(
              label: 'Chênh lệch',
              value: NumberHelper.formatCompact(activity.net),
              valueColor: activity.net < 0 ? scheme.error : null,
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildTimeline(BuildContext context, MonthActivity activity) {
    final groups = groupByDay(activity.items, (item) => item.date);
    if (groups.isEmpty) {
      return const EmptyState(
        icon: Icons.receipt_long_outlined,
        title: 'Không có giao dịch trong tháng này',
      );
    }

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        for (final (day, items) in groups) ...[
          DayHeader(dayLabel(day)),
          for (final item in items)
            ActivityTile(item: item, amountsVisible: true, onChanged: _load),
        ],
      ],
    );
  }
}
