import 'package:flutter/material.dart';
import 'package:intl/intl.dart';

import '../api/api_client.dart';
import '../models/potato_planting.dart';
import '../widgets/async_view.dart';
import '../widgets/potato_timeline_card.dart';

class PotatoTimelineScreen extends StatefulWidget {
  const PotatoTimelineScreen({super.key});

  @override
  State<PotatoTimelineScreen> createState() => _PotatoTimelineScreenState();
}

class _PotatoTimelineScreenState extends State<PotatoTimelineScreen> {
  final ApiClient _api = ApiClient();
  late Future<List<PotatoPlanting>> _future;

  @override
  void initState() {
    super.initState();
    _future = _api.potatoTimeline();
  }

  void _refresh() => setState(() => _future = _api.potatoTimeline());

  Future<void> _addPlanting() async {
    final created = await showModalBottomSheet<bool>(
      context: context,
      isScrollControlled: true,
      builder: (_) => _AddPlantingSheet(api: _api),
    );
    if (created == true) _refresh();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      floatingActionButton: FloatingActionButton.extended(
        onPressed: _addPlanting,
        icon: const Icon(Icons.add),
        label: const Text('Planting'),
      ),
      body: RefreshIndicator(
        onRefresh: () async => _refresh(),
        child: AsyncView<List<PotatoPlanting>>(
          future: _future,
          onRetry: _refresh,
          builder: (context, plantings) {
            if (plantings.isEmpty) {
              return ListView(
                children: const [
                  SizedBox(height: 120),
                  Center(child: Text('No potatoes in the ground yet.')),
                ],
              );
            }
            return ListView.builder(
              physics: const AlwaysScrollableScrollPhysics(),
              padding: const EdgeInsets.symmetric(vertical: 8),
              itemCount: plantings.length,
              itemBuilder: (context, i) => PotatoTimelineCard(planting: plantings[i]),
            );
          },
        ),
      ),
    );
  }
}

class _AddPlantingSheet extends StatefulWidget {
  final ApiClient api;
  const _AddPlantingSheet({required this.api});

  @override
  State<_AddPlantingSheet> createState() => _AddPlantingSheetState();
}

class _AddPlantingSheetState extends State<_AddPlantingSheet> {
  static const Map<String, String> _categories = {
    'first_early': 'First early',
    'second_early': 'Second early',
    'maincrop': 'Maincrop',
    'salad': 'Salad',
  };

  final _formKey = GlobalKey<FormState>();
  final _variety = TextEditingController();
  final _bed = TextEditingController();
  String _category = 'maincrop';
  DateTime _plantedOn = DateTime.now();
  bool _saving = false;

  @override
  void dispose() {
    _variety.dispose();
    _bed.dispose();
    super.dispose();
  }

  Future<void> _pickDate() async {
    final picked = await showDatePicker(
      context: context,
      initialDate: _plantedOn,
      firstDate: DateTime(DateTime.now().year - 2),
      lastDate: DateTime(DateTime.now().year + 1),
    );
    if (picked != null) setState(() => _plantedOn = picked);
  }

  Future<void> _save() async {
    if (!_formKey.currentState!.validate()) return;
    setState(() => _saving = true);
    try {
      await widget.api.createPlanting(
        variety: _variety.text.trim(),
        category: _category,
        plantedOn: _plantedOn,
        bed: _bed.text.trim(),
      );
      if (mounted) Navigator.of(context).pop(true);
    } catch (e) {
      if (mounted) {
        setState(() => _saving = false);
        ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text('Failed: $e')));
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    final bottomInset = MediaQuery.of(context).viewInsets.bottom;
    return Padding(
      padding: EdgeInsets.fromLTRB(16, 16, 16, 16 + bottomInset),
      child: Form(
        key: _formKey,
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text('New potato planting', style: Theme.of(context).textTheme.titleLarge),
            const SizedBox(height: 12),
            TextFormField(
              controller: _variety,
              decoration: const InputDecoration(
                labelText: 'Variety (e.g. Maris Piper)',
                border: OutlineInputBorder(),
              ),
              validator: (v) => (v == null || v.trim().isEmpty) ? 'Required' : null,
            ),
            const SizedBox(height: 12),
            DropdownButtonFormField<String>(
              initialValue: _category,
              decoration: const InputDecoration(labelText: 'Type', border: OutlineInputBorder()),
              items: [
                for (final entry in _categories.entries)
                  DropdownMenuItem<String>(value: entry.key, child: Text(entry.value)),
              ],
              onChanged: (v) => setState(() => _category = v ?? 'maincrop'),
            ),
            const SizedBox(height: 12),
            TextFormField(
              controller: _bed,
              decoration: const InputDecoration(
                labelText: 'Bed / row (optional)',
                border: OutlineInputBorder(),
              ),
            ),
            const SizedBox(height: 12),
            InkWell(
              onTap: _pickDate,
              child: InputDecorator(
                decoration: const InputDecoration(
                  labelText: 'Planted on',
                  border: OutlineInputBorder(),
                ),
                child: Text(DateFormat('d MMM y').format(_plantedOn)),
              ),
            ),
            const SizedBox(height: 16),
            Row(
              mainAxisAlignment: MainAxisAlignment.end,
              children: [
                TextButton(
                  onPressed: _saving ? null : () => Navigator.of(context).pop(false),
                  child: const Text('Cancel'),
                ),
                const SizedBox(width: 8),
                FilledButton(
                  onPressed: _saving ? null : _save,
                  child: _saving
                      ? const SizedBox(
                          width: 18, height: 18, child: CircularProgressIndicator(strokeWidth: 2))
                      : const Text('Add'),
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }
}
