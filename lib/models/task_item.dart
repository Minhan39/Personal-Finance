import 'dart:math' as math;

import 'package:cloud_firestore/cloud_firestore.dart';

/// How often a task comes back.
enum TaskRepeat {
  none('Một lần'),
  daily('Hằng ngày'),
  weekly('Hằng tuần'),
  monthly('Hằng tháng');

  const TaskRepeat(this.label);

  final String label;

  static TaskRepeat fromName(String? name) => TaskRepeat.values.firstWhere(
    (repeat) => repeat.name == name,
    orElse: () => TaskRepeat.none,
  );
}

/// Short Vietnamese weekday names, indexed by [DateTime.weekday] - 1.
const weekdayShortNames = ['T2', 'T3', 'T4', 'T5', 'T6', 'T7', 'CN'];

/// A to-do item, either done once at [startAt] or repeated from [startAt]
/// (daily, on chosen weekdays, or monthly) until the optional [endDate].
class TaskItem {
  const TaskItem({
    this.id = '',
    required this.title,
    this.note = '',
    this.repeat = TaskRepeat.none,
    this.weekdays = const [],
    required this.startAt,
    this.endDate,
    this.remind = true,
    this.completedAt,
    this.doneDays = const {},
    this.createdAt,
  });

  /// Firestore document id; empty until the task is saved.
  final String id;
  final String title;
  final String note;
  final TaskRepeat repeat;

  /// [DateTime.monday]..[DateTime.sunday], used when [repeat] is weekly.
  final List<int> weekdays;

  /// Date and time of the first occurrence; its time of day is reused by
  /// every repetition.
  final DateTime startAt;

  /// Last day (inclusive) a recurring task repeats on.
  final DateTime? endDate;

  /// Whether a notification is shown at each occurrence.
  final bool remind;

  /// When a one-time task was ticked off.
  final DateTime? completedAt;

  /// Days ([dayKey]) on which a recurring task's occurrence was ticked off.
  final Set<String> doneDays;
  final DateTime? createdAt;

  bool get isRecurring => repeat != TaskRepeat.none;

  static String dayKey(DateTime date) =>
      '${date.year.toString().padLeft(4, '0')}-'
      '${date.month.toString().padLeft(2, '0')}-'
      '${date.day.toString().padLeft(2, '0')}';

  static DateTime _dateOnly(DateTime date) =>
      DateTime(date.year, date.month, date.day);

  DateTime _at(DateTime day) =>
      DateTime(day.year, day.month, day.day, startAt.hour, startAt.minute);

  /// Weekdays the task repeats on; defaults to the start date's weekday.
  Set<int> get effectiveWeekdays =>
      weekdays.isEmpty ? {startAt.weekday} : weekdays.toSet();

  /// Occurrences at or after [from], in order, stopping after [endDate].
  /// Infinite for open-ended recurring tasks, so callers must limit it.
  Iterable<DateTime> occurrencesFrom(DateTime from) sync* {
    final end = endDate;
    final lastMoment = end == null
        ? null
        : DateTime(end.year, end.month, end.day, 23, 59, 59);
    bool afterEnd(DateTime value) =>
        lastMoment != null && value.isAfter(lastMoment);

    switch (repeat) {
      case TaskRepeat.none:
        if (!startAt.isBefore(from)) yield startAt;

      case TaskRepeat.daily:
      case TaskRepeat.weekly:
        final days = repeat == TaskRepeat.daily
            ? const {1, 2, 3, 4, 5, 6, 7}
            : effectiveWeekdays;
        final startDay = _dateOnly(startAt);
        final fromDay = _dateOnly(from);
        var day = fromDay.isAfter(startDay) ? fromDay : startDay;
        // Ten years of days is far more than any caller takes.
        for (var i = 0; i < 3660; i++) {
          if (afterEnd(day)) return;
          if (days.contains(day.weekday)) {
            final occurrence = _at(day);
            if (!occurrence.isBefore(from)) {
              if (afterEnd(occurrence)) return;
              yield occurrence;
            }
          }
          day = DateTime(day.year, day.month, day.day + 1);
        }

      case TaskRepeat.monthly:
        for (var i = 0; i < 1200; i++) {
          final month = DateTime(startAt.year, startAt.month + i);
          final lastDayOfMonth = DateTime(month.year, month.month + 1, 0).day;
          final occurrence = _at(
            DateTime(
              month.year,
              month.month,
              math.min(startAt.day, lastDayOfMonth),
            ),
          );
          if (occurrence.isBefore(from)) continue;
          if (afterEnd(occurrence)) return;
          yield occurrence;
        }
    }
  }

