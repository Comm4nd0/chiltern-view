import 'package:flutter/material.dart';
import 'package:intl/intl.dart';

import '../api/api_client.dart';
import '../models/overview.dart';
import '../services/notification_service.dart';
import '../theme.dart';
import '../widgets/async_view.dart';
import '../widgets/care_task_card.dart'; // AssigneeAvatar

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
          padding: const EdgeInsets.all(12),
          children: [
            _needsDoing(context, o),
            const SizedBox(height: 8),
            _potatoes(context, o),
            const SizedBox(height: 8),
            _eggs(context, o),
            const SizedBox(height: 8),
            _animals(context, o),
          ],
        ),
      ),
    );
  }

  Widget _needsDoing(BuildContext context, Overview o) {
    final primary = Theme.of(context).colorScheme.primary;
    return Card(
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Icon(Icons.checklist, color: primary),
                const SizedBox(width: 8),
                Text('Needs doing', style: Theme.of(context).textTheme.titleLarge),
                const Spacer(),
                TextButton(onPressed: () => widget.onOpenTab(1), child: const Text('All tasks')),
              ],
            ),
            const SizedBox(height: 8),
            Row(
              children: [
                _pill(context, 'overdue', o.tasksOverdue, AppTheme.statusColor('overdue')),
                const SizedBox(width: 8),
                _pill(context, 'today', o.tasksDueToday, AppTheme.statusColor('due_today')),
                const SizedBox(width: 8),
                _pill(context, 'upcoming', o.tasksUpcoming, AppTheme.statusColor('upcoming')),
              ],
            ),
            const SizedBox(height: 8),
            if (o.topTasks.isEmpty)
              Text('All caught up.', style: Theme.of(context).textTheme.bodyMedium)
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
      padding: const EdgeInsets.symmetric(vertical: 4),
      child: Row(
        children: [
          Container(
            width: 8,
            height: 8,
            decoration: BoxDecoration(color: color, shape: BoxShape.circle),
          ),
          const SizedBox(width: 8),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(t.name, maxLines: 1, overflow: TextOverflow.ellipsis),
                Text(t.dueLabel, style: TextStyle(color: color, fontSize: 12)),
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
        padding: const EdgeInsets.symmetric(vertical: 10),
        decoration: BoxDecoration(
          color: color.withValues(alpha: 0.08),
          borderRadius: BorderRadius.circular(10),
        ),
        child: Column(
          children: [
            Text(
              '$value',
              style: TextStyle(color: color, fontWeight: FontWeight.bold, fontSize: 22),
            ),
            Text(label, style: Theme.of(context).textTheme.bodySmall),
          ],
        ),
      ),
    );
  }

  Widget _potatoes(BuildContext context, Overview o) {
    final nh = o.nextHarvest;
    final String subtitle;
    if (o.potatoesGrowing == 0) {
      subtitle = 'nothing growing';
    } else if (nh != null) {
      subtitle = 'growing · next harvest ${nh.variety} ~ ${DateFormat('d MMM').format(nh.date)}';
    } else {
      subtitle = 'growing';
    }
    return _section(context, Icons.grass, 'Crops', '${o.potatoesGrowing}', subtitle,
        () => widget.onOpenTab(2));
  }

  Widget _eggs(BuildContext context, Overview o) {
    return _section(context, Icons.egg, 'Eggs', '${o.eggsToday}',
        'today · ${o.eggsThisWeek} this week', () => widget.onOpenTab(3));
  }

  Widget _animals(BuildContext context, Overview o) {
    final primary = Theme.of(context).colorScheme.primary;
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
                  Icon(Icons.pets, color: primary),
                  const SizedBox(width: 8),
                  Text('Animals', style: Theme.of(context).textTheme.titleLarge),
                  const Spacer(),
                  Text('${o.animalsTotal}', style: Theme.of(context).textTheme.titleLarge),
                ],
              ),
              const SizedBox(height: 8),
              if (o.bySpecies.isEmpty)
                Text('none yet', style: Theme.of(context).textTheme.bodyMedium)
              else
                Wrap(
                  spacing: 8,
                  runSpacing: 8,
                  children: [
                    for (final e in o.bySpecies.entries)
                      Chip(
                        label: Text('${e.key}: ${e.value}'),
                        visualDensity: VisualDensity.compact,
                      ),
                  ],
                ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _section(BuildContext context, IconData icon, String title, String value,
      String subtitle, VoidCallback onTap) {
    final primary = Theme.of(context).colorScheme.primary;
    return Card(
      child: InkWell(
        onTap: onTap,
        child: Padding(
          padding: const EdgeInsets.all(16),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                children: [
                  Icon(icon, color: primary),
                  const SizedBox(width: 8),
                  Text(title, style: Theme.of(context).textTheme.titleLarge),
                  const Spacer(),
                  Text(value, style: Theme.of(context).textTheme.titleLarge),
                ],
              ),
              const SizedBox(height: 4),
              Text(subtitle, style: Theme.of(context).textTheme.bodySmall),
            ],
          ),
        ),
      ),
    );
  }
}
