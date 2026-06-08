class EggSummary {
  final int today;
  final int thisWeek;
  final int thisMonth;
  final int total;

  EggSummary({
    required this.today,
    required this.thisWeek,
    required this.thisMonth,
    required this.total,
  });

  factory EggSummary.fromJson(Map<String, dynamic> json) => EggSummary(
        today: json['today'] as int? ?? 0,
        thisWeek: json['this_week'] as int? ?? 0,
        thisMonth: json['this_month'] as int? ?? 0,
        total: json['total'] as int? ?? 0,
      );
}
