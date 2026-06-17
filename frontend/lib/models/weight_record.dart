import '../util/json.dart';

/// A dated weight reading for an animal.
class WeightRecord {
  final int id;
  final int animal;
  final DateTime date;
  final double weightKg;
  final String note;

  WeightRecord({
    required this.id,
    required this.animal,
    required this.date,
    required this.weightKg,
    required this.note,
  });

  factory WeightRecord.fromJson(Map<String, dynamic> json) => WeightRecord(
        id: json['id'] as int,
        animal: json['animal'] as int,
        date: asDate(json['date']),
        weightKg: asDouble(json['weight_kg']),
        note: json['note'] as String? ?? '',
      );
}
