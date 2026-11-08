import 'package:flutter/material.dart';
import 'package:intl/intl.dart';

import '../../models/financial_snapshot.dart';
import '../../service/financial_ai_snapshot_service.dart';
import '../../shared/widgets/linear_header.dart';

class FinancialAiReportScreen extends StatefulWidget {
  const FinancialAiReportScreen({super.key});

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

    WidgetsBinding.instance.addPostFrameCallback((_) {
      _loadReport();
    });
  }

  @override
  Widget build(BuildContext context) {
    final rangeLabel = _formatRange(_selectedRange);
    final snapshot = _snapshot;

    return Scaffold(
      body: Column(
        children: [
          LinearHeader(
            height: 260,
            child: SafeArea(
              bottom: false,
              child: Padding(
                padding: const EdgeInsets.fromLTRB(16, 12, 16, 16),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Row(
                      children: [
                        IconButton(
                          onPressed: () => Navigator.pop(context),
                          icon: const Icon(Icons.arrow_back),
                        ),
                        const SizedBox(width: 8),
                        const Expanded(
                          child: Text(
                            'BÁO CÁO TÀI CHÍNH',
                            style: TextStyle(
                              fontWeight: FontWeight.bold,
                              fontSize: 18,
                            ),
                          ),
                        ),
                      ],
                    ),
                    const SizedBox(height: 12),
                    Text(
                      'Khoảng thời gian: $rangeLabel',
                      style: Theme.of(context).textTheme.titleMedium,
                    ),
                    const SizedBox(height: 12),
                    Wrap(
                      spacing: 12,
                      runSpacing: 12,
                      children: [
                        FilledButton.icon(
                          onPressed: _isLoading ? null : _pickRange,
                          icon: const Icon(Icons.date_range),
                          label: const Text('Chọn khoảng thời gian'),
                        ),
                        OutlinedButton.icon(
                          onPressed: _isLoading ? null : _loadReport,
                          icon: const Icon(Icons.refresh),
                          label: const Text('Tải lại'),
                        ),
                      ],
                    ),
                    if (_isLoading) ...[
                      const SizedBox(height: 20),
                      const LinearProgressIndicator(minHeight: 3),
                    ],
                  ],
                ),
              ),
            ),
          ),
          Expanded(
            child: RefreshIndicator(
              onRefresh: _loadReport,
              child: ListView(
                padding: const EdgeInsets.fromLTRB(16, 8, 16, 24),
                physics: const AlwaysScrollableScrollPhysics(),
                children: [
                  if (_errorMessage != null) ...[
                    const SizedBox(height: 12),
                    _SectionCard(
                      title: 'Không thể tải báo cáo',
                      icon: Icons.error_outline,
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(_errorMessage!),
                          const SizedBox(height: 12),
                          FilledButton(
                            onPressed: _isLoading ? null : _loadReport,
                            child: const Text('Thử lại'),
                          ),
                        ],
                      ),
                    ),
                  ],
                  if (snapshot != null) ...[
                    const SizedBox(height: 12),
                    _buildOverviewCard(context, snapshot),
                    const SizedBox(height: 12),
                    _buildIncomeCard(snapshot.incomes),
                    const SizedBox(height: 12),
                    _buildExpenseCard(snapshot.expenses),
                    const SizedBox(height: 12),
                    _buildSavingCard(snapshot.savings),
                  ],
                ],
              ),
            ),
          ),
        ],
      ),
    );
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
      setState(() {
        _snapshot = snapshot;
      });
    } catch (error) {
      if (!mounted) return;
      setState(() {
        _snapshot = null;
        _errorMessage = 'Không thể tải dữ liệu báo cáo: $error';
      });
    } finally {
      if (mounted) {
        setState(() {
          _isLoading = false;
        });
      }
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
    final normalized = start.isAfter(end)
        ? DateTimeRange(start: end, end: start)
        : DateTimeRange(start: start, end: end);

    setState(() {
      _selectedRange = normalized;
    });

    await _loadReport();
  }

  Widget _buildOverviewCard(
    BuildContext context,
    FinancialAiSnapshot snapshot,
  ) {
    return _SectionCard(
      title: 'Tổng quan (${snapshot.monthCount} tháng)',
      icon: Icons.assessment,
      child: Column(
        children: [
          GridView.count(
            crossAxisCount: 2,
            crossAxisSpacing: 12,
            mainAxisSpacing: 12,
            childAspectRatio: 1.7,
            shrinkWrap: true,
            physics: const NeverScrollableScrollPhysics(),
            children: [
              _MetricChip(
                label: 'Thu nhập',
                value: _formatMoney(snapshot.totalIncome),
                icon: Icons.arrow_upward,
              ),
              _MetricChip(
                label: 'Chi tiêu',
                value: _formatMoney(snapshot.totalExpense),
                icon: Icons.arrow_downward,
              ),
              _MetricChip(
                label: 'Dòng tiền ròng',
                value: _formatMoney(snapshot.netCashFlow),
                icon: Icons.compare_arrows,
              ),
              _MetricChip(
                label: 'Tỷ lệ chi/thu',
                value: _formatPercent(snapshot.expenseToIncomeRatio),
                icon: Icons.pie_chart,
              ),
              _MetricChip(
                label: 'Quỹ hiện có',
                value: _formatMoney(snapshot.savings.currentTotal),
                icon: Icons.account_balance_wallet,
              ),
              _MetricChip(
                label: 'Quỹ đủ chi tiêu',
                value:
                    '${snapshot.savingsCoverageMonths.toStringAsFixed(1)} tháng',
                icon: Icons.shield_outlined,
              ),
            ],
          ),
        ],
      ),
    );
  }

  Widget _buildIncomeCard(IncomeSummary incomes) {
    return _SectionCard(
      title: 'Thu nhập',
      icon: Icons.trending_up,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          _KeyValueRow('Số giao dịch', '${incomes.transactionCount}'),
          _KeyValueRow('Tổng', _formatMoney(incomes.totalAmount)),
          _KeyValueRow('Trung bình/tháng', _formatMoney(incomes.monthlyAverage)),
          const _SubHeading('Theo tháng'),
          _buildMonthlyTable(incomes.monthlyTotals),
          const _SubHeading('Theo loại'),
          _buildNamedTable(incomes.typeTotals, incomes.totalAmount),
        ],
      ),
    );
  }

  Widget _buildExpenseCard(ExpenseSummary expenses) {
    return _SectionCard(
      title: 'Chi tiêu',
      icon: Icons.trending_down,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          _KeyValueRow('Số giao dịch', '${expenses.transactionCount}'),
          _KeyValueRow('Tổng', _formatMoney(expenses.totalAmount)),
          _KeyValueRow(
            'Trung bình/tháng',
            _formatMoney(expenses.monthlyAverage),
          ),
          const _SubHeading('Theo tháng'),
          _buildMonthlyTable(expenses.monthlyTotals),
          const _SubHeading('Theo danh mục'),
          _buildNamedTable(expenses.categoryTotals, expenses.totalAmount),
        ],
      ),
    );
  }

  Widget _buildSavingCard(SavingSummary savings) {
    return _SectionCard(
      title: 'Tiết kiệm',
      icon: Icons.savings,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          _KeyValueRow('Quỹ hiện có', _formatMoney(savings.currentTotal)),
          _KeyValueRow('Quỹ tương lai', _formatMoney(savings.futureTotal)),
          _KeyValueRow('Tổng vốn', _formatMoney(savings.totalCapital)),
          _KeyValueRow('Tổng lãi', _formatMoney(savings.totalProfit)),
          _KeyValueRow(
            'Số kế hoạch',
            '${savings.activePlanCount} đang hoạt động / ${savings.planCount}',
          ),
          const _SubHeading('Các khoản tiết kiệm'),
          if (savings.plans.isEmpty)
            const _EmptyText()
          else
            ...savings.plans.map(_buildPlanTile),
        ],
      ),
    );
  }

  Widget _buildPlanTile(SavingPlanSnapshot plan) {
    final percent = plan.percent;
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 6),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            plan.name.isEmpty ? '(Không tên)' : plan.name,
            style: const TextStyle(fontWeight: FontWeight.w600),
          ),
          const SizedBox(height: 2),
          Text(
            '${plan.status} · ${plan.startLabel} - ${plan.endLabel}',
            style: Theme.of(context).textTheme.bodySmall,
          ),
          _KeyValueRow('Vốn', _formatMoney(plan.capital)),
          _KeyValueRow('Lãi', _formatMoney(plan.profit)),
          if (percent != null)
            _KeyValueRow('Lãi suất', '${percent.toStringAsFixed(2)}%'),
        ],
      ),
    );
  }

  Widget _buildMonthlyTable(List<MonthlyAmount> items) {
    if (items.isEmpty) return const _EmptyText();
    return Column(
      children: items
          .map((item) => _KeyValueRow(item.label, _formatMoney(item.amount)))
          .toList(),
    );
  }

  Widget _buildNamedTable(List<NamedAmount> items, double total) {
    if (items.isEmpty) return const _EmptyText();
    final sorted = [...items]..sort((a, b) => b.amount.compareTo(a.amount));
    return Column(
      children: sorted.map((item) {
        final share = total <= 0 ? 0.0 : item.amount / total;
        return _KeyValueRow(
          item.label,
          '${_formatMoney(item.amount)}  (${_formatPercent(share)})',
        );
      }).toList(),
    );
  }

  String _formatRange(DateTimeRange range) {
    final start = DateFormat('MM/yyyy').format(range.start);
    final end = DateFormat('MM/yyyy').format(range.end);
    return '$start - $end';
  }

  String _formatPercent(double ratio) => '${(ratio * 100).toStringAsFixed(1)}%';

  String _formatMoney(double amount) {
    return NumberFormat.currency(
      locale: 'vi_VN',
      symbol: '₫',
      decimalDigits: 0,
    ).format(amount);
  }
}

