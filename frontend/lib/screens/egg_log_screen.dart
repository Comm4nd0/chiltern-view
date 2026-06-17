import 'package:flutter/material.dart';
import 'package:intl/intl.dart';

import '../api/api_client.dart';
import '../models/egg_record.dart';
import '../models/egg_summary.dart';
import '../models/egg_trend.dart';
import '../widgets/async_view.dart';
import '../widgets/mini_bar_chart.dart';

class EggLogScreen extends StatefulWidget {
  const EggLogScreen({super.key});

  @override
  State<EggLogScreen> createState() => _EggLogScreenState();
}

class _EggLogScreenState extends State<EggLogScreen> {
  final ApiClient _api = ApiClient();
  late Future<(EggSummary, EggTrend, List<EggRecord>)> _future;
  bool _busy = false;

  @override
  void initState() {
    super.initState();
    _future = _load();
  }

  Future<(EggSummary, EggTrend, List<EggRecord>)> _load() async {
    final results = await Future.wait([
      _api.eggSummary(),
      _api.eggTrend(days: 30),
      _api.recentEggs(),
    ]);
    return (
      results[0] as EggSummary,
      results[1] as EggTrend,
      results[2] as List<EggRecord>,
    );
  }

  void _refresh() => setState(() => _future = _load());

  Future<void> _add(int count) async {
    if (_busy) return;
    setState(() => _busy = true);
    try {
      await _api.incrementEggs(count: count);
      _refresh();
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text('Failed: $e')));
      }
    } finally {
      if (mounted) setState(() => _busy = false);
    }
  }

  Future<void> _addCustom() async {
    final controller = TextEditingController();
    final value = await showDialog<int>(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Add eggs'),
        content: TextField(
          controller: controller,
          autofocus: true,
          keyboardType: TextInputType.number,
          decoration: const InputDecoration(labelText: 'How many?'),
          onSubmitted: (v) => Navigator.of(context).pop(int.tryParse(v.trim())),
        ),
        actions: [
          TextButton(onPressed: () => Navigator.of(context).pop(), child: const Text('Cancel')),
          FilledButton(
            onPressed: () => Navigator.of(context).pop(int.tryParse(controller.text.trim())),
            child: const Text('Add'),
          ),
        ],
      ),
    );
    if (value != null && value > 0) _add(value);
  }

  @override
  Widget build(BuildContext context) {
    return RefreshIndicator(
      onRefresh: () async => _refresh(),
      child: AsyncView<(EggSummary, EggTrend, List<EggRecord>)>(
        future: _future,
        onRetry: _refresh,
        builder: (context, data) {
          final (summary, trend, records) = data;
          return ListView(
            physics: const AlwaysScrollableScrollPhysics(),
            padding: const EdgeInsets.all(12),
            children: [
              _CounterCard(today: summary.today, busy: _busy, onAdd: _add, onCustom: _addCustom),
              const SizedBox(height: 8),
              _SummaryRow(summary: summary),
              if (trend.total > 0) ...[
                const SizedBox(height: 8),
                _TrendCard(trend: trend),
              ],
              const SizedBox(height: 16),
              Padding(
                padding: const EdgeInsets.symmetric(horizontal: 4),
                child: Text('Recent', style: Theme.of(context).textTheme.titleMedium),
              ),
              const SizedBox(height: 4),
              if (records.isEmpty)
                const Padding(
                  padding: EdgeInsets.all(24),
                  child: Center(child: Text('No eggs logged yet.')),
                )
              else
                for (final r in records) _EggTile(record: r),
            ],
          );
        },
      ),
    );
  }
}

class _CounterCard extends StatelessWidget {
  final int today;
  final bool busy;
  final void Function(int count) onAdd;
  final VoidCallback onCustom;

  const _CounterCard({
    required this.today,
    required this.busy,
    required this.onAdd,
    required this.onCustom,
  });

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return Card(
      color: theme.colorScheme.primaryContainer,
      child: Padding(
        padding: const EdgeInsets.all(20),
        child: Column(
          children: [
            Text('Collected today', style: theme.textTheme.labelLarge),
            const SizedBox(height: 4),
            Text(
              '$today',
              style: theme.textTheme.displayMedium?.copyWith(
                color: theme.colorScheme.onPrimaryContainer,
                fontWeight: FontWeight.bold,
              ),
            ),
            const SizedBox(height: 12),
            SizedBox(
              width: double.infinity,
              child: FilledButton.icon(
                onPressed: busy ? null : () => onAdd(1),
                icon: const Icon(Icons.add),
                label: const Text('Add one egg'),
                style: FilledButton.styleFrom(padding: const EdgeInsets.symmetric(vertical: 16)),
              ),
            ),
            const SizedBox(height: 8),
            Wrap(
              spacing: 8,
              alignment: WrapAlignment.center,
              children: [
                for (final n in const [2, 4, 6, 12])
                  ActionChip(label: Text('+$n'), onPressed: busy ? null : () => onAdd(n)),
                ActionChip(
                  avatar: const Icon(Icons.edit, size: 16),
                  label: const Text('Custom'),
                  onPressed: busy ? null : onCustom,
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }
}

class _SummaryRow extends StatelessWidget {
  final EggSummary summary;
  const _SummaryRow({required this.summary});

  @override
  Widget build(BuildContext context) {
    Widget stat(String label, int value) => Expanded(
          child: Card(
            child: Padding(
              padding: const EdgeInsets.symmetric(vertical: 14),
              child: Column(
                children: [
                  Text('$value', style: Theme.of(context).textTheme.titleLarge),
                  Text(label, style: Theme.of(context).textTheme.bodySmall),
                ],
              ),
            ),
          ),
        );
    return Row(
      children: [
        stat('This week', summary.thisWeek),
        stat('This month', summary.thisMonth),
        stat('All time', summary.total),
      ],
    );
  }
}

class _TrendCard extends StatelessWidget {
  final EggTrend trend;
  const _TrendCard({required this.trend});

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return Card(
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Text('Last 30 days', style: theme.textTheme.titleSmall),
                Text(
                  '${trend.average}/day avg · ${trend.total} total',
                  style: theme.textTheme.bodySmall,
                ),
              ],
            ),
            const SizedBox(height: 12),
            MiniBarChart(values: [for (final d in trend.days) d.count]),
          ],
        ),
      ),
    );
  }
}

class _EggTile extends StatelessWidget {
  final EggRecord record;
  const _EggTile({required this.record});

  @override
  Widget build(BuildContext context) {
    return Card(
      margin: const EdgeInsets.symmetric(horizontal: 0, vertical: 4),
      child: ListTile(
        leading: const Icon(Icons.egg_outlined),
        title: Text(DateFormat('EEE d MMM y').format(record.date)),
        subtitle: record.source.isNotEmpty ? Text(record.source) : null,
        trailing: Text(
          '${record.count}',
          style: Theme.of(context).textTheme.titleLarge,
        ),
      ),
    );
  }
}
