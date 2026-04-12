import 'package:flutter/material.dart';

import '../../../models/income_model.dart';
import '../../../shared/helpers/income_formatter.dart';

class IncomeTypeSummaryCard extends StatelessWidget {
  const IncomeTypeSummaryCard({
    super.key,
    required this.type,
    required this.amount,
  });

  final IncomeType type;
  final double amount;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: type.color.withValues(alpha: 0.12),
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: type.color.withValues(alpha: 0.2)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          CircleAvatar(
            radius: 18,
            backgroundColor: type.color,
            child: Icon(type.icon, color: Colors.white, size: 18),
          ),
          const Spacer(),
          Text(
            type.label,
            style: TextStyle(
              fontSize: 12,
              color: Theme.of(context).colorScheme.onSurface.withValues(
                alpha: 0.8,
              ),
            ),
          ),
          const SizedBox(height: 6),
          Text(
            formatVnd(amount),
            maxLines: 2,
            overflow: TextOverflow.ellipsis,
            style: TextStyle(
              fontWeight: FontWeight.bold,
              color: type.color,
            ),
          ),
        ],
      ),
    );
  }
}
