import '../util/json.dart';
import 'potato_stage.dart';

class PotatoPlanting {
  final int id;
  final String variety;
  final String category;
  final String categoryDisplay;
  final DateTime plantedOn;
  final int? quantity;
  final String bed;
  final DateTime? expectedHarvest;
  final DateTime? harvestedOn;
  final double? yieldKg;
  final String notes;
  final DateTime estimatedHarvest;
  final String currentStage;
  final double progress; // 0.0 .. 1.0
  final List<PotatoStage> stages;

  PotatoPlanting({
    required this.id,
    required this.variety,
    required this.category,
    required this.categoryDisplay,
    required this.plantedOn,
    required this.quantity,
    required this.bed,
    required this.expectedHarvest,
    required this.harvestedOn,
    required this.yieldKg,
    required this.notes,
    required this.estimatedHarvest,
    required this.currentStage,
    required this.progress,
    required this.stages,
  });

  factory PotatoPlanting.fromJson(Map<String, dynamic> json) => PotatoPlanting(
        id: json['id'] as int,
        variety: json['variety'] as String? ?? '',
        category: json['category'] as String? ?? '',
        categoryDisplay: json['category_display'] as String? ?? '',
        plantedOn: asDate(json['planted_on']),
        quantity: json['quantity'] as int?,
        bed: json['bed'] as String? ?? '',
        expectedHarvest: asNullableDate(json['expected_harvest']),
        harvestedOn: asNullableDate(json['harvested_on']),
        yieldKg: asNullableDouble(json['yield_kg']),
        notes: json['notes'] as String? ?? '',
        estimatedHarvest: asDate(json['estimated_harvest']),
        currentStage: json['current_stage'] as String? ?? '',
        progress: asDouble(json['progress']),
        stages: (json['stages'] as List<dynamic>? ?? [])
            .map((e) => PotatoStage.fromJson(e as Map<String, dynamic>))
            .toList(),
      );

  bool get isHarvested => harvestedOn != null;
}
