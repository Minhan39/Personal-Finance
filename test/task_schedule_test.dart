import 'package:flutter_test/flutter_test.dart';
import 'package:personal_finance/features/tasks/task_agenda.dart';
import 'package:personal_finance/models/task_item.dart';
import 'package:personal_finance/service/task_notification_service.dart';

TaskItem task({
  String id = 't',
  TaskRepeat repeat = TaskRepeat.none,
  List<int> weekdays = const [],
  required DateTime startAt,
  DateTime? endDate,
  DateTime? completedAt,
  Set<String> doneDays = const {},
  bool remind = true,
}) {
  return TaskItem(
    id: id,
    title: 'Việc $id',
    repeat: repeat,
    weekdays: weekdays,
    startAt: startAt,
    endDate: endDate,
    completedAt: completedAt,
    doneDays: doneDays,
    remind: remind,
  );
}

void main() {
  // Monday 9 November 2026, 10:00.
  final now = DateTime(2026, 11, 9, 10);

  group('occurrencesFrom', () {
    test('one-time task yields only its own time, if not past', () {
      final t = task(startAt: DateTime(2026, 11, 12, 8));
      expect(t.occurrencesFrom(now).toList(), [DateTime(2026, 11, 12, 8)]);
      expect(t.occurrencesFrom(DateTime(2026, 11, 13)).toList(), isEmpty);
    });

    test('daily task repeats at the same time and honours the end date', () {
      final t = task(
        repeat: TaskRepeat.daily,
        startAt: DateTime(2026, 11, 1, 7, 30),
        endDate: DateTime(2026, 11, 11),
      );
      expect(t.occurrencesFrom(now).toList(), [
        DateTime(2026, 11, 10, 7, 30),
        DateTime(2026, 11, 11, 7, 30),
      ]);
    });

    test('weekly task only lands on the chosen weekdays', () {
      final t = task(
        repeat: TaskRepeat.weekly,
        weekdays: const [DateTime.monday, DateTime.thursday],
        startAt: DateTime(2026, 11, 2, 20),
      );
      expect(t.occurrencesFrom(now).take(3).toList(), [
        DateTime(2026, 11, 9, 20),
        DateTime(2026, 11, 12, 20),
        DateTime(2026, 11, 16, 20),
      ]);
    });

    test('monthly task on the 31st falls back to the last day of month', () {
      final t = task(
        repeat: TaskRepeat.monthly,
        startAt: DateTime(2026, 1, 31, 9),
      );
      expect(t.occurrencesFrom(DateTime(2026, 2, 1)).take(3).toList(), [
        DateTime(2026, 2, 28, 9),
        DateTime(2026, 3, 31, 9),
        DateTime(2026, 4, 30, 9),
      ]);
    });
  });

  group('completion', () {
    test('ticking a recurring task skips to the next occurrence', () {
      final t = task(
        repeat: TaskRepeat.daily,
        startAt: DateTime(2026, 11, 1, 8),
      );
      expect(t.nextPending(now), DateTime(2026, 11, 9, 8));

      final done = t.toggledOn(DateTime(2026, 11, 9, 8), now: now);
      expect(done.isDoneOn(now), isTrue);
      expect(done.nextPending(now), DateTime(2026, 11, 10, 8));

      final undone = done.toggledOn(DateTime(2026, 11, 9, 8), now: now);
      expect(undone.isDoneOn(now), isFalse);
    });

    test('one-time task is finished once ticked', () {
      final t = task(startAt: DateTime(2026, 11, 8, 8));
      expect(t.nextPending(now), DateTime(2026, 11, 8, 8));
      expect(t.toggledOn(t.startAt, now: now).isFinished(now), isTrue);
    });
  });

  test('agenda sorts tasks into overdue, today, tomorrow and upcoming', () {
    final entries = buildAgenda([
      task(id: 'late', startAt: DateTime(2026, 11, 7, 9)),
      task(id: 'today', startAt: DateTime(2026, 11, 9, 18)),
      task(id: 'tomorrow', startAt: DateTime(2026, 11, 10, 9)),
      task(id: 'later', startAt: DateTime(2026, 11, 20, 9)),
      task(
        id: 'doneToday',
        repeat: TaskRepeat.daily,
        startAt: DateTime(2026, 11, 1, 6),
        doneDays: {'2026-11-09'},
      ),
      task(
        id: 'finished',
        startAt: DateTime(2026, 11, 1, 6),
        completedAt: DateTime(2026, 11, 2),
      ),
    ], now);

    expect(entries.map((e) => '${e.task.id}:${e.section.name}:${e.checked}'), [
      'late:overdue:false',
      'today:today:false',
      'doneToday:today:true',
      'tomorrow:tomorrow:false',
      'later:upcoming:false',
    ]);
  });

  test('reminders skip done days, finished tasks and muted tasks', () {
    final planned = TaskNotificationService.plannedReminders([
      task(
        id: 'daily',
        repeat: TaskRepeat.daily,
        startAt: DateTime(2026, 11, 1, 8),
        endDate: DateTime(2026, 11, 12),
        doneDays: {'2026-11-10'},
      ),
      task(id: 'muted', startAt: DateTime(2026, 11, 10, 9), remind: false),
      task(
        id: 'done',
        startAt: DateTime(2026, 11, 10, 9),
        completedAt: DateTime(2026, 11, 9),
      ),
      task(id: 'once', startAt: DateTime(2026, 11, 9, 12)),
    ], now);

    expect(planned.map((p) => p.$3), [
      DateTime(2026, 11, 9, 12),
      DateTime(2026, 11, 11, 8),
      DateTime(2026, 11, 12, 8),
    ]);
    expect(planned.map((p) => p.$1).toSet(), hasLength(3));
  });
}
