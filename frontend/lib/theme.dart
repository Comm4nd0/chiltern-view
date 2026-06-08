import 'package:flutter/material.dart';

class AppTheme {
  static const Color _seed = Color(0xFF4F772D); // smallholding green

  static ThemeData light() {
    final scheme = ColorScheme.fromSeed(seedColor: _seed);
    return ThemeData(
      useMaterial3: true,
      colorScheme: scheme,
      scaffoldBackgroundColor: scheme.surface,
      cardTheme: CardThemeData(
        elevation: 0,
        margin: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
        clipBehavior: Clip.antiAlias,
      ),
    );
  }

  /// Colour used to flag a care task's urgency.
  static Color statusColor(String status) {
    switch (status) {
      case 'overdue':
        return const Color(0xFFC0392B); // red
      case 'due_today':
        return const Color(0xFFE67E22); // amber
      default:
        return const Color(0xFF4F772D); // green
    }
  }
}
