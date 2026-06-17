import 'package:flutter/material.dart' show TimeOfDay;

import '../util/json.dart';

class CareTask {
  final int id;
  final String name;
  final String description;
  final int? animal;
  final String? animalName;
  final String species; // animal type code (e.g. 'chicken'); '' if not type-level
  final String speciesDisplay; // human label for the type; '' if none
  final int? assignee;
  final String? assigneeName;
  final int recurrenceIntervalDays;
  final int timesPerDay; // how many times the task needs doing on its due day
  final int timesDoneToday; // completions recorded so far today
  final DateTime? lastCompleted;
  final DateTime? dueDate; // set => one-off task (doesn't repeat)
  final TimeOfDay? dueTime; // set => due/reminds at a clock time; null = anytime that day
  final DateTime? snoozedUntil; // 'remind me later' hold date; null when not snoozed
  final bool active;
  final DateTime nextDue;
  final int daysOverdue; // >0 overdue, 0 due today, <0 upcoming
  final String status; // overdue | due_today | upcoming
  final bool rainDeferred; // rain covers this watering job for today
  final String? weatherNote;

  CareTask({
    required this.id,
    required this.name,
    required this.description,
    required this.animal,
    required this.animalName,
    this.species = '',
    this.speciesDisplay = '',
    required this.assignee,
    required this.assigneeName,
    required this.recurrenceIntervalDays,
    this.timesPerDay = 1,
    this.timesDoneToday = 0,
    required this.lastCompleted,
    this.dueDate,
    this.dueTime,
    this.snoozedUntil,
    required this.active,
    required this.nextDue,
    required this.daysOverdue,
    required this.status,
    this.rainDeferred = false,
    this.weatherNote,
  });

  factory CareTask.fromJson(Map<String, dynamic> json) => CareTask(
        id: json['id'] as int,
        name: json['name'] as String? ?? '',
        description: json['description'] as String? ?? '',
        animal: json['animal'] as int?,
        animalName: json['animal_name'] as String?,
        species: json['species'] as String? ?? '',
        speciesDisplay: json['species_display'] as String? ?? '',
        assignee: json['assignee'] as int?,
        assigneeName: json['assignee_name'] as String?,
        recurrenceIntervalDays: json['recurrence_interval_days'] as int? ?? 0,
        timesPerDay: json['times_per_day'] as int? ?? 1,
        timesDoneToday: json['times_done_today'] as int? ?? 0,
        lastCompleted: asNullableDate(json['last_completed']),
        dueDate: asNullableDate(json['due_date']),
        dueTime: _parseTime(json['due_time'] as String?),
        snoozedUntil: asNullableDate(json['snoozed_until']),
        active: json['active'] as bool? ?? true,
        nextDue: asDate(json['next_due']),
        daysOverdue: json['days_overdue'] as int? ?? 0,
        status: json['status'] as String? ?? 'upcoming',
        rainDeferred: json['rain_deferred'] as bool? ?? false,
        weatherNote: json['weather_note'] as String?,
      );

  bool get isOverdue => status == 'overdue';

  /// Parse the API's "HH:MM:SS" time into a [TimeOfDay] (null when unset).
  static TimeOfDay? _parseTime(String? value) {
    if (value == null || value.isEmpty) return null;
    final parts = value.split(':');
    if (parts.length < 2) return null;
    final h = int.tryParse(parts[0]);
    final m = int.tryParse(parts[1]);
    if (h == null || m == null) return null;
    return TimeOfDay(hour: h, minute: m);
  }

  /// "07:30" (24h) for display, or null when the task has no set time.
  String? get dueTimeLabel {
    final t = dueTime;
    if (t == null) return null;
    return '${t.hour.toString().padLeft(2, '0')}:${t.minute.toString().padLeft(2, '0')}';
  }

  /// One-off tasks have a fixed due date and don't repeat.
  bool get isOneOff => dueDate != null;

  /// Human-friendly urgency label for the dashboard.
  String get dueLabel {
    if (status == 'due_today') {
      if (timesPerDay > 1 && timesDoneToday > 0) {
        return 'Due today ($timesDoneToday of $timesPerDay done)';
      }
      return 'Due today';
    }
    if (daysOverdue > 0) {
      return '$daysOverdue day${daysOverdue == 1 ? '' : 's'} overdue';
    }
    final inDays = -daysOverdue;
    return 'Due in $inDays day${inDays == 1 ? '' : 's'}';
  }

  /// "one-off", "daily", "4× a day", "every 3 days" — matches the web wording.
  String get recurrenceLabel {
    if (isOneOff) return 'one-off';
    if (timesPerDay > 1) {
      final times = '$timesPerDay× a day';
      return recurrenceIntervalDays == 1 ? times : 'every $recurrenceIntervalDays days, $times';
    }
    if (recurrenceIntervalDays == 1) return 'daily';
    return 'every $recurrenceIntervalDays days';
  }
}
