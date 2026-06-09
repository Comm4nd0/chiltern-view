import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import 'package:phosphor_flutter/phosphor_flutter.dart';

import '../api/api_client.dart';
import '../models/overview.dart';
import '../services/notification_service.dart';
import '../theme.dart';
import '../widgets/async_view.dart';
import '../widgets/care_task_card.dart'; // AssigneeAvatar
import 'animal_detail_screen.dart';
import 'egg_log_screen.dart';

// Per-section accent colours (iOS-style varied tints).
const _teal = Color(0xFF00796B);
const _green = Color(0xFF34C759);
const _orange = Color(0xFFFF9500);
const _blue = Color(0xFF007AFF);
const _purple = Color(0xFFAF52DE);

/// A rounded, tinted square holding an icon — the iOS Settings-row motif.
class _IconTile extends StatelessWidget {
  final IconData icon;
  final Color color;
  const _IconTile(this.icon, this.color);

  @override
  Widget build(BuildContext context) {
    return Container(
      width: 38,
      height: 38,
      decoration: BoxDecoration(
        color: color.withValues(alpha: 0.12),
        borderRadius: BorderRadius.circular(10),
      ),
      child: Icon(icon, color: color, size: 22),
    );
  }
}

/// Home / front page: an at-a-glance overview of the whole holding.
class OverviewScreen extends StatefulWidget {
  final void Function(int index) onOpenTab;
  const OverviewScreen({super.key, required this.onOpenTab});

  @override
  State<OverviewScreen> createState() => _OverviewScreenState();
}

class _OverviewScreenState extends State<OverviewScreen> {
  final ApiClient _api = ApiClient();
  late Future<Overview> _future;
  int? _completingId;

  @override
  void initState() {
    super.initState();
    _future = _api.overview();
  }

  void _refresh() => setState(() => _future = _api.overview());

