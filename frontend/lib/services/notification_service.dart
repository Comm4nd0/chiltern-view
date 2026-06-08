import 'package:flutter_local_notifications/flutter_local_notifications.dart';
import 'package:timezone/data/latest_all.dart' as tzdata;
import 'package:timezone/timezone.dart' as tz;

import '../api/api_client.dart';
import '../config.dart';
import '../models/care_task.dart';

/// Schedules on-device reminders for care tasks. No cloud or push service —
/// everything is registered with the OS so it fires even when the app is closed.
///
/// Because care tasks recur on a fixed interval, each task's future due dates
/// are deterministic, so we can schedule a rolling window of reminders ahead of
/// time and refresh them whenever the app syncs.
class NotificationService {
  NotificationService._();
  static final NotificationService instance = NotificationService._();

  final FlutterLocalNotificationsPlugin _plugin = FlutterLocalNotificationsPlugin();
  bool _ready = false;

  /// How many days ahead to schedule reminders for.
  static const int _windowDays = 14;

  /// iOS allows at most 64 pending local notifications; stay well under.
  static const int _maxScheduled = 56;

  static const String _channelId = 'care_tasks';
  static const String _channelName = 'Care task reminders';
  static const String _channelDesc = 'Reminders to do smallholding care tasks';

  /// UK smallholding — schedule against UK wall-clock time. Change here if the
  /// holding is ever elsewhere.
  static const String _timeZone = 'Europe/London';

  Future<void> init() async {
    if (_ready) return;
    tzdata.initializeTimeZones();
    tz.setLocalLocation(tz.getLocation(_timeZone));

    const android = AndroidInitializationSettings('@mipmap/ic_launcher');
    const darwin = DarwinInitializationSettings(
      requestAlertPermission: false,
      requestBadgePermission: false,
      requestSoundPermission: false,
    );
    await _plugin.initialize(
      const InitializationSettings(android: android, iOS: darwin, macOS: darwin),
    );
    _ready = true;
  }

  /// Ask the OS for notification permission. Returns true if granted.
  Future<bool> requestPermissions() async {
    await init();
    final ios = _plugin
        .resolvePlatformSpecificImplementation<IOSFlutterLocalNotificationsPlugin>();
    if (ios != null) {
      final granted = await ios.requestPermissions(alert: true, badge: true, sound: true);
      return granted ?? false;
    }
    final android = _plugin
        .resolvePlatformSpecificImplementation<AndroidFlutterLocalNotificationsPlugin>();
    if (android != null) {
      final granted = await android.requestNotificationsPermission();
      return granted ?? true;
    }
    return true;
  }

  Future<void> cancelAll() async {
    await init();
    await _plugin.cancelAll();
  }

  /// Cancel everything and (re)schedule reminders for [myTasks] — already
  /// filtered to this device's person. Honours [AppConfig] reminder settings.
  Future<void> reschedule(List<CareTask> myTasks) async {
    await init();
    await _plugin.cancelAll();
    if (!AppConfig.remindersEnabled) return;

    final now = tz.TZDateTime.now(tz.local);
    final today = tz.TZDateTime(tz.local, now.year, now.month, now.day);
    final horizon = today.add(const Duration(days: _windowDays));
    var id = 0;

    tz.TZDateTime fireTime(tz.TZDateTime day) => tz.TZDateTime(
          tz.local,
          day.year,
          day.month,
          day.day,
          AppConfig.reminderHour,
          AppConfig.reminderMinute,
        );

    // --- Morning digest: for each day in the window, list what's due/overdue.
    for (var offset = 0; offset <= _windowDays && id < _maxScheduled; offset++) {
      final day = today.add(Duration(days: offset));
      final when = fireTime(day);
      if (when.isBefore(now)) continue; // today's time already passed
      final due = myTasks.where((t) => !_dueDate(t).isAfter(day)).toList();
      if (due.isEmpty) continue;
      await _schedule(id++, 'Tasks to do', _digestBody(due), when);
    }

    // --- Per-task ping on each task's due date.
    for (final task in myTasks) {
      if (id >= _maxScheduled) break;
      final dueDate = _dueDate(task);
      if (dueDate.isAfter(horizon)) continue;
      final when = fireTime(dueDate);
      if (when.isBefore(now)) continue; // overdue/today-past — digest covers it
      final detail = task.animalName != null ? 'For ${task.animalName}' : 'Care task due today';
      await _schedule(id++, 'Due today: ${task.name}', detail, when);
    }
  }

  tz.TZDateTime _dueDate(CareTask task) {
    final d = task.nextDue;
    return tz.TZDateTime(tz.local, d.year, d.month, d.day);
  }

  String _digestBody(List<CareTask> due) {
    final names = due.take(4).map((t) => t.name).join(', ');
    final extra = due.length > 4 ? ' +${due.length - 4} more' : '';
    return '${due.length} task${due.length == 1 ? '' : 's'} to do: $names$extra';
  }

  Future<void> _schedule(int id, String title, String body, tz.TZDateTime when) async {
    await _plugin.zonedSchedule(
      id,
      title,
      body,
      when,
      const NotificationDetails(
        android: AndroidNotificationDetails(
          _channelId,
          _channelName,
          channelDescription: _channelDesc,
          importance: Importance.high,
          priority: Priority.high,
        ),
        iOS: DarwinNotificationDetails(),
      ),
      androidScheduleMode: AndroidScheduleMode.inexactAllowWhileIdle,
      uiLocalNotificationDateInterpretation: UILocalNotificationDateInterpretation.absoluteTime,
    );
  }
}

/// Fetch this device's tasks and refresh scheduled reminders. No-op (and clears
/// any existing schedule) when no person is set for this device or reminders are
/// off. Leaves the existing schedule untouched if the server is unreachable.
Future<void> syncReminders(ApiClient api) async {
  if (AppConfig.myPersonId == null || !AppConfig.remindersEnabled) {
    await NotificationService.instance.cancelAll();
    return;
  }
  try {
    final tasks = await api.dashboard(
      assignee: AppConfig.myPersonId.toString(),
      include: 'all',
    );
    await NotificationService.instance.reschedule(tasks);
  } catch (_) {
    // Offline / server down — keep whatever is already scheduled.
  }
}
