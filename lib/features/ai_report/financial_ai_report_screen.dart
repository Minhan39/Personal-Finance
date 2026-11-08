import 'package:flutter/material.dart';
import 'package:intl/intl.dart';

import '../../models/financial_snapshot.dart';
import '../../service/financial_ai_snapshot_service.dart';
import '../../shared/helpers/number_helper.dart';
import '../../shared/ui/ui.dart';

/// Income, expense and saving figures for a month range, computed from the
/// user's own data.
class FinancialAiReportScreen extends StatefulWidget {
  const FinancialAiReportScreen({super.key, this.embedded = false});

  /// True when shown as a home tab (no back button).
  final bool embedded;

  @override
  State<FinancialAiReportScreen> createState() =>
      _FinancialAiReportScreenState();
}

class _FinancialAiReportScreenState extends State<FinancialAiReportScreen> {
  final _snapshotService = FinancialAiSnapshotService();

  late DateTimeRange _selectedRange;
  FinancialAiSnapshot? _snapshot;
  String? _errorMessage;
  bool _isLoading = false;

  @override
  void initState() {
    super.initState();
    final defaultRange = FinancialAiSnapshotService.defaultRange();
    _selectedRange = DateTimeRange(
      start: defaultRange.startMonth,
      end: defaultRange.endMonth,
    );
    WidgetsBinding.instance.addPostFrameCallback((_) => _loadReport());
  }

  Future<void> _loadReport() async {
    if (_isLoading) return;
    setState(() {
      _isLoading = true;
      _errorMessage = null;
    });

    try {
      final snapshot = await _snapshotService.build(
        startMonth: _selectedRange.start,
        endMonth: _selectedRange.end,
      );
      if (!mounted) return;
      setState(() => _snapshot = snapshot);
    } catch (error) {
      if (!mounted) return;
      setState(() {
        _snapshot = null;
        _errorMessage = 'Không tải được dữ liệu báo cáo. Kéo xuống để thử lại.';
      });
    } finally {
      if (mounted) setState(() => _isLoading = false);
    }
  }

  Future<void> _pickRange() async {
    final picked = await showDateRangePicker(
      context: context,
      firstDate: DateTime.now().subtract(const Duration(days: 365 * 3)),
      lastDate: DateTime.now(),
      initialDateRange: _selectedRange,
      helpText: 'Chọn khoảng thời gian báo cáo',
    );
    if (picked == null) return;

    final start = DateTime(picked.start.year, picked.start.month);
    final end = DateTime(picked.end.year, picked.end.month);
    setState(() {
      _selectedRange = start.isAfter(end)
          ? DateTimeRange(start: end, end: start)
          : DateTimeRange(start: start, end: end);
    });
    await _loadReport();
  }

  @override
  Widget build(BuildContext context) {
    final snapshot = _snapshot;
    final rangeLabel =
        '${DateFormat('MM/yyyy').format(_selectedRange.start)} – '
        '${DateFormat('MM/yyyy').format(_selectedRange.end)}';

    return ModuleScaffold(
      title: 'Báo cáo tài chính',
      showBack: !widget.embedded,
      onRefresh: _loadReport,
      children: [
        Row(
          children: [
            PillChip(
              label: rangeLabel,
              selected: true,
              onTap: _isLoading ? () {} : _pickRange,
            ),
            const Spacer(),
            if (_isLoading)
              const SizedBox(
                width: 20,
                height: 20,
                child: CircularProgressIndicator(strokeWidth: 2),
              ),
          ],
        ),
        if (_errorMessage != null)
          EmptyState(icon: Icons.cloud_off_outlined, title: _errorMessage!),
        if (snapshot == null && _isLoading && _errorMessage == null)
          const Padding(
            padding: EdgeInsets.all(32),
            child: Center(child: CircularProgressIndicator()),
          ),
        if (snapshot != null) ...[
          _buildOverview(context, snapshot),
          _buildIncome(context, snapshot.incomes),
          _buildExpense(context, snapshot.expenses),
          _buildSavings(context, snapshot.savings),
        ],
      ],
    );
  }

