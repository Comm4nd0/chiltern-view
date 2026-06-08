import '../util/json.dart';

class EggRecord {
  final int id;
  final DateTime date;
  final int count;
  final String source;
  final String notes;

  EggRecord({
    required this.id,
    required this.date,
    required this.count,
    required this.source,
    required this.notes,
  });

  factory EggRecord.fromJson(Map<String, dynamic> json) => EggRecord(
        id: json['id'] as int,
        date: asDate(json['date']),
        count: json['count'] as int? ?? 0,
        source: json['source'] as String? ?? '',
        notes: json['notes'] as String? ?? '',
      );
}
