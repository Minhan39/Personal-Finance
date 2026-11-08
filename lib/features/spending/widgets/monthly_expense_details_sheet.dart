import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';

import '../../../blocs/expense/expense_bloc.dart';
import '../../../blocs/expense/expense_event.dart';
import '../../../blocs/expense/expense_state.dart';
import '../../../models/expense.dart';
import '../../../shared/helpers/number_helper.dart';
import 'expense_category_style.dart';
import 'sheet_header.dart';

/// Lists one month's expenses; swipe left on an item to delete it.
class MonthlyExpenseDetailsSheet extends StatelessWidget {
  const MonthlyExpenseDetailsSheet({
    super.key,
    required this.month,
    required this.year,
    required this.showAmounts,
  });

  final int month;
  final int year;
  final bool showAmounts;

  static Future<void> show(
    BuildContext context, {
    required int month,
    required int year,
    required bool showAmounts,
  }) {
    context.read<ExpenseBloc>().add(
      LoadExpensesByMonthEvent(month: month, year: year),
    );

    return showModalBottomSheet<void>(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (_) => MonthlyExpenseDetailsSheet(
        month: month,
        year: year,
        showAmounts: showAmounts,
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final colorScheme = Theme.of(context).colorScheme;

    return SafeArea(
      child: Container(
        height: MediaQuery.of(context).size.height * 0.6,
        decoration: BoxDecoration(
          color: colorScheme.surface,
          borderRadius: const BorderRadius.vertical(top: Radius.circular(20)),
        ),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Padding(
              padding: const EdgeInsets.all(16),
              child: SheetHeader(title: 'Chi tiết tháng $month/$year'),
            ),
            Expanded(
              child: BlocConsumer<ExpenseBloc, ExpenseState>(
                listener: (context, state) {
                  if (state is ExpenseDeleteSuccess) {
                    Navigator.pop(context);
                  }
                },
                builder: (context, state) {
                  if (state is ExpenseLoading || state is ExpenseLoadingData) {
                    return Center(
                      child: CircularProgressIndicator(
                        color: colorScheme.primary,
                      ),
                    );
                  }

                  final expenses = state is ExpenseLoaded
                      ? state.expenses
                      : const <Map<String, dynamic>>[];

                  if (expenses.isEmpty) {
                    return _EmptyState(colorScheme: colorScheme);
                  }

                  return ListView.builder(
                    padding: const EdgeInsets.symmetric(horizontal: 16),
                    itemCount: expenses.length,
                    itemBuilder: (context, index) => _ExpenseTile(
                      expense: expenses[index],
                      showAmounts: showAmounts,
                    ),
                  );
                },
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _EmptyState extends StatelessWidget {
  const _EmptyState({required this.colorScheme});

  final ColorScheme colorScheme;

  @override
  Widget build(BuildContext context) {
    return Center(
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Icon(
            Icons.receipt_long_outlined,
            size: 48,
            color: colorScheme.onSurface.withValues(alpha: 0.5),
          ),
          const SizedBox(height: 16),
          Text(
            'Chưa có chi tiêu nào trong tháng này',
            style: TextStyle(
              color: colorScheme.onSurface.withValues(alpha: 0.7),
            ),
          ),
        ],
      ),
    );
  }
}

class _ExpenseTile extends StatelessWidget {
  const _ExpenseTile({required this.expense, required this.showAmounts});

  final Map<String, dynamic> expense;
  final bool showAmounts;

  Future<bool> _confirmDelete(BuildContext context) async {
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (dialogContext) => AlertDialog(
        title: const Text('Xác nhận xóa'),
        content: const Text('Bạn có chắc chắn muốn xóa chi tiêu này?'),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(dialogContext).pop(false),
            child: const Text('Huỷ'),
          ),
          TextButton(
            onPressed: () => Navigator.of(dialogContext).pop(true),
            child: const Text('Xoá'),
          ),
        ],
      ),
    );
    return confirmed ?? false;
  }

  @override
  Widget build(BuildContext context) {
    final id = expense['id'] as String;
    final category = expense['category'] as String;
    final amount = (expense['amount'] as num).toDouble();
    final description = expense['description'] as String;
    final date = (expense['date'] as Timestamp).toDate();

    final categoryIndex = ExpenseCategoryStyle.indexOf(category);
    final displayName = categoryIndex >= 0
        ? ExpenseCategory.allDisplayNames[categoryIndex]
        : category;

    return Dismissible(
      key: Key(id),
      direction: DismissDirection.endToStart,
      confirmDismiss: (_) => _confirmDelete(context),
      onDismissed: (_) {
        context.read<ExpenseBloc>().add(DeleteExpenseEvent(id: id, date: date));
      },
      child: Card(
        margin: const EdgeInsets.only(bottom: 8),
        child: ListTile(
          leading: CircleAvatar(
            backgroundColor: ExpenseCategoryStyle.colorAt(categoryIndex),
            child: Icon(
              ExpenseCategoryStyle.iconAt(categoryIndex),
              color: Colors.white,
            ),
          ),
          title: Text(displayName),
          subtitle: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              if (description.isNotEmpty) Text(description),
              Text(
                '${date.day}/${date.month}/${date.year}',
                style: const TextStyle(fontSize: 12),
              ),
            ],
          ),
          trailing: Text(
            showAmounts
                ? NumberHelper.formatCurrency(amount)
                : NumberHelper.hideMoney(),
            style: TextStyle(
              fontWeight: FontWeight.bold,
              color: Theme.of(context).colorScheme.primary,
            ),
          ),
        ),
      ),
    );
  }
}