  Widget _buildOverview(BuildContext context, FinancialAiSnapshot snapshot) {
    final scheme = Theme.of(context).colorScheme;
    final ratio = snapshot.expenseToIncomeRatio;
    return SummaryCard(
      label: 'Dòng tiền ròng · ${snapshot.monthCount} tháng',
      value: NumberHelper.formatCurrency(snapshot.netCashFlow),
      caption: Text(
        snapshot.totalIncome <= 0
            ? 'Chưa có thu nhập trong khoảng này'
            : 'Đã chi ${(ratio * 100).toStringAsFixed(1)}% thu nhập',
        style: Theme.of(context).textTheme.bodySmall?.copyWith(
          color: ratio > 1 ? scheme.error : scheme.onSurfaceVariant,
        ),
      ),
      child: Row(
        children: [
          Expanded(
            child: StatColumn(
              label: 'Thu nhập',
              value: NumberHelper.formatCompact(snapshot.totalIncome),
              valueColor: Colors.green.shade600,
            ),
          ),
          Expanded(
            child: StatColumn(
              label: 'Chi tiêu',
              value: NumberHelper.formatCompact(snapshot.totalExpense),
            ),
          ),
          Expanded(
            child: StatColumn(
              label: 'Quỹ đủ chi',
              value:
                  '${snapshot.savingsCoverageMonths.toStringAsFixed(1)} tháng',
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildIncome(BuildContext context, IncomeSummary incomes) {
    final tone = ModuleTone.of(context, AppModule.income);
    return _ReportSection(
      title: 'Thu nhập',
      icon: Icons.account_balance_wallet_outlined,
      tone: tone,
      stats: [
        ('Tổng', NumberHelper.formatCompact(incomes.totalAmount)),
        ('TB/tháng', NumberHelper.formatCompact(incomes.monthlyAverage)),
        ('Giao dịch', '${incomes.transactionCount}'),
      ],
      monthly: incomes.monthlyTotals,
      breakdownTitle: 'Theo nguồn',
      breakdown: incomes.typeTotals,
      total: incomes.totalAmount,
    );
  }

  Widget _buildExpense(BuildContext context, ExpenseSummary expenses) {
    final tone = ModuleTone.of(context, AppModule.spending);
    return _ReportSection(
      title: 'Chi tiêu',
      icon: Icons.receipt_long_outlined,
      tone: tone,
      stats: [
        ('Tổng', NumberHelper.formatCompact(expenses.totalAmount)),
        ('TB/tháng', NumberHelper.formatCompact(expenses.monthlyAverage)),
        ('Giao dịch', '${expenses.transactionCount}'),
      ],
      monthly: expenses.monthlyTotals,
      breakdownTitle: 'Theo danh mục',
      breakdown: expenses.categoryTotals,
      total: expenses.totalAmount,
    );
  }

  Widget _buildSavings(BuildContext context, SavingSummary savings) {
    final theme = Theme.of(context);
    final tone = ModuleTone.of(context, AppModule.savings);
    return AppCard(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          _SectionTitle(
            title: 'Tiết kiệm',
            icon: Icons.savings_outlined,
            tone: tone,
          ),
          const SizedBox(height: 16),
          Row(
            children: [
              Expanded(
                child: StatColumn(
                  label: 'Hiện có',
                  value: NumberHelper.formatCompact(savings.currentTotal),
                ),
              ),
              Expanded(
                child: StatColumn(
                  label: 'Tương lai',
                  value: NumberHelper.formatCompact(savings.futureTotal),
                ),
              ),
              Expanded(
                child: StatColumn(
                  label: 'Tổng lãi',
                  value: NumberHelper.formatCompact(savings.totalProfit),
                  valueColor: Colors.green.shade600,
                ),
              ),
            ],
          ),
          const SizedBox(height: 12),
          Text(
            '${savings.activePlanCount} khoản đang gửi · '
            'vốn ${NumberHelper.formatCompact(savings.totalCapital)}',
            style: theme.textTheme.bodySmall?.copyWith(
              color: theme.colorScheme.onSurfaceVariant,
            ),
          ),
        ],
      ),
    );
  }
}

class _SectionTitle extends StatelessWidget {
  const _SectionTitle({
    required this.title,
    required this.icon,
    required this.tone,
  });

  final String title;
  final IconData icon;
  final ModuleTone tone;

  @override
  Widget build(BuildContext context) {
    return Row(
      children: [
        IconBadge(icon: icon, tone: tone, size: 36),
        const SizedBox(width: 12),
        Text(
          title,
          style: Theme.of(
            context,
          ).textTheme.titleMedium?.copyWith(fontWeight: FontWeight.w600),
        ),
      ],
    );
  }
}

/// Income or expense block: stats, monthly bars and a breakdown list.
class _ReportSection extends StatelessWidget {
  const _ReportSection({
    required this.title,
    required this.icon,
    required this.tone,
    required this.stats,
    required this.monthly,
    required this.breakdownTitle,
    required this.breakdown,
    required this.total,
  });

  final String title;
  final IconData icon;
  final ModuleTone tone;
  final List<(String, String)> stats;
  final List<MonthlyAmount> monthly;
  final String breakdownTitle;
  final List<NamedAmount> breakdown;
  final double total;

  @override
  Widget build(BuildContext context) {
    final sorted = [...breakdown.where((item) => item.amount > 0)]
      ..sort((a, b) => b.amount.compareTo(a.amount));

    return AppCard(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          _SectionTitle(title: title, icon: icon, tone: tone),
          const SizedBox(height: 16),
          Row(
            children: [
              for (final (label, value) in stats)
                Expanded(
                  child: StatColumn(label: label, value: value),
                ),
            ],
          ),
          if (monthly.length > 1) ...[
            const SizedBox(height: 16),
            MiniBarChart(
              values: monthly.map((item) => item.amount).toList(),
              color: tone.accent,
              highlightIndex: monthly.length - 1,
              labels: [monthly.first.label, monthly.last.label],
            ),
          ],
          const SizedBox(height: 16),
          Text(
            breakdownTitle,
            style: Theme.of(
              context,
            ).textTheme.labelLarge?.copyWith(fontWeight: FontWeight.w600),
          ),
          const SizedBox(height: 8),
          if (sorted.isEmpty)
            Text(
              'Không có dữ liệu.',
              style: Theme.of(context).textTheme.bodySmall?.copyWith(
                color: Theme.of(context).colorScheme.onSurfaceVariant,
              ),
            )
          else
            for (final item in sorted) ...[
              ProgressRow(
                label: item.label,
                value:
                    '${NumberHelper.formatCompact(item.amount)} · '
                    '${(total <= 0 ? 0 : item.amount / total * 100).toStringAsFixed(0)}%',
                fraction: total <= 0 ? 0 : item.amount / total,
                color: tone.accent,
              ),
              const SizedBox(height: 10),
            ],
        ],
      ),
    );
  }
}
