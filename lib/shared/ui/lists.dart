import 'package:flutter/material.dart';

import '../../core/theme/module_palette.dart';
import 'cards.dart';

/// One income/expense row: icon badge, title, subtitle and signed amount.
class TransactionTile extends StatelessWidget {
  const TransactionTile({
    super.key,
    required this.icon,
    required this.tone,
    required this.title,
    required this.amount,
    this.subtitle,
    this.positive = false,
    this.onTap,
  });

  final IconData icon;
  final ModuleTone tone;
  final String title;
  final String? subtitle;

  /// Already formatted, without sign.
  final String amount;

  /// Income (green, "+") versus expense ("−").
  final bool positive;
  final VoidCallback? onTap;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(12),
      child: Padding(
        padding: const EdgeInsets.symmetric(vertical: 8),
        child: Row(
          children: [
            IconBadge(icon: icon, tone: tone),
            const SizedBox(width: 12),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    title,
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: theme.textTheme.bodyMedium?.copyWith(
                      fontWeight: FontWeight.w500,
                    ),
                  ),
                  if (subtitle != null && subtitle!.isNotEmpty)
                    Text(
                      subtitle!,
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: theme.textTheme.bodySmall?.copyWith(
                        color: theme.colorScheme.onSurfaceVariant,
                      ),
                    ),
                ],
              ),
            ),
            const SizedBox(width: 8),
            Text(
              '${positive ? '+' : '−'}$amount',
              style: theme.textTheme.bodyMedium?.copyWith(
                fontWeight: FontWeight.w600,
                color: positive ? Colors.green.shade600 : null,
              ),
            ),
          ],
        ),
      ),
    );
  }
}

/// Muted date heading between groups of transactions.
class DayHeader extends StatelessWidget {
  const DayHeader(this.label, {super.key});

  final String label;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return Padding(
      padding: const EdgeInsets.only(top: 12, bottom: 2),
      child: Text(
        label,
        style: theme.textTheme.labelMedium?.copyWith(
          color: theme.colorScheme.onSurfaceVariant,
        ),
      ),
    );
  }
}

/// Red "delete" background revealed when swiping a row to the left.
class SwipeDeleteBackground extends StatelessWidget {
  const SwipeDeleteBackground({super.key});

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    return Container(
      alignment: Alignment.centerRight,
      padding: const EdgeInsets.symmetric(horizontal: 20),
      decoration: BoxDecoration(
        color: scheme.errorContainer,
        borderRadius: BorderRadius.circular(12),
      ),
      child: Icon(Icons.delete_outline, color: scheme.onErrorContainer),
    );
  }
}

/// Asks before deleting; resolves to `true` only when confirmed.
Future<bool> confirmDelete(BuildContext context, String message) async {
  final confirmed = await showDialog<bool>(
    context: context,
    builder: (dialogContext) => AlertDialog(
      title: const Text('Xác nhận xoá'),
      content: Text(message),
      actions: [
        TextButton(
          onPressed: () => Navigator.pop(dialogContext, false),
          child: const Text('Huỷ'),
        ),
        FilledButton(
          onPressed: () => Navigator.pop(dialogContext, true),
          child: const Text('Xoá'),
        ),
      ],
    ),
  );
  return confirmed ?? false;
}

/// Groups items by calendar day, newest day first.
List<(DateTime, List<T>)> groupByDay<T>(
  Iterable<T> items,
  DateTime Function(T item) dateOf,
) {
  final groups = <DateTime, List<T>>{};
  for (final item in items) {
    final date = dateOf(item);
    groups
        .putIfAbsent(DateTime(date.year, date.month, date.day), () => [])
        .add(item);
  }
  final days = groups.keys.toList()..sort((a, b) => b.compareTo(a));
  return [
    for (final day in days)
      (day, groups[day]!..sort((a, b) => dateOf(b).compareTo(dateOf(a)))),
  ];
}

/// "Hôm nay", "Hôm qua" or "dd/MM/yyyy".
String dayLabel(DateTime day) {
  final today = DateTime.now();
  final todayDate = DateTime(today.year, today.month, today.day);
  final difference = todayDate.difference(day).inDays;
  if (difference == 0) return 'Hôm nay';
  if (difference == 1) return 'Hôm qua';
  final dd = day.day.toString().padLeft(2, '0');
  final mm = day.month.toString().padLeft(2, '0');
  return '$dd/$mm/${day.year}';
}
