import 'dart:async';

import 'package:flutter/foundation.dart';
import 'package:flutter_local_notifications/flutter_local_notifications.dart';
import 'package:flutter_timezone/flutter_timezone.dart';
import 'package:timezone/data/latest_all.dart' as tz_data;
import 'package:timezone/timezone.dart' as tz;

import '../models/task_item.dart';

/// Schedules on-device reminders for tasks.
///
/// Every sync replaces all pending reminders with the next occurrences of
/// each task (up to [_perTaskLimit] per task and [_totalLimit] overall, to
/// stay under Android's alarm cap). The window is refreshed whenever the
/// task list changes or the app starts, so repeating tasks keep firing as
/// long as the app is opened now and then.
class TaskNotificationService {
  TaskNotificationService._();

  static const payloadPrefix = 'task:';
  static const _perTaskLimit = 30;
  static const _totalLimit = 400;
  static const _horizon = Duration(days: 60);

  static final _plugin = FlutterLocalNotificationsPlugin();
  static final _taps = StreamController<String>.broadcast();
  static bool _ready = false;
  static Future<void> _queue = Future.value();

  /// Payloads of reminders the user tapped while the app was running.
  static Stream<String> get taps => _taps.stream;

  static const _details = NotificationDetails(
    android: AndroidNotificationDetails(
      'task_reminders',
      'Nhắc việc',
      channelDescription: 'Thông báo khi đến giờ làm một công việc',
      importance: Importance.high,
      priority: Priority.high,
    ),
    iOS: DarwinNotificationDetails(),
  );

  static Future<void> init() async {
    if (kIsWeb) return;
    tz_data.initializeTimeZones();
    try {
      final zone = await FlutterTimezone.getLocalTimezone();
      tz.setLocalLocation(tz.getLocation(zone.identifier));
    } catch (error) {
      debugPrint('Local timezone unavailable, using Asia/Ho_Chi_Minh: $error');
      tz.setLocalLocation(tz.getLocation('Asia/Ho_Chi_Minh'));
    }

    await _plugin.initialize(
      const InitializationSettings(
        android: AndroidInitializationSettings('@mipmap/ic_launcher'),
        iOS: DarwinInitializationSettings(
          requestAlertPermission: false,
          requestBadgePermission: false,
          requestSoundPermission: false,
        ),
      ),
      onDidReceiveNotificationResponse: (response) {
        final payload = response.payload;
        if (payload != null && payload.startsWith(payloadPrefix)) {
          _taps.add(payload);
        }
      },
    );
    _ready = true;
  }

  /// Payload of the reminder that launched the app, if any.
  static Future<String?> launchPayload() async {
    if (!_ready) return null;
    final details = await _plugin.getNotificationAppLaunchDetails();
    if (details?.didNotificationLaunchApp != true) return null;
    final payload = details!.notificationResponse?.payload;
    return payload != null && payload.startsWith(payloadPrefix)
        ? payload
        : null;
  }

  static AndroidFlutterLocalNotificationsPlugin? get _android => _plugin
      .resolvePlatformSpecificImplementation<
        AndroidFlutterLocalNotificationsPlugin
      >();

  /// Asks for permission to show notifications; `true` when allowed.
  static Future<bool> requestPermission() async {
    if (!_ready) return false;
    final android = _android;
    if (android != null) {
      return await android.requestNotificationsPermission() ?? false;
    }
    final ios = _plugin
        .resolvePlatformSpecificImplementation<
          IOSFlutterLocalNotificationsPlugin
        >();
    return await ios?.requestPermissions(
          alert: true,
          badge: true,
          sound: true,
        ) ??
        true;
  }

  /// Whether reminders can fire at the exact minute (Android 12+ needs the
  /// user's approval; otherwise Android may delay them a little).
  static Future<bool> canScheduleExact() async {
    if (!_ready) return false;
    return await _android?.canScheduleExactNotifications() ?? true;
  }

  /// Opens the system screen to allow exact reminders.
  static Future<void> requestExactPermission() async {
    if (!_ready) return;
    await _android?.requestExactAlarmsPermission();
  }

  /// Replaces all scheduled reminders with those of [tasks]. Calls are
  /// queued so overlapping syncs never interleave.
  static Future<void> sync(List<TaskItem> tasks) {
    _queue = _queue.then((_) => _sync(tasks)).catchError((Object error) {
      debugPrint('Task reminder sync failed: $error');
    });
    return _queue;
  }

  static Future<void> cancelAll() async {
    if (!_ready) return;
    await _plugin.cancelAll();
  }

  /// The reminders [sync] would schedule, soonest first. Exposed for tests.
  @visibleForTesting
  static List<(int, TaskItem, DateTime)> plannedReminders(
    List<TaskItem> tasks,
    DateTime now,
  ) {
    final limit = now.add(_horizon);
    final planned = <(int, TaskItem, DateTime)>[];
    for (final task in tasks) {
      if (!task.remind) continue;
      if (!task.isRecurring && task.completedAt != null) continue;

      var index = 0;
      for (final occurrence in task.occurrencesFrom(now)) {
        if (index >= _perTaskLimit || occurrence.isAfter(limit)) break;
        if (task.doneDays.contains(TaskItem.dayKey(occurrence))) continue;
        planned.add((0, task, occurrence));
        index++;
      }
    }
    planned.sort((a, b) => a.$3.compareTo(b.$3));
    // Every sync cancels all reminders first, so ids only need to be unique
    // within one sync: number them in time order.
    return [
      for (final (i, (_, task, at)) in planned.take(_totalLimit).indexed)
        (i + 1, task, at),
    ];
  }

  static Future<void> _sync(List<TaskItem> tasks) async {
    if (!_ready) return;
    await _plugin.cancelAll();

    final exact = await canScheduleExact();
    final mode = exact
        ? AndroidScheduleMode.exactAllowWhileIdle
        : AndroidScheduleMode.inexactAllowWhileIdle;

    for (final (id, task, fireAt) in plannedReminders(tasks, DateTime.now())) {
      await _plugin.zonedSchedule(
        id,
        task.title,
        task.note.isNotEmpty ? task.note : 'Đến giờ: ${task.scheduleLabel()}',
        tz.TZDateTime.from(fireAt, tz.local),
        _details,
        androidScheduleMode: mode,
        payload: '$payloadPrefix${task.id}',
      );
    }
  }
}
