class CropCatalogEntry {
  final String key;
  final String label;
  final int daysToHarvest;

  /// Botanical family code (e.g. 'solanaceae'); null for an unknown crop.
  final String? family;
  final String? familyLabel;

  CropCatalogEntry({
    required this.key,
    required this.label,
    required this.daysToHarvest,
    this.family,
    this.familyLabel,
  });

  factory CropCatalogEntry.fromJson(Map<String, dynamic> json) => CropCatalogEntry(
        key: json['key'] as String? ?? '',
        label: json['label'] as String? ?? '',
        daysToHarvest: json['days_to_harvest'] as int? ?? 0,
        family: json['family'] as String?,
        familyLabel: json['family_label'] as String?,
      );
}
