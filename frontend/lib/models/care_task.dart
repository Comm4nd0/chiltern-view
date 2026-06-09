import '../util/json.dart';

class CareTask {
  final int id;
  final String name;
  final String description;
  final int? animal;
  final String? animalName;
  final int? assignee;
  final String? assigneeName;
  final int recurrenceIntervalDays;
  final DateTime? lastCompleted;
  final DateTime? dueDate; // set => one-off task (doesn't repeat)
  final bool active;
  final DateTime nextDue;
  final int daysOverdue; // >0 overdue, 0 due today, <0 upcoming
  final String status; // overdue | due_today | upcoming

  CareTask({
    required this.id,
    required this.name,
    required this.description,
    required this.animal,
    required this.animalName,
    required this.assignee,
    required this.assigneeName,
    required this.recurrenceIntervalDays,
    required this.lastCompleted,
    this.dueDate,
    required this.active,
    required this.nextDue,
    required this.daysOverdue,
    required this.status,
  });

  factory CareTask.fromJson(Map<String, dynamic> json) => CareTask(
        id: json['id'] as int,
        name: json['name'] as String? ?? '',
        description: json['description'] as String? ?? '',
        animal: json['animal'] as int?,
        animalName: json['animal_name'] as String?,
        assignee: json['assignee'] as int?,
        assigneeName: json['assignee_name'] as String?,
        recurrenceIntervalDays: json['recurrence_interval_days'] as int? ?? 0,
        lastCompleted: asNullableDate(json['last_completed']),
        dueDate: asNullableDate(json['due_date']),
        active: json['active'] as bool? ?? true,
        nextDue: asDate(json['next_due']),
        daysOverdue: json['days_overdue'] as int? ?? 0,
        status: json['status'] as String? ?? 'upcoming',
      );

  bool get isOverdue => status == 'overdue';

  /// One-off tasks have a fixed due date and don't repeat.
  bool get isOneOff => dueDate != null;

  /// Human-friendly urgency label for the dashboard.
  String get dueLabel {
    if (status == 'due_today') return 'Due today';
    if (daysOverdue > 0) {
      return '$daysOverdue day${daysOverdue == 1 ? '' : 's'} overdue';
    }
    final inDays = -daysOverdue;
    return 'Due in $inDays day${inDays == 1 ? '' : 's'}';
  }
}
