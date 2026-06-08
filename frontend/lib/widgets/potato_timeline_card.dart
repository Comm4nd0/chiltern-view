import 'package:flutter/material.dart';
import 'package:intl/intl.dart';

import '../models/potato_planting.dart';

/// A planting rendered as a horizontal growth timeline with the current
/// stage highlighted and a progress bar towards estimated harvest.
class PotatoTimelineCard extends StatelessWidget {
  final PotatoPlanting planting;

  const PotatoTimelineCard({super.key, required this.planting});

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final dateFmt = DateFormat('d MMM');

    return Card(
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Expanded(
                  child: Text(planting.variety, style: theme.textTheme.titleMedium),
                ),
                Chip(
                  label: Text(planting.categoryDisplay),
                  visualDensity: VisualDensity.compact,
                  materialTapTargetSize: MaterialTapTargetSize.shrinkWrap,
                ),
              ],
            ),
            if (planting.bed.isNotEmpty)
              Text(planting.bed, style: theme.textTheme.bodySmall),
            const SizedBox(height: 12),
            _StageStrip(planting: planting),
            const SizedBox(height: 16),
            ClipRRect(
              borderRadius: BorderRadius.circular(6),
              child: LinearProgressIndicator(
                value: planting.progress,
                minHeight: 8,
              ),
            ),
            const SizedBox(height: 8),
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Text('Planted ${dateFmt.format(planting.plantedOn)}',
                    style: theme.textTheme.bodySmall),
                Text(
                  planting.isHarvested
                      ? 'Harvested'
                      : 'Harvest ~ ${dateFmt.format(planting.estimatedHarvest)}',
                  style: theme.textTheme.bodySmall,
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }
}

class _StageStrip extends StatelessWidget {
  final PotatoPlanting planting;
  const _StageStrip({required this.planting});

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final primary = theme.colorScheme.primary;
    final dateFmt = DateFormat('d MMM');

    return SingleChildScrollView(
      scrollDirection: Axis.horizontal,
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          for (final stage in planting.stages) ...[
            SizedBox(
              width: 88,
              child: Column(
                children: [
                  Icon(
                    stage.label == planting.currentStage
                        ? Icons.radio_button_checked
                        : Icons.circle,
                    size: stage.label == planting.currentStage ? 18 : 12,
                    color: _reached(stage.label)
                        ? primary
                        : theme.colorScheme.outlineVariant,
                  ),
                  const SizedBox(height: 4),
                  Text(
                    stage.label,
                    textAlign: TextAlign.center,
                    style: theme.textTheme.labelSmall?.copyWith(
                      fontWeight: stage.label == planting.currentStage
                          ? FontWeight.bold
                          : FontWeight.normal,
                    ),
                  ),
                  Text(dateFmt.format(stage.date), style: theme.textTheme.bodySmall),
                ],
              ),
            ),
          ],
        ],
      ),
    );
  }

  /// A stage counts as "reached" up to and including the current stage.
  bool _reached(String label) {
    final labels = planting.stages.map((s) => s.label).toList();
    final currentIndex = labels.indexOf(planting.currentStage);
    final stageIndex = labels.indexOf(label);
    if (planting.isHarvested) return true;
    return currentIndex >= 0 && stageIndex <= currentIndex;
  }
}