  Future<void> _complete(int id) async {
    setState(() => _completingId = id);
    try {
      await _api.completeTask(id);
      _refresh();
      syncReminders(_api);
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text('Failed: $e')));
      }
    } finally {
      if (mounted) setState(() => _completingId = null);
    }
  }

  @override
  Widget build(BuildContext context) {
    return RefreshIndicator(
      onRefresh: () async => _refresh(),
      child: AsyncView<Overview>(
        future: _future,
        onRetry: _refresh,
        builder: (context, o) => ListView(
          physics: const AlwaysScrollableScrollPhysics(),
          padding: const EdgeInsets.symmetric(vertical: 8),
          children: [
            _needsDoing(context, o),
            _crops(context, o),
            _eggs(context, o),
            _animals(context, o),
            if (o.activity.isNotEmpty) _recentNotes(context, o),
          ],
        ),
      ),
    );
  }

  Widget _needsDoing(BuildContext context, Overview o) {
    return Card(
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                _IconTile(PhosphorIcons.listChecks(PhosphorIconsStyle.fill), _teal),
                const SizedBox(width: 12),
                Text('Needs doing', style: Theme.of(context).textTheme.titleLarge),
                const Spacer(),
                TextButton(onPressed: () => widget.onOpenTab(1), child: const Text('All tasks')),
              ],
            ),
            const SizedBox(height: 12),
            Row(
              children: [
                _pill(context, 'overdue', o.tasksOverdue, AppTheme.statusColor('overdue')),
                const SizedBox(width: 8),
                _pill(context, 'today', o.tasksDueToday, AppTheme.statusColor('due_today')),
                const SizedBox(width: 8),
                _pill(context, 'upcoming', o.tasksUpcoming, AppTheme.statusColor('upcoming')),
              ],
            ),
            const SizedBox(height: 4),
            if (o.topTasks.isEmpty)
              Padding(
                padding: const EdgeInsets.only(top: 8),
                child: Row(
                  children: [
                    Icon(PhosphorIcons.checkCircle(PhosphorIconsStyle.fill),
                        size: 20, color: _green),
                    const SizedBox(width: 8),
                    Text('All caught up.', style: Theme.of(context).textTheme.bodyMedium),
                  ],
                ),
              )
            else
              ...o.topTasks.map((t) => _topTask(context, t)),
          ],
        ),
      ),
    );
  }

  Widget _topTask(BuildContext context, OverviewTask t) {
    final color = AppTheme.statusColor(t.status);
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 6),
      child: Row(
        children: [
          Container(
            width: 8,
            height: 8,
            decoration: BoxDecoration(color: color, shape: BoxShape.circle),
          ),
          const SizedBox(width: 10),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(t.name,
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: const TextStyle(fontWeight: FontWeight.w500)),
                Text(t.dueLabel,
                    style: TextStyle(color: color, fontSize: 12, fontWeight: FontWeight.w600)),
              ],
            ),
          ),
          if (t.assigneeName != null) ...[
            AssigneeAvatar(name: t.assigneeName!, radius: 12),
            const SizedBox(width: 8),
          ],
          OutlinedButton(
            onPressed: _completingId == t.id ? null : () => _complete(t.id),
            child: const Text('Done'),
          ),
        ],
      ),
    );
  }

  Widget _pill(BuildContext context, String label, int value, Color color) {
    return Expanded(
      child: Container(
        padding: const EdgeInsets.symmetric(vertical: 12),
        decoration: BoxDecoration(
          color: color.withValues(alpha: 0.10),
          borderRadius: BorderRadius.circular(14),
        ),
        child: Column(
          children: [
            Text(
              '$value',
              style: TextStyle(color: color, fontWeight: FontWeight.w800, fontSize: 24),
            ),
            Text(label,
                style: Theme.of(context)
                    .textTheme
                    .bodySmall
                    ?.copyWith(fontWeight: FontWeight.w600)),
          ],
        ),
      ),
    );
  }

  Widget _crops(BuildContext context, Overview o) {
    final nh = o.nextHarvest;
    final String subtitle;
    if (o.cropsGrowing == 0) {
      subtitle = 'nothing growing';
    } else if (nh != null) {
      subtitle = 'next harvest ${nh.label} ~ ${DateFormat('d MMM').format(nh.date)}';
    } else {
      subtitle = 'growing';
    }
    return _section(context, PhosphorIcons.plant(PhosphorIconsStyle.fill), _green, 'Crops',
        '${o.cropsGrowing}', subtitle, () => widget.onOpenTab(2));
  }

  Widget _eggs(BuildContext context, Overview o) {
    return _section(context, PhosphorIcons.egg(PhosphorIconsStyle.fill), _orange, 'Eggs',
        '${o.eggsToday}', 'today · ${o.eggsThisWeek} this week', () => _openEggs(context));
  }

  void _openEggs(BuildContext context) {
    Navigator.of(context).push(MaterialPageRoute<void>(
      builder: (_) => Scaffold(
        appBar: AppBar(title: const Text('Eggs')),
        body: const EggLogScreen(),
      ),
    ));
  }

  Widget _animals(BuildContext context, Overview o) {
    return Card(
      child: InkWell(
        onTap: () => widget.onOpenTab(3),
        child: Padding(
          padding: const EdgeInsets.all(16),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                children: [
                  _IconTile(PhosphorIcons.pawPrint(PhosphorIconsStyle.fill), _blue),
                  const SizedBox(width: 12),
                  Expanded(
                    child: Text('Animals', style: Theme.of(context).textTheme.titleMedium),
                  ),
                  Text('${o.animalsTotal}', style: Theme.of(context).textTheme.titleLarge),
                  const SizedBox(width: 6),
                  Icon(PhosphorIcons.caretRight(PhosphorIconsStyle.bold),
                      size: 16, color: Colors.black26),
                ],
              ),
              if (o.bySpecies.isNotEmpty) ...[
                const SizedBox(height: 12),
                Wrap(
                  spacing: 8,
                  runSpacing: 8,
                  children: [
                    for (final e in o.bySpecies.entries)
                      Chip(
                        label: Text('${e.key}: ${e.value}'),
                        visualDensity: VisualDensity.compact,
                        materialTapTargetSize: MaterialTapTargetSize.shrinkWrap,
                      ),
                  ],
                ),
              ],
            ],
          ),
        ),
      ),
    );
  }

  /// The latest hand-written journal notes (task completions excluded).
  Widget _recentNotes(BuildContext context, Overview o) {
    final dateFmt = DateFormat('d MMM');
    return Card(
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                _IconTile(PhosphorIcons.notebook(PhosphorIconsStyle.fill), _purple),
                const SizedBox(width: 12),
                Text('Recent notes', style: Theme.of(context).textTheme.titleLarge),
              ],
            ),
            const SizedBox(height: 8),
            for (final entry in o.activity)
              InkWell(
                onTap: entry.animal == null
                    ? null
                    : () async {
                        await Navigator.of(context).push(MaterialPageRoute<void>(
                          builder: (_) => AnimalDetailScreen(animalId: entry.animal!),
                        ));
                        _refresh();
                      },
                child: Padding(
                  padding: const EdgeInsets.symmetric(vertical: 6),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(entry.note,
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                          style: Theme.of(context).textTheme.bodyMedium),
                      Text(
                        [
                          if (entry.animalName != null) entry.animalName!,
                          dateFmt.format(entry.occurredOn),
                          if (entry.createdByName != null) entry.createdByName!,
                        ].join(' · '),
                        style: Theme.of(context).textTheme.bodySmall,
                      ),
                    ],
                  ),
                ),
              ),
          ],
        ),
      ),
    );
  }

  Widget _section(BuildContext context, IconData icon, Color color, String title, String value,
      String subtitle, VoidCallback onTap) {
    return Card(
      child: InkWell(
        onTap: onTap,
        child: Padding(
          padding: const EdgeInsets.all(16),
          child: Row(
            children: [
              _IconTile(icon, color),
              const SizedBox(width: 12),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(title, style: Theme.of(context).textTheme.titleMedium),
                    const SizedBox(height: 2),
                    Text(subtitle,
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                        style: Theme.of(context).textTheme.bodySmall),
                  ],
                ),
              ),
              Text(value, style: Theme.of(context).textTheme.titleLarge),
              const SizedBox(width: 6),
              Icon(PhosphorIcons.caretRight(PhosphorIconsStyle.bold),
                  size: 16, color: Colors.black26),
            ],
          ),
        ),
      ),
    );
  }
}
