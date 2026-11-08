import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';

import '../../blocs/income/income_bloc.dart';
import '../../blocs/income/income_event.dart';
import '../../blocs/income/income_state.dart';
import '../../models/income_model.dart';
import '../../shared/helpers/number_helper.dart';
import '../../shared/ui/ui.dart';
import 'widgets/income_tile.dart';

class IncomeDashboardScreen extends StatefulWidget {
  const IncomeDashboardScreen({super.key});

  @override
  State<IncomeDashboardScreen> createState() => _IncomeDashboardScreenState();
}

class _IncomeDashboardScreenState extends State<IncomeDashboardScreen> {
  bool _yearView = false;

  void _changeMonth(int month, int year) {
    context.read<IncomeBloc>().add(IncomeMonthChanged(month, year));
  }

  @override
  Widget build(BuildContext context) {
    return BlocConsumer<IncomeBloc, IncomeState>(
      listener: (context, state) {
        if (state is IncomeError) {
          ScaffoldMessenger.of(
            context,
          ).showSnackBar(SnackBar(content: Text(state.message)));
        }
      },
      builder: (context, state) {
        final now = DateTime.now();
        return ModuleScaffold(
          title: 'Thu nhập',
          floatingActionButton: FloatingActionButton.extended(
            onPressed: () => Navigator.pushNamed(context, '/income/add'),
            icon: const Icon(Icons.add),
            label: const Text('Thêm thu nhập'),
          ),
          children: [
            PillRow(
              children: [
                PillChip(
                  label: 'Theo tháng',
                  selected: !_yearView,
                  onTap: () => setState(() => _yearView = false),
                ),
                PillChip(
                  label: 'Theo năm',
                  selected: _yearView,
                  onTap: () => setState(() => _yearView = true),
                ),
              ],
            ),
            if (state is IncomeLoaded) ...[
              if (_yearView)
                YearStepper(
                  year: state.selectedYear,
                  onChanged: (year) =>
                      _changeMonth(year == now.year ? now.month : 12, year),
                )
              else
                MonthStrip(
                  month: state.selectedMonth,
                  year: state.selectedYear,
                  onChanged: _changeMonth,
                ),
              _buildSummary(context, state),
              _buildSources(context, state),
              _yearView
                  ? _buildMonthsList(context, state)
                  : _buildTransactions(context, state),
            ] else if (state is IncomeError)
              EmptyState(
                icon: Icons.cloud_off_outlined,
                title: 'Không tải được thu nhập',
                message: state.message,
              )
            else
              const Padding(
                padding: EdgeInsets.all(32),
                child: Center(child: CircularProgressIndicator()),
              ),
          ],
        );
      },
    );
  }

  List<double> _monthTotals(IncomeLoaded state) {
    final totals = List<double>.filled(12, 0);
    for (final income in state.yearIncomes) {
      if (income.year == state.selectedYear) {
        totals[income.month - 1] += income.amount;
      }
    }
    return totals;
  }

  Widget _buildSummary(BuildContext context, IncomeLoaded state) {
    final tone = ModuleTone.of(context, AppModule.income);
    final totals = _monthTotals(state);
    final monthsWithData = totals.where((value) => value > 0).length;

    final String label;
    final double total;
    Widget? caption;

    if (_yearView) {
      label = 'Tổng thu năm ${state.selectedYear}';
      total = totals.fold(0, (acc, value) => acc + value);
      if (monthsWithData > 0) {
        caption = Text(
          'Trung bình ${NumberHelper.formatCompact(total / monthsWithData)}'
          '/tháng · $monthsWithData tháng có thu',
          style: Theme.of(context).textTheme.bodySmall?.copyWith(
            color: Theme.of(context).colorScheme.onSurfaceVariant,
          ),
        );
      }
    } else {
      label = 'Tổng thu tháng ${state.selectedMonth}/${state.selectedYear}';
      total = state.grandTotal;
      final previous = state.selectedMonth > 1
          ? totals[state.selectedMonth - 2]
          : null;
      if (total > 0 && previous != null && previous > 0) {
        final change = (total - previous) / previous * 100;
        caption = _IncomeTrend(change: change);
      }
    }

    return SummaryCard(
      label: label,
      value: NumberHelper.formatCurrency(total),
      caption: caption,
      child: MiniBarChart(
        values: totals,
        color: tone.accent,
        highlightIndex: _yearView ? null : state.selectedMonth - 1,
        labels: const ['T1', 'T6', 'T12'],
        onBarTap: (index) {
          setState(() => _yearView = false);
          _changeMonth(index + 1, state.selectedYear);
        },
      ),
    );
  }

