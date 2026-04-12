import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';

import '../../blocs/income/income_bloc.dart';
import '../../blocs/income/income_event.dart';
import '../../blocs/income/income_state.dart';
import '../../models/income_model.dart';
import '../../shared/helpers/income_formatter.dart';
import '../../shared/widgets/linear_header.dart';
import 'widgets/income_bar_chart.dart';
import 'widgets/income_pie_chart.dart';
import 'widgets/income_type_summary_card.dart';
import 'widgets/month_year_picker.dart';

class IncomeDashboardScreen extends StatefulWidget {
  const IncomeDashboardScreen({super.key});

  @override
  State<IncomeDashboardScreen> createState() => _IncomeDashboardScreenState();
}

class _IncomeDashboardScreenState extends State<IncomeDashboardScreen> {
  @override
  Widget build(BuildContext context) {
    return Scaffold(
      floatingActionButton: FloatingActionButton(
        onPressed: () => Navigator.pushNamed(context, '/income/add'),
        child: const Icon(Icons.add),
      ),
      body: BlocConsumer<IncomeBloc, IncomeState>(
        listener: (context, state) {
          if (state is IncomeError) {
            ScaffoldMessenger.of(context).showSnackBar(
              SnackBar(
                content: Text(state.message),
                backgroundColor: Colors.red,
              ),
            );
          }
        },
        builder: (context, state) {
          if (state is IncomeInitial || state is IncomeLoading) {
            return const Center(child: CircularProgressIndicator());
          }

          if (state is IncomeError) {
            return _buildErrorState(context, state);
          }

          if (state is! IncomeLoaded) {
            return const SizedBox.shrink();
          }

          final previousTotal = _getPreviousMonthTotal(
            state.selectedMonth,
            state.selectedYear,
            state.monthlyTotals,
          );
          final recentIncomes = state.incomes.take(5).toList();

          return Column(
            children: [
              LinearHeader(
                height: 220,
                child: SafeArea(
                  bottom: false,
                  child: Padding(
                    padding: const EdgeInsets.all(16),
                    child: Column(
                      children: [
                        Row(
                          children: [
                            IconButton(
                              onPressed: () => Navigator.pop(context),
                              icon: const Icon(Icons.arrow_back),
                            ),
                            const Expanded(
                              child: Padding(
                                padding: EdgeInsets.only(left: 16),
                                child: Text(
                                  'THU NHẬP',
                                  style: TextStyle(fontWeight: FontWeight.bold),
                                ),
                              ),
                            ),
                          ],
                        ),
                        const SizedBox(height: 16),
                        MonthYearPicker(
                          month: state.selectedMonth,
                          year: state.selectedYear,
                          onPrevious: () {
                            final previous = DateTime(
                              state.selectedYear,
                              state.selectedMonth - 1,
                            );
                            context.read<IncomeBloc>().add(
                              IncomeMonthChanged(previous.month, previous.year),
                            );
                          },
                          onNext: () {
                            final next = DateTime(
                              state.selectedYear,
                              state.selectedMonth + 1,
                            );
                            context.read<IncomeBloc>().add(
                              IncomeMonthChanged(next.month, next.year),
                            );
                          },
                        ),
                      ],
                    ),
                  ),
                ),
              ),
              Expanded(
                child: SingleChildScrollView(
                  padding: const EdgeInsets.all(16),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      _buildTotalIncomeCard(
                        context,
                        state.grandTotal,
                        previousTotal,
                      ),
                      const SizedBox(height: 16),
                      SizedBox(
                        height: 132,
                        child: Row(
                          children: IncomeType.values.map((type) {
                            return Expanded(
                              child: Padding(
                                padding: EdgeInsets.only(
                                  right: type == IncomeType.teaching ? 0 : 8,
                                ),
                                child: IncomeTypeSummaryCard(
                                  type: type,
                                  amount: state.totalByType[type] ?? 0,
                                ),
                              ),
                            );
                          }).toList(),
                        ),
                      ),
                      const SizedBox(height: 16),
                      IncomePieChart(data: state.totalByType),
                      const SizedBox(height: 16),
                      IncomeBarChart(data: state.monthlyTotals),
                      const SizedBox(height: 16),
                      _buildRecentIncomeList(context, recentIncomes, state),
                      const SizedBox(height: 80)
                    ],
                  ),
                ),
              ),
            ],
          );
        },
      ),
    );
  }

  Widget _buildErrorState(BuildContext context, IncomeError state) {
    final now = DateTime.now();

    return SafeArea(
      child: Center(
        child: Padding(
          padding: const EdgeInsets.all(24),
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              const Icon(Icons.error_outline, size: 48, color: Colors.red),
              const SizedBox(height: 16),
              Text(
                state.message,
                textAlign: TextAlign.center,
                style: TextStyle(
                  color: Theme.of(context).colorScheme.onSurface,
                ),
              ),
              const SizedBox(height: 16),
              ElevatedButton(
                onPressed: () {
                  context.read<IncomeBloc>().add(
                    IncomeMonthChanged(now.month, now.year),
                  );
                },
                child: const Text('Thử lại'),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildTotalIncomeCard(
    BuildContext context,
    double grandTotal,
    double previousTotal,
  ) {
    final percentChange = previousTotal <= 0
        ? null
        : ((grandTotal - previousTotal) / previousTotal) * 100;
    final isUp = (percentChange ?? 0) >= 0;

    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        color: Theme.of(context).colorScheme.primary.withValues(alpha: 0.1),
        borderRadius: BorderRadius.circular(12),
        border: Border.all(
          color: Theme.of(context).colorScheme.primary.withValues(alpha: 0.2),
        ),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            'Tổng thu nhập tháng',
            style: TextStyle(
              color: Theme.of(context).colorScheme.onSurface.withValues(
                alpha: 0.7,
              ),
            ),
          ),
          const SizedBox(height: 8),
          Text(
            formatVnd(grandTotal),
            style: TextStyle(
              fontSize: 26,
              fontWeight: FontWeight.bold,
              color: Theme.of(context).colorScheme.primary,
            ),
          ),
          const SizedBox(height: 8),
          Text(
            percentChange == null
                ? 'Chưa có dữ liệu tháng trước để so sánh'
                : '${isUp ? 'Tăng' : 'Giảm'} ${percentChange.abs().toStringAsFixed(1)}% so với tháng trước',
            style: TextStyle(
              color: percentChange == null
                  ? Theme.of(context).colorScheme.onSurface.withValues(
                      alpha: 0.7,
                    )
                  : isUp
                        ? Colors.green
                        : Colors.red,
              fontWeight: FontWeight.w600,
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildRecentIncomeList(
    BuildContext context,
    List<IncomeModel> incomes,
    IncomeLoaded state,
  ) {
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: Theme.of(context).colorScheme.surface,
        borderRadius: BorderRadius.circular(12),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: 0.05),
            blurRadius: 10,
            offset: const Offset(0, 2),
          ),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              const Expanded(
                child: Text(
                  'Giao dịch gần đây',
                  style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold),
                ),
              ),
              TextButton(
                onPressed: () => Navigator.pushNamed(
                  context,
                  '/income/list',
                  arguments: {
                    'month': state.selectedMonth,
                    'year': state.selectedYear,
                  },
                ),
                child: const Text('Xem tất cả'),
              ),
            ],
          ),
          const SizedBox(height: 8),
          if (incomes.isEmpty)
            Text(
              'Chưa có giao dịch thu nhập trong tháng này',
              style: TextStyle(
                color: Theme.of(context).colorScheme.onSurface.withValues(
                  alpha: 0.7,
                ),
              ),
            ),
          ...incomes.map((income) {
            return ListTile(
              contentPadding: EdgeInsets.zero,
              onTap: () => Navigator.pushNamed(
                context,
                '/income/edit/${income.id}',
                arguments: income,
              ),
              leading: CircleAvatar(
                backgroundColor: income.type.color,
                child: Icon(income.type.icon, color: Colors.white),
              ),
              title: Text(income.type.label),
              subtitle: Text(
                income.note.isEmpty
                    ? '${income.date.day}/${income.date.month}/${income.date.year}'
                    : income.note,
              ),
              trailing: Text(
                formatVnd(income.amount),
                style: TextStyle(
                  color: Theme.of(context).colorScheme.primary,
                  fontWeight: FontWeight.bold,
                ),
              ),
            );
          }),
        ],
      ),
    );
  }

  double _getPreviousMonthTotal(
    int month,
    int year,
    List<MonthlyTotal> monthlyTotals,
  ) {
    final previousDate = DateTime(year, month - 1);

    for (final monthlyTotal in monthlyTotals) {
      if (monthlyTotal.month == previousDate.month &&
          monthlyTotal.year == previousDate.year) {
        return monthlyTotal.total;
      }
    }

    return 0;
  }
}
