import '../util/json.dart';

class OverviewTask {
  final int id;
  final String name;
  final String? assigneeName;
  final int daysOverdue;
  final String status;
  final bool rainDeferred;
  final String? weatherNote;

  OverviewTask({
    required this.id,
    required this.name,
    required this.assigneeName,
    required this.daysOverdue,
    required this.status,
    this.rainDeferred = false,
    this.weatherNote,
  });

  factory OverviewTask.fromJson(Map<String, dynamic> json) => OverviewTask(
        id: json['id'] as int,
        name: json['name'] as String? ?? '',
        assigneeName: json['assignee_name'] as String?,
        daysOverdue: json['days_overdue'] as int? ?? 0,
        status: json['status'] as String? ?? 'upcoming',
        rainDeferred: json['rain_deferred'] as bool? ?? false,
        weatherNote: json['weather_note'] as String?,
      );

  String get dueLabel {
    if (status == 'due_today') return 'due today';
    if (daysOverdue > 0) return '${daysOverdue}d overdue';
    return 'due in ${-daysOverdue}d';
  }
}

class WeatherDay {
  final DateTime date;
  final double? tmin;
  final double? tmax;
  final double precipMm;
  final double? precipProb;
  final bool frost;

  WeatherDay({
    required this.date,
    required this.tmin,
    required this.tmax,
    required this.precipMm,
    required this.precipProb,
    required this.frost,
  });

  factory WeatherDay.fromJson(Map<String, dynamic> json) => WeatherDay(
        date: asDate(json['date']),
        tmin: asNullableDouble(json['tmin']),
        tmax: asNullableDouble(json['tmax']),
        precipMm: asDouble(json['precip_mm']),
        precipProb: asNullableDouble(json['precip_prob']),
        frost: json['frost'] as bool? ?? false,
      );
}

class FrostWarning {
  final List<String> crops;
  final String message;

  FrostWarning({required this.crops, required this.message});

  factory FrostWarning.fromJson(Map<String, dynamic> json) => FrostWarning(
        crops: (json['crops'] as List<dynamic>? ?? []).map((e) => '$e').toList(),
        message: json['message'] as String? ?? '',
      );
}

class Weather {
  final String location;
  final double recentRainMm;
  final WeatherDay? today;
  final List<WeatherDay> days;
  final bool stale;
  final FrostWarning? frostWarning;

  Weather({
    required this.location,
    required this.recentRainMm,
    required this.today,
    required this.days,
    required this.stale,
    required this.frostWarning,
  });

  factory Weather.fromJson(Map<String, dynamic> json) {
    final today = json['today'] as Map<String, dynamic>?;
    final frost = json['frost_warning'] as Map<String, dynamic>?;
    return Weather(
      location: json['location'] as String? ?? '',
      recentRainMm: asDouble(json['recent_rain_mm']),
      today: today == null ? null : WeatherDay.fromJson(today),
      days: (json['days'] as List<dynamic>? ?? [])
          .map((e) => WeatherDay.fromJson(e as Map<String, dynamic>))
          .toList(),
      stale: json['stale'] as bool? ?? false,
      frostWarning: frost == null ? null : FrostWarning.fromJson(frost),
    );
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
  final Weather? weather;

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
    this.weather,
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
      weather: json['weather'] == null
          ? null
          : Weather.fromJson(json['weather'] as Map<String, dynamic>),
    );
  }
}
