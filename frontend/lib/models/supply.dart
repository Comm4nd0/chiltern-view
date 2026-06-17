import '../util/json.dart';

/// A consumable kept on the holding (feed, hay, bedding, …) with a reorder
/// threshold so the dashboard can flag what's running low.
class Supply {
  final int id;
  final String name;
  final String unit;
  final double quantity;
  final double reorderAt;
  final bool isLow;
  final String notes;
  final bool active;

  Supply({
    required this.id,
    required this.name,
    required this.unit,
    required this.quantity,
    required this.reorderAt,
    required this.isLow,
    required this.notes,
    required this.active,
  });

  factory Supply.fromJson(Map<String, dynamic> json) => Supply(
        id: json['id'] as int,
        name: json['name'] as String? ?? '',
        unit: json['unit'] as String? ?? '',
        quantity: asDouble(json['quantity']),
        reorderAt: asDouble(json['reorder_at']),
        isLow: json['is_low'] as bool? ?? false,
        notes: json['notes'] as String? ?? '',
        active: json['active'] as bool? ?? true,
      );
}

/// A low supply surfaced on the home dashboard.
class SupplyLow {
  final int id;
  final String name;
  final double quantity;
  final String unit;

  SupplyLow({required this.id, required this.name, required this.quantity, required this.unit});

  factory SupplyLow.fromJson(Map<String, dynamic> json) => SupplyLow(
        id: json['id'] as int,
        name: json['name'] as String? ?? '',
        quantity: asDouble(json['quantity']),
        unit: json['unit'] as String? ?? '',
      );
}
