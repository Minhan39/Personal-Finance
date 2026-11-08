import 'package:flutter/material.dart';

import '../../../models/income_model.dart';
import '../../../shared/helpers/number_helper.dart';
import '../../../shared/ui/ui.dart';

/// Income row; tapping it opens the edit form.
class IncomeTile extends StatelessWidget {
  const IncomeTile({super.key, required this.income});

  final IncomeModel income;

  @override
  Widget build(BuildContext context) {
    final time =
        '${income.date.hour.toString().padLeft(2, '0')}:'
        '${income.date.minute.toString().padLeft(2, '0')}';
    return TransactionTile(
      icon: income.type.icon,
      tone: ModuleTone.fromColor(context, income.type.color),
      title: income.note.isEmpty ? income.type.label : income.note,
      subtitle: income.note.isEmpty ? time : '${income.type.label} · $time',
      amount: NumberHelper.formatCurrency(income.amount),
      positive: true,
      onTap: () => Navigator.pushNamed(
        context,
        '/income/edit/${income.id}',
        arguments: income,
      ),
    );
  }
}
