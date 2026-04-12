import 'package:fl_chart/fl_chart.dart';
import 'package:flutter/material.dart';

import '../../../models/income_model.dart';

class IncomePieChart extends StatelessWidget {
  const IncomePieChart({super.key, required this.data});

  final Map<IncomeType, double> data;

  @override
  Widget build(BuildContext context) {
    final total = data.values.fold<double>(0, (sum, value) => sum + value);

    if (total == 0) {
      return Container(
        height: 240,
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
        child: Center(
          child: Text(
            'Chưa có dữ liệu',
            style: TextStyle(
              color: Theme.of(context).colorScheme.onSurface.withValues(
                alpha: 0.7,
              ),
            ),
          ),
        ),
      );
    }

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
            'Tỷ trọng nguồn thu',
            style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold),
          ),
          const SizedBox(height: 16),
          SizedBox(
            height: 160,
            child: PieChart(
              PieChartData(
                sectionsSpace: 3,
                centerSpaceRadius: 40,
                pieTouchData: PieTouchData(enabled: true),
                sections: IncomeType.values
                    .where((type) => (data[type] ?? 0) > 0)
                    .map((type) {
                      final value = data[type] ?? 0;
                      final percentage = (value / total) * 100;
                      return PieChartSectionData(
                        color: type.color,
                        value: value,
                        title: '${percentage.toStringAsFixed(0)}%',
                        radius: 52,
                        titleStyle: const TextStyle(
                          fontWeight: FontWeight.bold,
                          color: Colors.white,
                          fontSize: 12,
                        ),
                      );
                    })
                    .toList(),
              ),
              duration: const Duration(milliseconds: 300),
            ),
          ),
          const SizedBox(height: 16),
          Wrap(
            spacing: 12,
            runSpacing: 8,
            children: IncomeType.values.map((type) {
              final value = data[type] ?? 0;
              final percentage = total > 0 ? (value / total) * 100 : 0;
              return Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Container(
                    width: 10,
                    height: 10,
                    decoration: BoxDecoration(
                      color: type.color,
                      borderRadius: BorderRadius.circular(999),
                    ),
                  ),
                  const SizedBox(width: 6),
                  Text('${type.label} ${percentage.toStringAsFixed(0)}%'),
                ],
              );
            }).toList(),
          ),
        ],
      ),
    );
  }
}