class _SubHeading extends StatelessWidget {
  const _SubHeading(this.text);

  final String text;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.only(top: 16, bottom: 4),
      child: Text(
        text,
        style: TextStyle(
          fontWeight: FontWeight.w700,
          color: Theme.of(context).colorScheme.primary,
        ),
      ),
    );
  }
}

class _KeyValueRow extends StatelessWidget {
  const _KeyValueRow(this.label, this.value);

  final String label;
  final String value;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 4),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Expanded(
            child: Text(
              label,
              style: TextStyle(
                color: Theme.of(
                  context,
                ).colorScheme.onSurface.withValues(alpha: 0.75),
              ),
            ),
          ),
          const SizedBox(width: 12),
          Text(value, style: const TextStyle(fontWeight: FontWeight.w600)),
        ],
      ),
    );
  }
}

class _EmptyText extends StatelessWidget {
  const _EmptyText();

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 4),
      child: Text(
        'Không có dữ liệu.',
        style: TextStyle(
          color: Theme.of(context).colorScheme.onSurface.withValues(alpha: 0.6),
        ),
      ),
    );
  }
}

class _SectionCard extends StatelessWidget {
  const _SectionCard({
    required this.title,
    required this.icon,
    required this.child,
  });

  final String title;
  final IconData icon;
  final Widget child;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: Theme.of(context).colorScheme.surface,
        borderRadius: BorderRadius.circular(20),
        border: Border.all(
          color: Theme.of(context).colorScheme.outline.withValues(alpha: 0.12),
        ),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: 0.04),
            blurRadius: 24,
            offset: const Offset(0, 12),
          ),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Container(
                width: 40,
                height: 40,
                decoration: BoxDecoration(
                  color: Theme.of(
                    context,
                  ).colorScheme.primary.withValues(alpha: 0.12),
                  borderRadius: BorderRadius.circular(12),
                ),
                child: Icon(icon, color: Theme.of(context).colorScheme.primary),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: Text(
                  title,
                  style: const TextStyle(
                    fontWeight: FontWeight.w700,
                    fontSize: 16,
                  ),
                ),
              ),
            ],
          ),
          const SizedBox(height: 16),
          child,
        ],
      ),
    );
  }
}

class _MetricChip extends StatelessWidget {
  const _MetricChip({
    required this.label,
    required this.value,
    required this.icon,
  });

  final String label;
  final String value;
  final IconData icon;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: Theme.of(context).colorScheme.primary.withValues(alpha: 0.08),
        borderRadius: BorderRadius.circular(16),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Icon(icon, size: 18, color: Theme.of(context).colorScheme.primary),
          const SizedBox(height: 10),
          Text(
            label,
            maxLines: 1,
            overflow: TextOverflow.ellipsis,
            style: TextStyle(
              fontSize: 12,
              color: Theme.of(
                context,
              ).colorScheme.onSurface.withValues(alpha: 0.7),
            ),
          ),
          const SizedBox(height: 4),
          Text(
            value,
            maxLines: 1,
            overflow: TextOverflow.ellipsis,
            style: const TextStyle(fontWeight: FontWeight.w700, fontSize: 14),
          ),
        ],
      ),
    );
  }
}
