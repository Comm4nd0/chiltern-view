// Small helpers for decoding JSON coming back from the DRF API.

DateTime asDate(dynamic value) => DateTime.parse(value as String);

DateTime? asNullableDate(dynamic value) =>
    value == null ? null : DateTime.parse(value as String);

double asDouble(dynamic value, [double fallback = 0]) {
  if (value == null) return fallback;
  if (value is num) return value.toDouble();
  return double.tryParse(value.toString()) ?? fallback;
}

double? asNullableDouble(dynamic value) {
  if (value == null) return null;
  if (value is num) return value.toDouble();
  return double.tryParse(value.toString());
}
