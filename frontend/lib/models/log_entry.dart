import '../util/json.dart';

/// A dated journal note, optionally tied to an animal or task.
class LogEntry {
  final int id;
  final String entryType;
  final String entryTypeDisplay;
  final String note;
  final String medicine;
  final int? withdrawalDays;
  final DateTime? withdrawalUntil;
  final bool withdrawalActive;
  final int? animal;
  final String? animalName;
  final int? careTask;
  final String? careTaskName;
  final int? createdBy;
  final String? createdByName;
  final DateTime occurredOn;

  LogEntry({
    required this.id,
    required this.entryType,
    required this.entryTypeDisplay,
    required this.note,
    this.medicine = '',
    this.withdrawalDays,
    this.withdrawalUntil,
    this.withdrawalActive = false,
    required this.animal,
    required this.animalName,
    required this.careTask,
    required this.careTaskName,
    required this.createdBy,
    required this.createdByName,
    required this.occurredOn,
  });

  factory LogEntry.fromJson(Map<String, dynamic> json) => LogEntry(
        id: json['id'] as int,
        entryType: json['entry_type'] as String? ?? 'general',
        entryTypeDisplay: json['entry_type_display'] as String? ?? '',
        note: json['note'] as String? ?? '',
        medicine: json['medicine'] as String? ?? '',
        withdrawalDays: json['withdrawal_days'] as int?,
        withdrawalUntil: asNullableDate(json['withdrawal_until']),
        withdrawalActive: json['withdrawal_active'] as bool? ?? false,
        animal: json['animal'] as int?,
        animalName: json['animal_name'] as String?,
        careTask: json['care_task'] as int?,
        careTaskName: json['care_task_name'] as String?,
        createdBy: json['created_by'] as int?,
        createdByName: json['created_by_name'] as String?,
        occurredOn: asDate(json['occurred_on']),
      );

  /// System entries (task completions) are shown but not editable.
  bool get isSystem => entryType == 'task_completed';
}

/// One page of a DRF-paginated journal list.
class PagedLogEntries {
  final List<LogEntry> entries;
  final bool hasMore;

  PagedLogEntries({required this.entries, required this.hasMore});
}
