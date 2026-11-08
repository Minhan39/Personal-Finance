import 'package:flutter/material.dart';

import '../../../models/expense.dart';
import '../../../service/month_activity_service.dart';
import '../../../shared/helpers/number_helper.dart';
import '../../../shared/ui/ui.dart';
import '../../spending/widgets/expense_category_style.dart';

/// Placeholder shown instead of amounts while they are hidden.
const hiddenAmount = '••••••';

/// A merged income/expense row for the home and transactions tabs.
class ActivityTile extends StatelessWidget {
  const ActivityTile({
    super.key,
    required this.item,
    required this.amountsVisible,
    this.onChanged,
  });

  final ActivityItem item;
  final bool amountsVisible;

  /// Called after the user comes back from editing the item.
  final VoidCallback? onChanged;

  @override
  Widget build(BuildContext context) {
    final amount = amountsVisible
        ? NumberHelper.formatCurrency(item.amount)
        : hiddenAmount;

    final income = item.income;
    if (income != null) {
      return TransactionTile(
        icon: income.type.icon,
        tone: ModuleTone.fromColor(context, income.type.color),
        title: income.type.label,
        subtitle: income.note.isEmpty ? dayLabel(income.date) : income.note,
        amount: amount,
        positive: true,
        onTap: () async {
          await Navigator.pushNamed(
            context,
            '/income/edit/${income.id}',
            arguments: income,
          );
          onChanged?.call();
        },
      );
    }

    final expense = item.expense!;
    final index = ExpenseCategoryStyle.indexOf(expense.category);
    return TransactionTile(
      icon: ExpenseCategoryStyle.iconAt(index),
      tone: ModuleTone.fromColor(context, ExpenseCategoryStyle.colorAt(index)),
      title: ExpenseCategory.fromKey(expense.category).displayName,
      subtitle: expense.description.isEmpty
          ? dayLabel(expense.date)
          : expense.description,
      amount: amount,
    );
  }
}