  Widget _buildSources(BuildContext context, IncomeLoaded state) {
    final Map<IncomeType, double> byType;
    if (_yearView) {
      byType = state.yearIncomes
          .where((income) => income.year == state.selectedYear)
          .toList()
          .totalByType();
    } else {
      byType = state.totalByType;
    }

    final total = byType.values.fold<double>(0, (acc, value) => acc + value);
    if (total <= 0) return const SizedBox.shrink();

    final entries = byType.entries.where((e) => e.value > 0).toList()
      ..sort((a, b) => b.value.compareTo(a.value));

    return AppCard(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const SectionHeader(title: 'Nguồn thu'),
          const SizedBox(height: 12),
          SegmentedBar(
            segments: [for (final e in entries) (e.value, e.key.color)],
          ),
          const SizedBox(height: 12),
          for (final entry in entries)
            LegendRow(
              color: entry.key.color,
              label: entry.key.label,
              value:
                  '${NumberHelper.formatCompact(entry.value)} · '
                  '${(entry.value / total * 100).toStringAsFixed(0)}%',
            ),
        ],
      ),
    );
  }

  Widget _buildTransactions(BuildContext context, IncomeLoaded state) {
    if (state.incomes.isEmpty) {
      return const EmptyState(
        icon: Icons.account_balance_wallet_outlined,
        title: 'Chưa có thu nhập trong tháng này',
        message: 'Bấm "Thêm thu nhập" để ghi khoản đầu tiên.',
      );
    }

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        SectionHeader(
          title: 'Giao dịch',
          actionLabel: 'Lọc theo nguồn',
          onAction: () => Navigator.pushNamed(
            context,
            '/income/list',
            arguments: {
              'month': state.selectedMonth,
              'year': state.selectedYear,
            },
          ),
        ),
        for (final (day, items) in groupByDay(
          state.incomes,
          (IncomeModel income) => income.date,
        )) ...[
          DayHeader(dayLabel(day)),
          for (final income in items) IncomeTile(income: income),
        ],
      ],
    );
  }

  Widget _buildMonthsList(BuildContext context, IncomeLoaded state) {
    final totals = _monthTotals(state);
    final tone = ModuleTone.of(context, AppModule.income);
    final months = [
      for (var month = 12; month >= 1; month--)
        if (totals[month - 1] > 0) month,
    ];
    if (months.isEmpty) {
      return const EmptyState(
        icon: Icons.account_balance_wallet_outlined,
        title: 'Chưa có thu nhập trong năm này',
      );
    }

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        const SectionHeader(title: 'Theo tháng'),
        for (final month in months)
          TransactionTile(
            icon: Icons.calendar_month_outlined,
            tone: tone,
            title: 'Tháng $month/${state.selectedYear}',
            subtitle:
                '${state.yearIncomes.where((i) => i.month == month && i.year == state.selectedYear).length} khoản thu',
            amount: NumberHelper.formatCurrency(totals[month - 1]),
            positive: true,
            onTap: () {
              setState(() => _yearView = false);
              _changeMonth(month, state.selectedYear);
            },
          ),
      ],
    );
  }
}

class _IncomeTrend extends StatelessWidget {
  const _IncomeTrend({required this.change});

  final double change;

  @override
  Widget build(BuildContext context) {
    final up = change >= 0;
    final color = up
        ? Colors.green.shade600
        : Theme.of(context).colorScheme.error;
    return Row(
      children: [
        Icon(
          up ? Icons.trending_up : Icons.trending_down,
          size: 16,
          color: color,
        ),
        const SizedBox(width: 4),
        Text(
          '${up ? 'Tăng' : 'Giảm'} ${change.abs().toStringAsFixed(0)}% so với tháng trước',
          style: Theme.of(context).textTheme.bodySmall?.copyWith(color: color),
        ),
      ],
    );
  }
}