  /// The occurrence the user still has to do: for a one-time task its date
  /// (even if overdue), for a recurring task the first occurrence from today
  /// that isn't ticked off. `null` when nothing is left.
  DateTime? nextPending(DateTime now) {
    if (!isRecurring) return completedAt == null ? startAt : null;
    for (final occurrence in occurrencesFrom(_dateOnly(now)).take(400)) {
      if (!doneDays.contains(dayKey(occurrence))) return occurrence;
    }
    return null;
  }

  /// Whether a recurring task has an occurrence today that was ticked off.
  bool isDoneOn(DateTime day) =>
      isRecurring &&
      doneDays.contains(dayKey(day)) &&
      occurrencesFrom(
        _dateOnly(day),
      ).take(1).any((occurrence) => dayKey(occurrence) == dayKey(day));

  /// Nothing left to do: a completed one-time task, or a recurring task
  /// whose last occurrence is done or past.
  bool isFinished(DateTime now) => nextPending(now) == null;

  /// "08:00 · Hằng tuần T2, T4" style description of the schedule.
  String scheduleLabel() {
    final time =
        '${startAt.hour.toString().padLeft(2, '0')}:'
        '${startAt.minute.toString().padLeft(2, '0')}';
    switch (repeat) {
      case TaskRepeat.none:
        return time;
      case TaskRepeat.daily:
        return '$time · Hằng ngày';
      case TaskRepeat.weekly:
        final days = effectiveWeekdays.toList()..sort();
        return '$time · ${days.length == 7 ? 'Hằng ngày' : days.map((d) => weekdayShortNames[d - 1]).join(', ')}';
      case TaskRepeat.monthly:
        return '$time · Ngày ${startAt.day} hằng tháng';
    }
  }

  /// Ticks off (or un-ticks) the occurrence on [day] for recurring tasks,
  /// or the whole task for one-time tasks.
  TaskItem toggledOn(DateTime day, {required DateTime now}) {
    if (!isRecurring) {
      return copyWith(
        completedAt: completedAt == null ? now : null,
        clearCompletedAt: completedAt != null,
      );
    }
    final key = dayKey(day);
    final cutoff = dayKey(now.subtract(const Duration(days: 90)));
    final days = {...doneDays.where((d) => d.compareTo(cutoff) >= 0)};
    if (!days.remove(key)) days.add(key);
    return copyWith(doneDays: days);
  }

  TaskItem copyWith({
    String? id,
    String? title,
    String? note,
    TaskRepeat? repeat,
    List<int>? weekdays,
    DateTime? startAt,
    DateTime? endDate,
    bool clearEndDate = false,
    bool? remind,
    DateTime? completedAt,
    bool clearCompletedAt = false,
    Set<String>? doneDays,
  }) {
    return TaskItem(
      id: id ?? this.id,
      title: title ?? this.title,
      note: note ?? this.note,
      repeat: repeat ?? this.repeat,
      weekdays: weekdays ?? this.weekdays,
      startAt: startAt ?? this.startAt,
      endDate: clearEndDate ? null : (endDate ?? this.endDate),
      remind: remind ?? this.remind,
      completedAt: clearCompletedAt ? null : (completedAt ?? this.completedAt),
      doneDays: doneDays ?? this.doneDays,
      createdAt: createdAt,
    );
  }

  Map<String, dynamic> toFirestore() {
    return {
      'title': title,
      'note': note,
      'repeat': repeat.name,
      'weekdays': weekdays,
      'startAt': Timestamp.fromDate(startAt),
      'endDate': endDate == null ? null : Timestamp.fromDate(endDate!),
      'remind': remind,
      'completedAt': completedAt == null
          ? null
          : Timestamp.fromDate(completedAt!),
      'doneDays': doneDays.toList()..sort(),
    };
  }

  factory TaskItem.fromFirestore(String id, Map<String, dynamic> data) {
    DateTime? date(Object? value) => value is Timestamp ? value.toDate() : null;

    return TaskItem(
      id: id,
      title: data['title'] as String? ?? '',
      note: data['note'] as String? ?? '',
      repeat: TaskRepeat.fromName(data['repeat'] as String?),
      weekdays: [
        for (final day in data['weekdays'] as List? ?? const [])
          if (day is num) day.toInt(),
      ],
      startAt: date(data['startAt']) ?? DateTime.now(),
      endDate: date(data['endDate']),
      remind: data['remind'] as bool? ?? true,
      completedAt: date(data['completedAt']),
      doneDays: {
        for (final day in data['doneDays'] as List? ?? const []) day.toString(),
      },
      createdAt: date(data['createdAt']),
    );
  }
}
