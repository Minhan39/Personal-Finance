import 'package:flutter/material.dart';

import '../../models/task_item.dart';
import '../../service/task_service.dart';

enum AgendaSection {
  overdue('Quá hạn'),
  today('Hôm nay'),
  tomorrow('Ngày mai'),
  upcoming('Sắp tới');

  const AgendaSection(this.label);

  final String label;
}

/// A task as it appears in the to-do list: its relevant occurrence, whether
/// that occurrence is ticked off, and which section it falls in.
class AgendaEntry {
  const AgendaEntry({
    required this.task,
    required this.when,
    required this.checked,
    required this.section,
  });

  final TaskItem task;
  final DateTime when;
  final bool checked;
  final AgendaSection section;
}

DateTime _dateOnly(DateTime date) => DateTime(date.year, date.month, date.day);

/// Builds the to-do list for [now]. Each task appears once: at its next
/// pending occurrence, or ticked in "today" when today's occurrence (or the
/// one-time task) was completed today, so it can still be undone.
List<AgendaEntry> buildAgenda(List<TaskItem> tasks, DateTime now) {
  final today = _dateOnly(now);
  final tomorrow = DateTime(today.year, today.month, today.day + 1);
  final entries = <AgendaEntry>[];

  for (final task in tasks) {
    if (task.isRecurring && task.isDoneOn(now)) {
      entries.add(
        AgendaEntry(
          task: task,
          when: DateTime(
            today.year,
            today.month,
            today.day,
            task.startAt.hour,
            task.startAt.minute,
          ),
          checked: true,
          section: AgendaSection.today,
        ),
      );
      continue;
    }

    final completedAt = task.completedAt;
    if (!task.isRecurring && completedAt != null) {
      if (_dateOnly(completedAt) == today) {
        entries.add(
          AgendaEntry(
            task: task,
            when: task.startAt,
            checked: true,
            section: AgendaSection.today,
          ),
        );
      }
      continue;
    }

    final pending = task.nextPending(now);
    if (pending == null) continue;
    final day = _dateOnly(pending);
    final section = day.isBefore(today)
        ? AgendaSection.overdue
        : day == today
        ? AgendaSection.today
        : day == tomorrow
        ? AgendaSection.tomorrow
        : AgendaSection.upcoming;
    entries.add(
      AgendaEntry(task: task, when: pending, checked: false, section: section),
    );
  }

  entries.sort((a, b) {
    final bySection = a.section.index.compareTo(b.section.index);
    if (bySection != 0) return bySection;
    if (a.checked != b.checked) return a.checked ? 1 : -1;
    return a.when.compareTo(b.when);
  });
  return entries;
}

/// Ticks the entry's occurrence on or off and saves the task.
Future<void> toggleAgendaEntry(BuildContext context, AgendaEntry entry) async {
  final messenger = ScaffoldMessenger.of(context);
  try {
    await TaskService.save(
      entry.task.toggledOn(entry.when, now: DateTime.now()),
    );
  } catch (error) {
    messenger.showSnackBar(
      const SnackBar(content: Text('Không cập nhật được công việc.')),
    );
  }
}
