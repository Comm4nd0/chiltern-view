import '../util/json.dart';

class EggTrendPoint {
  final DateTime date;
  final int count;

  EggTrendPoint({required this.date, required this.count});

  factory EggTrendPoint.fromJson(Map<String, dynamic> json) => EggTrendPoint(
        date: asDate(json['date']),
        count: json['count'] as int? ?? 0,
      );
}

/// Daily egg totals over a window (zero-filled by the API) plus simple stats,
/// for the laying-trend chart.
class EggTrend {
  final List<EggTrendPoint> days;
  final int total;
  final double average;
  final EggTrendPoint? bestDay;

  EggTrend({
    required this.days,
    required this.total,
    required this.average,
    required this.bestDay,
  });

  factory EggTrend.fromJson(Map<String, dynamic> json) => EggTrend(
        days: (json['days'] as List<dynamic>? ?? [])
            .map((e) => EggTrendPoint.fromJson(e as Map<String, dynamic>))
            .toList(),
        total: json['total'] as int? ?? 0,
        average: asDouble(json['average']),
        bestDay: json['best_day'] == null
            ? null
            : EggTrendPoint.fromJson(json['best_day'] as Map<String, dynamic>),
      );
}
