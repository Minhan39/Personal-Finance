import 'package:flutter/material.dart';

import '../../../models/task_item.dart';
import '../../../shared/ui/ui.dart';

/// One task row: round checkbox, title, schedule and reminder bell.
class TaskTile extends StatelessWidget {
  const TaskTile({
    super.key,
    required this.task,
    required this.checked,
    required this.subtitle,
    required this.onToggle,
    this.overdue = false,
    this.onTap,
  });

  final TaskItem task;
  final bool checked;
  final String subtitle;
  final VoidCallback onToggle;
  final bool overdue;
  final VoidCallback? onTap;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final tone = ModuleTone.of(context, AppModule.tasks);
    final muted = theme.colorScheme.onSurfaceVariant;

    return InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(12),
      child: Padding(
        padding: const EdgeInsets.symmetric(vertical: 4),
        child: Row(
          children: [
            IconButton(
              onPressed: onToggle,
              tooltip: checked ? 'Đánh dấu chưa xong' : 'Đánh dấu đã xong',
              icon: Icon(
                checked ? Icons.check_circle : Icons.radio_button_unchecked,
                color: checked ? tone.accent : theme.colorScheme.outline,
                size: 26,
              ),
            ),
            const SizedBox(width: 4),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    task.title,
                    maxLines: 2,
                    overflow: TextOverflow.ellipsis,
                    style: theme.textTheme.bodyLarge?.copyWith(
                      fontWeight: FontWeight.w500,
                      decoration: checked ? TextDecoration.lineThrough : null,
                      color: checked ? muted : null,
                    ),
                  ),
                  const SizedBox(height: 2),
                  Row(
                    children: [
                      if (task.isRecurring) ...[
                        Icon(Icons.repeat, size: 14, color: muted),
                        const SizedBox(width: 4),
                      ],
                      Flexible(
                        child: Text(
                          subtitle,
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                          style: theme.textTheme.bodySmall?.copyWith(
                            color: overdue && !checked
                                ? theme.colorScheme.error
                                : muted,
                          ),
                        ),
                      ),
                    ],
                  ),
                ],
              ),
            ),
            if (task.remind)
              Padding(
                padding: const EdgeInsets.only(left: 8, right: 4),
                child: Icon(
                  Icons.notifications_active_outlined,
                  size: 18,
                  color: muted,
                ),
              ),
          ],
        ),
      ),
    );
  }
}

/// "08:00" for today, otherwise "T5, 13/11 · 08:00".
String taskWhenLabel(DateTime when, DateTime now) {
  final time =
      '${when.hour.toString().padLeft(2, '0')}:'
      '${when.minute.toString().padLeft(2, '0')}';
  final sameDay =
      when.year == now.year && when.month == now.month && when.day == now.day;
  if (sameDay) return time;
  final date =
      '${weekdayShortNames[when.weekday - 1]}, '
      '${when.day.toString().padLeft(2, '0')}/'
      '${when.month.toString().padLeft(2, '0')}'
      '${when.year == now.year ? '' : '/${when.year}'}';
  return '$date · $time';
}
