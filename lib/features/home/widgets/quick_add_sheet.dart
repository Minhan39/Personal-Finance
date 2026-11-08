import 'package:flutter/material.dart';

import '../../../shared/ui/ui.dart';
import '../../spending/widgets/add_expense_sheet.dart';

/// Bottom sheet behind the "+" tab: add an expense or an income.
class QuickAddSheet extends StatelessWidget {
  const QuickAddSheet({super.key});

  /// Resolves once the chosen form is closed.
  static Future<void> show(BuildContext context) async {
    final choice = await showModalBottomSheet<String>(
      context: context,
      showDragHandle: true,
      builder: (_) => const QuickAddSheet(),
    );
    if (choice == null || !context.mounted) return;

    if (choice == 'expense') {
      await AddExpenseSheet.show(context);
    } else {
      await Navigator.pushNamed(context, '/income/add');
    }
  }

  @override
  Widget build(BuildContext context) {
    return SafeArea(
      child: Padding(
        padding: const EdgeInsets.fromLTRB(16, 0, 16, 16),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Text(
              'Thêm giao dịch',
              style: Theme.of(
                context,
              ).textTheme.titleMedium?.copyWith(fontWeight: FontWeight.w600),
            ),
            const SizedBox(height: 16),
            _Option(
              icon: Icons.receipt_long_outlined,
              tone: ModuleTone.of(context, AppModule.spending),
              title: 'Chi tiêu',
              subtitle: 'Ghi lại một khoản đã chi',
              onTap: () => Navigator.pop(context, 'expense'),
            ),
            const SizedBox(height: 12),
            _Option(
              icon: Icons.account_balance_wallet_outlined,
              tone: ModuleTone.of(context, AppModule.income),
              title: 'Thu nhập',
              subtitle: 'Ghi lại một khoản tiền vào',
              onTap: () => Navigator.pop(context, 'income'),
            ),
          ],
        ),
      ),
    );
  }
}

class _Option extends StatelessWidget {
  const _Option({
    required this.icon,
    required this.tone,
    required this.title,
    required this.subtitle,
    required this.onTap,
  });

  final IconData icon;
  final ModuleTone tone;
  final String title;
  final String subtitle;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return AppCard(
      onTap: onTap,
      child: Row(
        children: [
          IconBadge(icon: icon, tone: tone, size: 44),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  title,
                  style: theme.textTheme.titleSmall?.copyWith(
                    fontWeight: FontWeight.w600,
                  ),
                ),
                Text(
                  subtitle,
                  style: theme.textTheme.bodySmall?.copyWith(
                    color: theme.colorScheme.onSurfaceVariant,
                  ),
                ),
              ],
            ),
          ),
          Icon(Icons.chevron_right, color: theme.colorScheme.outline),
        ],
      ),
    );
  }
}
