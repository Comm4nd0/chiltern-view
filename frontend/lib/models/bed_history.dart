import '../util/json.dart';

/// A bed's planting history, used to warn about poor crop rotation: growing the
/// same botanical [family] in a bed two seasons running.
class BedHistory {
  final String bed;
  final String lastCrop;
  final String? lastFamily;
  final String? lastFamilyLabel;
  final DateTime lastPlantedOn;
  final bool growing;

  /// Family codes grown in this bed within roughly the last year.
  final List<String> recentFamilies;

  BedHistory({
    required this.bed,
    required this.lastCrop,
    required this.lastFamily,
    required this.lastFamilyLabel,
    required this.lastPlantedOn,
    required this.growing,
    required this.recentFamilies,
  });

  factory BedHistory.fromJson(Map<String, dynamic> json) => BedHistory(
        bed: json['bed'] as String? ?? '',
        lastCrop: json['last_crop'] as String? ?? '',
        lastFamily: json['last_family'] as String?,
        lastFamilyLabel: json['last_family_label'] as String?,
        lastPlantedOn: asDate(json['last_planted_on']),
        growing: json['growing'] as bool? ?? false,
        recentFamilies:
            (json['recent_families'] as List<dynamic>? ?? []).map((e) => e as String).toList(),
      );
}
