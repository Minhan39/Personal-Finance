import 'package:fl_chart/fl_chart.dart';
import 'package:flutter/material.dart';

import '../../../blocs/income/income_state.dart';
import '../../../models/income_model.dart';
import '../../../shared/helpers/income_formatter.dart';

class IncomeBarChart extends StatelessWidget {
  const IncomeBarChart({super.key, required this.data});

  final List<MonthlyTotal> data;

  @override
  Widget build(BuildContext context) {
    final maxTotal = data.fold<double>(
      0,
      (max, item) => item.total > max ? item.total : max,
    );
    final maxY = maxTotal <= 0 ? 1.0 : maxTotal * 1.2;

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
          const Text(
            '6 tháng gần nhất',
            style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold),
          ),
          const SizedBox(height: 16),
          SizedBox(
            height: 220,
            child: BarChart(
              BarChartData(
                minY: 0,
                maxY: maxY,
                alignment: BarChartAlignment.spaceAround,
                gridData: FlGridData(
                  show: true,
                  drawVerticalLine: false,
                  horizontalInterval: maxY / 4,
                ),
                borderData: FlBorderData(show: false),
                barTouchData: BarTouchData(
                  enabled: true,
                  touchTooltipData: BarTouchTooltipData(
                    getTooltipItem: (group, groupIndex, rod, rodIndex) {
                      final item = data[group.x.toInt()];
                      return BarTooltipItem(
                        'T${item.month}/${item.year}\n'
                        'Lương: ${formatVnd(item.byType[IncomeType.salary] ?? 0)}\n'
                        'Mua bán: ${formatVnd(item.byType[IncomeType.trading] ?? 0)}\n'
                        'Dạy học: ${formatVnd(item.byType[IncomeType.teaching] ?? 0)}',
                        TextStyle(
                          color: Theme.of(context).colorScheme.onInverseSurface,
                          fontWeight: FontWeight.w600,
                        ),
                      );
                    },
                  ),
                ),
                titlesData: FlTitlesData(
                  topTitles: AxisTitles(
                    sideTitles: SideTitles(showTitles: false),
                  ),
                  rightTitles: AxisTitles(
                    sideTitles: SideTitles(showTitles: false),
                  ),
                  leftTitles: AxisTitles(
                    sideTitles: SideTitles(
                      showTitles: true,
                      reservedSize: 42,
                      getTitlesWidget: (value, meta) {
                        return Text(
                          '${(value / 1000000).toStringAsFixed(0)}tr',
                          style: const TextStyle(fontSize: 10),
                        );
                      },
                    ),
                  ),
                  bottomTitles: AxisTitles(
                    sideTitles: SideTitles(
                      showTitles: true,
                      getTitlesWidget: (value, meta) {
                        final index = value.toInt();
                        if (index < 0 || index >= data.length) {
                          return const SizedBox.shrink();
                        }
                        return Padding(
                          padding: const EdgeInsets.only(top: 8),
                          child: Text(
                            'T${data[index].month}',
                            style: const TextStyle(fontSize: 11),
                          ),
                        );
                      },
                    ),
                  ),
                ),
                barGroups: data.asMap().entries.map((entry) {
                  final byType = entry.value.byType;
                  final salary = byType[IncomeType.salary] ?? 0;
                  final trading = byType[IncomeType.trading] ?? 0;
                  final teaching = byType[IncomeType.teaching] ?? 0;
                  final total = salary + trading + teaching;

                  return BarChartGroupData(
                    x: entry.key,
                    barRods: [
                      BarChartRodData(
                        toY: total,
                        width: 20,
                        borderRadius: BorderRadius.circular(6),
                        rodStackItems: [
                          BarChartRodStackItem(0, salary, IncomeType.salary.color),
                          BarChartRodStackItem(
                            salary,
                            salary + trading,
                            IncomeType.trading.color,
                          ),
                          BarChartRodStackItem(
                            salary + trading,
                            total,
                            IncomeType.teaching.color,
                          ),
                        ],
                      ),
                    ],
                  );
                }).toList(),
              ),
              duration: const Duration(milliseconds: 300),
            ),
          ),
        ],
      ),
    );
  }
}
