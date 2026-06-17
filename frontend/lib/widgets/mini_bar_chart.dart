import 'package:flutter/material.dart';

/// A lightweight bar chart drawn with a CustomPainter — no chart package,
/// mirroring the web MiniBarChart. Bars scale to the tallest value; the last
/// bar (today) is highlighted.
class MiniBarChart extends StatelessWidget {
  final List<int> values;
  final double height;

  const MiniBarChart({super.key, required this.values, this.height = 72});

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    return SizedBox(
      height: height,
      width: double.infinity,
      child: CustomPaint(
        painter: _BarChartPainter(
          values: values,
          color: scheme.primary,
          mutedColor: scheme.primary.withValues(alpha: 0.35),
        ),
      ),
    );
  }
}

class _BarChartPainter extends CustomPainter {
  final List<int> values;
  final Color color;
  final Color mutedColor;

  _BarChartPainter({required this.values, required this.color, required this.mutedColor});

  @override
  void paint(Canvas canvas, Size size) {
    if (values.isEmpty) return;
    final maxValue = values.fold<int>(1, (m, v) => v > m ? v : m);
    final gap = values.length > 1 ? 1.5 : 0.0;
    final barWidth = (size.width - gap * (values.length - 1)) / values.length;
    for (var i = 0; i < values.length; i++) {
      final value = values[i];
      final barHeight = (value / maxValue) * (size.height - 2);
      final isLast = i == values.length - 1;
      final paint = Paint()..color = isLast ? color : mutedColor;
      final left = i * (barWidth + gap);
      final top = size.height - (value > 0 ? barHeight.clamp(1.0, size.height) : 0.6);
      final rect = RRect.fromRectAndRadius(
        Rect.fromLTWH(left, top, barWidth, size.height - top),
        const Radius.circular(1),
      );
      canvas.drawRRect(rect, paint);
    }
  }

  @override
  bool shouldRepaint(_BarChartPainter old) =>
      old.values != values || old.color != color || old.mutedColor != mutedColor;
}
