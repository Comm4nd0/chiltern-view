import '../util/json.dart';

class OverviewTask {
  final int id;
  final String name;
  final String? assigneeName;
  final int daysOverdue;
  final String status;

  OverviewTask({
    required this.id,
    required this.name,
    required this.assigneeName,
    required this.daysOverdue,
    required this.status,
  });

  factory OverviewTask.fromJson(Map<String, dynamic> json) => OverviewTask(
        id: json['id'] as int,
        name: json['name'] as String? ?? '',
        assigneeName: json['assignee_name'] as String?,
        daysOverdue: json['days_overdue'] as int? ?? 0,
        status: json['status'] as String? ?? 'upcoming',
      );

  String get dueLabel {
    if (status == 'due_today') return 'due today';
    if (daysOverdue > 0) return '${daysOverdue}d overdue';
    return 'due in ${-daysOverdue}d';
  }
}

class NextHarvest {
  final String label;
  final DateTime date;

  NextHarvest({required this.label, required this.date});

  factory NextHarvest.fromJson(Map<String, dynamic> json) => NextHarvest(
        label: json['label'] as String? ?? '',
        date: asDate(json['date']),
      );
}

/// A recent journal note surfaced on the home screen.
class OverviewActivityEntry {
  final int id;
  final String entryType;
  final String entryTypeDisplay;
  final String note;
  final int? animal;
  final String? animalName;
  final DateTime occurredOn;
  final String? createdByName;

  OverviewActivityEntry({
    required this.id,
    required this.entryType,
    required this.entryTypeDisplay,
    required this.note,
    required this.animal,
    required this.animalName,
    required this.occurredOn,
    required this.createdByName,
  });

  factory OverviewActivityEntry.fromJson(Map<String, dynamic> json) => OverviewActivityEntry(
        id: json['id'] as int,
        entryType: json['entry_type'] as String? ?? 'general',
        entryTypeDisplay: json['entry_type_display'] as String? ?? '',
        note: json['note'] as String? ?? '',
        animal: json['animal'] as int?,
        animalName: json['animal_name'] as String?,
        occurredOn: asDate(json['occurred_on']),
        createdByName: json['created_by_name'] as String?,
      );
}

class Overview {
  final int tasksOverdue;
  final int tasksDueToday;
  final int tasksUpcoming;
  final Map<String, int> perPerson;
  final List<OverviewTask> topTasks;
  final int animalsTotal;
  final Map<String, int> bySpecies;
  final int cropsGrowing;
  final NextHarvest? nextHarvest;
  final int eggsToday;
  final int eggsThisWeek;
  final List<OverviewActivityEntry> activity;

  Overview({
    required this.tasksOverdue,
    required this.tasksDueToday,
    required this.tasksUpcoming,
    required this.perPerson,
    required this.topTasks,
    required this.animalsTotal,
    required this.bySpecies,
    required this.cropsGrowing,
    required this.nextHarvest,
    required this.eggsToday,
    required this.eggsThisWeek,
    required this.activity,
  });

  factory Overview.fromJson(Map<String, dynamic> json) {
    final tasks = json['tasks'] as Map<String, dynamic>? ?? {};
    final animals = json['animals'] as Map<String, dynamic>? ?? {};
    final crops = json['crops'] as Map<String, dynamic>? ?? {};
    final eggs = json['eggs'] as Map<String, dynamic>? ?? {};
    final nh = crops['next_harvest'] as Map<String, dynamic>?;
    return Overview(
      tasksOverdue: tasks['overdue'] as int? ?? 0,
      tasksDueToday: tasks['due_today'] as int? ?? 0,
      tasksUpcoming: tasks['upcoming'] as int? ?? 0,
      perPerson: (tasks['per_person'] as Map<String, dynamic>? ?? {})
          .map((k, v) => MapEntry(k, v as int)),
      topTasks: (tasks['top'] as List<dynamic>? ?? [])
          .map((e) => OverviewTask.fromJson(e as Map<String, dynamic>))
          .toList(),
      animalsTotal: animals['total'] as int? ?? 0,
      bySpecies: (animals['by_species'] as Map<String, dynamic>? ?? {})
          .map((k, v) => MapEntry(k, v as int)),
      cropsGrowing: crops['growing'] as int? ?? 0,
      nextHarvest: nh == null ? null : NextHarvest.fromJson(nh),
      eggsToday: eggs['today'] as int? ?? 0,
      eggsThisWeek: eggs['this_week'] as int? ?? 0,
      activity: (json['activity'] as List<dynamic>? ?? [])
          .map((e) => OverviewActivityEntry.fromJson(e as Map<String, dynamic>))
          .toList(),
    );
  }
}
