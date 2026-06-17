import '../util/json.dart';

class CropStage {
  final String label;
  final DateTime date;

  CropStage({required this.label, required this.date});

  factory CropStage.fromJson(Map<String, dynamic> json) => CropStage(
        label: json['label'] as String? ?? '',
        date: asDate(json['date']),
      );
}

class Crop {
  final int id;
  final String crop;
  final String cropLabel;
  final String? family;
  final String? familyLabel;
  final String variety;
  final DateTime plantedOn;
  final int? quantity;
  final String bed;
  final DateTime? expectedHarvest;
  final DateTime? harvestedOn;
  final double? yieldKg;
  final String notes;
  final DateTime estimatedHarvest;
  final String currentStage;
  final double progress;
  final List<CropStage> stages;

  Crop({
    required this.id,
    required this.crop,
    required this.cropLabel,
    this.family,
    this.familyLabel,
    required this.variety,
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

  factory Crop.fromJson(Map<String, dynamic> json) => Crop(
        id: json['id'] as int,
        crop: json['crop'] as String? ?? '',
        cropLabel: json['crop_label'] as String? ?? '',
        family: json['family'] as String?,
        familyLabel: json['family_label'] as String?,
        variety: json['variety'] as String? ?? '',
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
            .map((e) => CropStage.fromJson(e as Map<String, dynamic>))
            .toList(),
      );

  bool get isHarvested => harvestedOn != null;
}
