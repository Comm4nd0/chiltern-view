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
  final String variety;
  final DateTime date;

  NextHarvest({required this.variety, required this.date});

  factory NextHarvest.fromJson(Map<String, dynamic> json) => NextHarvest(
        variety: json['variety'] as String? ?? '',
        date: asDate(json['date']),
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
  final int potatoesGrowing;
  final NextHarvest? nextHarvest;
  final int eggsToday;
  final int eggsThisWeek;

  Overview({
    required this.tasksOverdue,
    required this.tasksDueToday,
    required this.tasksUpcoming,
    required this.perPerson,
    required this.topTasks,
    required this.animalsTotal,
    required this.bySpecies,
    required this.potatoesGrowing,
    required this.nextHarvest,
    required this.eggsToday,
    required this.eggsThisWeek,
  });

  factory Overview.fromJson(Map<String, dynamic> json) {
    final tasks = json['tasks'] as Map<String, dynamic>? ?? {};
    final animals = json['animals'] as Map<String, dynamic>? ?? {};
    final potatoes = json['potatoes'] as Map<String, dynamic>? ?? {};
    final eggs = json['eggs'] as Map<String, dynamic>? ?? {};
    final nh = potatoes['next_harvest'] as Map<String, dynamic>?;
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
      potatoesGrowing: potatoes['growing'] as int? ?? 0,
      nextHarvest: nh == null ? null : NextHarvest.fromJson(nh),
      eggsToday: eggs['today'] as int? ?? 0,
      eggsThisWeek: eggs['this_week'] as int? ?? 0,
    );
  }
}
