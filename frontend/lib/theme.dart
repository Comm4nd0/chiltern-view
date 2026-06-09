import 'package:flutter/material.dart';

/// An Apple-flavoured Material theme: the iOS system font, a "grouped" grey
/// background with flat white rounded cards, hairline dividers and pill buttons.
/// Teal (#00796B, Marco & Claire's favourite) stays the accent. Kept in sync
/// with the web app's theme.ts so the two clients feel like one product.
class AppTheme {
  static const Color _teal = Color(0xFF00796B);
  static const Color _label = Color(0xFF1C1C1E); // iOS label
  static const Color _secondaryLabel = Color(0xFF6E6E73); // iOS secondary label
  static const Color _groupedBg = Color(0xFFF2F2F7); // iOS grouped background
  static const Color _separator = Color(0x293C3C43); // rgba(60,60,67,0.16)

  // The iOS system font. On Apple devices these resolve to San Francisco; on
  // other platforms Flutter falls back to the default sans, which is fine.
  static const String _font = '.SF Pro Text';
  static const List<String> _fontFallback = ['.SF Pro Display', 'SF Pro Text'];

  static ThemeData light() {
    final scheme = ColorScheme.fromSeed(seedColor: _teal).copyWith(
      primary: _teal,
      surface: Colors.white,
      onSurface: _label,
      onSurfaceVariant: _secondaryLabel,
      outlineVariant: _separator,
      error: const Color(0xFFFF3B30),
    );

    final base = ThemeData(
      useMaterial3: true,
      colorScheme: scheme,
      fontFamily: _font,
      fontFamilyFallback: _fontFallback,
    );
    final text = base.textTheme
        .apply(fontFamily: _font, bodyColor: _label, displayColor: _label)
        .copyWith(
          headlineSmall: const TextStyle(fontWeight: FontWeight.w800, letterSpacing: -0.5),
          titleLarge: const TextStyle(fontWeight: FontWeight.w700, letterSpacing: -0.3),
          titleMedium: const TextStyle(fontWeight: FontWeight.w600, letterSpacing: -0.2),
        );

    return base.copyWith(
      scaffoldBackgroundColor: _groupedBg,
      textTheme: text,
      cardTheme: CardThemeData(
        elevation: 0,
        color: Colors.white,
        surfaceTintColor: Colors.transparent,
        margin: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
        clipBehavior: Clip.antiAlias,
      ),
      appBarTheme: const AppBarTheme(
        backgroundColor: _groupedBg,
        surfaceTintColor: Colors.transparent,
        foregroundColor: _label,
        elevation: 0,
        scrolledUnderElevation: 0,
        centerTitle: false,
        titleTextStyle: TextStyle(
          fontFamily: _font,
          color: _label,
          fontSize: 22,
          fontWeight: FontWeight.w800,
          letterSpacing: -0.4,
        ),
      ),
      navigationBarTheme: NavigationBarThemeData(
        backgroundColor: Colors.white,
        surfaceTintColor: Colors.transparent,
        indicatorColor: Colors.transparent,
        elevation: 0,
        height: 64,
        labelBehavior: NavigationDestinationLabelBehavior.alwaysShow,
        labelTextStyle: WidgetStateProperty.resolveWith((states) {
          final selected = states.contains(WidgetState.selected);
          return TextStyle(
            fontFamily: _font,
            fontSize: 11,
            fontWeight: FontWeight.w600,
            color: selected ? _teal : _secondaryLabel,
          );
        }),
        iconTheme: WidgetStateProperty.resolveWith((states) {
          final selected = states.contains(WidgetState.selected);
          return IconThemeData(size: 26, color: selected ? _teal : _secondaryLabel);
        }),
      ),
      filledButtonTheme: FilledButtonThemeData(
        style: FilledButton.styleFrom(
          shape: const StadiumBorder(),
          elevation: 0,
          padding: const EdgeInsets.symmetric(horizontal: 18, vertical: 10),
          textStyle: const TextStyle(fontFamily: _font, fontWeight: FontWeight.w600),
        ),
      ),
      outlinedButtonTheme: OutlinedButtonThemeData(
        style: OutlinedButton.styleFrom(
          shape: const StadiumBorder(),
          side: const BorderSide(color: _separator),
          padding: const EdgeInsets.symmetric(horizontal: 18, vertical: 10),
          textStyle: const TextStyle(fontFamily: _font, fontWeight: FontWeight.w600),
        ),
      ),
      textButtonTheme: TextButtonThemeData(
        style: TextButton.styleFrom(
          textStyle: const TextStyle(fontFamily: _font, fontWeight: FontWeight.w600),
        ),
      ),
      chipTheme: const ChipThemeData(
        backgroundColor: Color(0x1F787880),
        side: BorderSide.none,
        shape: StadiumBorder(),
        labelStyle: TextStyle(fontFamily: _font, fontWeight: FontWeight.w600, fontSize: 13),
      ),
      inputDecorationTheme: InputDecorationTheme(
        filled: true,
        fillColor: Colors.white,
        border: OutlineInputBorder(
          borderRadius: BorderRadius.circular(12),
          borderSide: const BorderSide(color: _separator),
        ),
        enabledBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(12),
          borderSide: const BorderSide(color: _separator),
        ),
      ),
      dividerTheme: const DividerThemeData(color: _separator, thickness: 0.5, space: 1),
      dialogTheme: DialogThemeData(
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
      ),
      bottomSheetTheme: const BottomSheetThemeData(
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
        ),
      ),
    );
  }

  /// Colour used to flag a care task's urgency (matches the web app).
  static Color statusColor(String status) {
    switch (status) {
      case 'overdue':
        return const Color(0xFFFF3B30); // iOS red
      case 'due_today':
        return const Color(0xFFFF9500); // iOS orange
      default:
        return _teal;
    }
  }
}
