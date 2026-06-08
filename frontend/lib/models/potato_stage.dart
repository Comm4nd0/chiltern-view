import '../util/json.dart';

class PotatoStage {
  final String label;
  final DateTime date;

  PotatoStage({required this.label, required this.date});

  factory PotatoStage.fromJson(Map<String, dynamic> json) => PotatoStage(
        label: json['label'] as String? ?? '',
        date: asDate(json['date']),
      );
}
