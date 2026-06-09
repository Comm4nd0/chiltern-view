import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import 'package:phosphor_flutter/phosphor_flutter.dart';

import '../models/care_task.dart';
import '../theme.dart';

/// Small circular avatar showing a person's initials, coloured deterministically.
class AssigneeAvatar extends StatelessWidget {
  final String name;
  final double radius;
  const AssigneeAvatar({super.key, required this.name, this.radius = 13});

  static const List<Color> _palette = [
    Color(0xFF00796B),
    Color(0xFF3949AB),
    Color(0xFFD84315),
    Color(0xFF6A1B9A),
    Color(0xFF5D4037),
    Color(0xFF455A64),
  ];

  @override
  Widget build(BuildContext context) {
    final parts = name.trim().split(RegExp(r'\s+')).where((s) => s.isNotEmpty).toList();
    final initials = parts.take(2).map((s) => s[0].toUpperCase()).join();
    final color = _palette[name.hashCode.abs() % _palette.length];
    return Tooltip(
      message: name,
      child: CircleAvatar(
        radius: radius,
        backgroundColor: color,
        child: Text(
          initials,
          style: TextStyle(
            fontSize: radius * 0.85,
            color: Colors.white,
            fontWeight: FontWeight.bold,
          ),
        ),
      ),
    );
  }
}

class CareTaskCard extends StatelessWidget {
  final CareTask task;
  final Future<void> Function() onComplete;

  const CareTaskCard({super.key, required this.task, required this.onComplete});

  @override
  Widget build(BuildContext context) {
    final color = AppTheme.statusColor(task.status);
    final subtitle = <String>[
      if (task.animalName != null) task.animalName!,
      'every ${task.recurrenceIntervalDays} days',
    ].join(' · ');

    return Card(
      child: IntrinsicHeight(
        child: Row(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Container(width: 6, color: color),
            Expanded(
              child: Padding(
                padding: const EdgeInsets.fromLTRB(14, 12, 12, 12),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Row(
                      children: [
                        Expanded(
                          child: Text(task.name, style: Theme.of(context).textTheme.titleMedium),
                        ),
                        if (task.assigneeName != null) ...[
                          const SizedBox(width: 8),
                          AssigneeAvatar(name: task.assigneeName!),
                        ],
                      ],
                    ),
                    const SizedBox(height: 2),
                    Text(subtitle, style: Theme.of(context).textTheme.bodySmall),
                    const SizedBox(height: 8),
                    Row(
                      children: [
                        Icon(PhosphorIcons.clock(PhosphorIconsStyle.fill), size: 16, color: color),
                        const SizedBox(width: 4),
                        Text(
                          task.dueLabel,
                          style: TextStyle(color: color, fontWeight: FontWeight.w600),
                        ),
                        const Spacer(),
                        Text(
                          DateFormat('d MMM').format(task.nextDue),
                          style: Theme.of(context).textTheme.bodySmall,
                        ),
                      ],
                    ),
                  ],
                ),
              ),
            ),
            Padding(
              padding: const EdgeInsets.only(right: 8),
              child: Center(
                child: FilledButton.tonalIcon(
                  onPressed: onComplete,
                  icon: Icon(PhosphorIcons.check(PhosphorIconsStyle.bold), size: 16),
                  label: const Text('Done'),
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}
