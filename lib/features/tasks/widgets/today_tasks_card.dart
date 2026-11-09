import 'package:flutter/material.dart';

import '../../../models/task_item.dart';
import '../../../service/task_service.dart';
import '../../../shared/ui/ui.dart';
import '../task_agenda.dart';
import 'task_tile.dart';

/// Home-screen card with today's and overdue tasks, tickable in place.
class TodayTasksCard extends StatefulWidget {
  const TodayTasksCard({super.key});

  @override
  State<TodayTasksCard> createState() => _TodayTasksCardState();
}

class _TodayTasksCardState extends State<TodayTasksCard> {
  static const _maxItems = 4;
  late final Stream<List<TaskItem>> _tasks = TaskService.watch();

  @override
  Widget build(BuildContext context) {
    return StreamBuilder<List<TaskItem>>(
      stream: _tasks,
      builder: (context, snapshot) {
        final tasks = snapshot.data;
        // Stay out of the way until the user has created a task.
        if (tasks == null || tasks.isEmpty) return const SizedBox.shrink();

        final now = DateTime.now();
        final entries = buildAgenda(tasks, now)
            .where(
              (e) =>
                  e.section == AgendaSection.overdue ||
                  e.section == AgendaSection.today,
            )
            .toList();
        final remaining = entries.where((e) => !e.checked).length;
        final theme = Theme.of(context);

        return Padding(
          padding: const EdgeInsets.only(top: 20),
          child: AppCard(
            padding: const EdgeInsets.fromLTRB(8, 8, 8, 12),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Padding(
                  padding: const EdgeInsets.only(left: 8),
                  child: SectionHeader(
                    title: remaining == 0
                        ? 'Việc hôm nay'
                        : 'Việc hôm nay · còn $remaining',
                    actionLabel: 'Xem tất cả',
                    onAction: () => Navigator.pushNamed(context, '/tasks'),
                  ),
                ),
                if (entries.isEmpty)
                  Padding(
                    padding: const EdgeInsets.fromLTRB(8, 4, 8, 0),
                    child: Text(
                      'Hôm nay không có việc nào.',
                      style: theme.textTheme.bodySmall?.copyWith(
                        color: theme.colorScheme.onSurfaceVariant,
                      ),
                    ),
                  )
                else
                  for (final entry in entries.take(_maxItems))
                    TaskTile(
                      task: entry.task,
                      checked: entry.checked,
                      overdue: entry.section == AgendaSection.overdue,
                      subtitle: entry.section == AgendaSection.overdue
                          ? 'Quá hạn · ${taskWhenLabel(entry.when, now)}'
                          : taskWhenLabel(entry.when, now),
                      onToggle: () => toggleAgendaEntry(context, entry),
                      onTap: () => Navigator.pushNamed(
                        context,
                        '/tasks/edit',
                        arguments: entry.task,
                      ),
                    ),
                if (entries.length > _maxItems)
                  Padding(
                    padding: const EdgeInsets.only(left: 16, top: 4),
                    child: Text(
                      '+${entries.length - _maxItems} việc khác',
                      style: theme.textTheme.bodySmall?.copyWith(
                        color: theme.colorScheme.onSurfaceVariant,
                      ),
                    ),
                  ),
              ],
            ),
          ),
        );
      },
    );
  }
}
