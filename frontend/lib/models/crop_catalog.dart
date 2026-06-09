class CropCatalogEntry {
  final String key;
  final String label;
  final int daysToHarvest;

  CropCatalogEntry({required this.key, required this.label, required this.daysToHarvest});

  factory CropCatalogEntry.fromJson(Map<String, dynamic> json) => CropCatalogEntry(
        key: json['key'] as String? ?? '',
        label: json['label'] as String? ?? '',
        daysToHarvest: json['days_to_harvest'] as int? ?? 0,
      );
}
