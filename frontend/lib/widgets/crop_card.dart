import 'package:flutter/material.dart';
import 'package:intl/intl.dart';

import '../models/crop.dart';

/// A crop rendered as a horizontal growth timeline with the current stage
/// highlighted and a progress bar towards estimated harvest.
class CropCard extends StatelessWidget {
  final Crop crop;

  const CropCard({super.key, required this.crop});

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
                  child: Text(crop.cropLabel, style: theme.textTheme.titleMedium),
                ),
                if (crop.variety.isNotEmpty)
                  Chip(
                    label: Text(crop.variety),
                    visualDensity: VisualDensity.compact,
                    materialTapTargetSize: MaterialTapTargetSize.shrinkWrap,
                  ),
              ],
            ),
            if (crop.bed.isNotEmpty) Text(crop.bed, style: theme.textTheme.bodySmall),
            const SizedBox(height: 12),
            _StageStrip(crop: crop),
            const SizedBox(height: 16),
            ClipRRect(
              borderRadius: BorderRadius.circular(6),
              child: LinearProgressIndicator(value: crop.progress, minHeight: 8),
            ),
            const SizedBox(height: 8),
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Text('Planted ${dateFmt.format(crop.plantedOn)}',
                    style: theme.textTheme.bodySmall),
                Text(
                  crop.isHarvested
                      ? 'Harvested'
                      : 'Harvest ~ ${dateFmt.format(crop.estimatedHarvest)}',
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
  final Crop crop;
  const _StageStrip({required this.crop});

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
          for (final stage in crop.stages) ...[
            SizedBox(
              width: 88,
              child: Column(
                children: [
                  Icon(
                    stage.label == crop.currentStage
                        ? Icons.radio_button_checked
                        : Icons.circle,
                    size: stage.label == crop.currentStage ? 18 : 12,
                    color: _reached(stage.label) ? primary : theme.colorScheme.outlineVariant,
                  ),
                  const SizedBox(height: 4),
                  Text(
                    stage.label,
                    textAlign: TextAlign.center,
                    style: theme.textTheme.labelSmall?.copyWith(
                      fontWeight:
                          stage.label == crop.currentStage ? FontWeight.bold : FontWeight.normal,
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

  bool _reached(String label) {
    final labels = crop.stages.map((s) => s.label).toList();
    final currentIndex = labels.indexOf(crop.currentStage);
    final stageIndex = labels.indexOf(label);
    if (crop.isHarvested) return true;
    return currentIndex >= 0 && stageIndex <= currentIndex;
  }
}
