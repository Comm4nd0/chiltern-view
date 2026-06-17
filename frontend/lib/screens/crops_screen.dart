import 'package:flutter/material.dart';
import 'package:intl/intl.dart';

import '../api/api_client.dart';
import '../models/bed_history.dart';
import '../models/crop.dart';
import '../models/crop_catalog.dart';
import '../services/notification_service.dart';
import '../widgets/async_view.dart';
import '../widgets/crop_card.dart';

class CropsScreen extends StatefulWidget {
  const CropsScreen({super.key});

  @override
  State<CropsScreen> createState() => _CropsScreenState();
}

class _CropsScreenState extends State<CropsScreen> {
  final ApiClient _api = ApiClient();
  bool _showPrevious = false;
  late Future<List<Crop>> _future;

  @override
  void initState() {
    super.initState();
    _future = _load();
  }

  Future<List<Crop>> _load() => _api.crops(show: _showPrevious ? 'all' : 'growing');

  void _refresh() => setState(() => _future = _load());

  /// Crop changes ripple into the to-do list (auto watering/harvest reminders),
  /// so refresh the scheduled notifications as well as the crop list.
  void _changed() {
    _refresh();
    syncReminders(_api);
  }

  Future<void> _addCrop() async {
    final changed = await showModalBottomSheet<bool>(
      context: context,
      isScrollControlled: true,
      builder: (_) => _CropSheet(api: _api),
    );
    if (changed == true) _changed();
  }

  Future<void> _editCrop(Crop crop) async {
    final changed = await showModalBottomSheet<bool>(
      context: context,
      isScrollControlled: true,
      builder: (_) => _CropSheet(api: _api, crop: crop),
    );
    if (changed == true) _changed();
  }

  Future<void> _harvestCrop(Crop crop) async {
    final harvested = await showModalBottomSheet<Crop>(
      context: context,
      isScrollControlled: true,
      builder: (_) => _HarvestSheet(api: _api, crop: crop),
    );
    if (harvested == null) return;
    _changed();
    if (mounted) {
      final yield_ = harvested.yieldKg;
      ScaffoldMessenger.of(context).showSnackBar(SnackBar(
        content: Text(yield_ != null
            ? 'Harvested ${harvested.cropLabel} — $yield_ kg'
            : 'Harvested ${harvested.cropLabel}'),
      ));
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      floatingActionButton: FloatingActionButton.extended(
        onPressed: _addCrop,
        icon: const Icon(Icons.add),
        label: const Text('Crop'),
      ),
      body: Column(
        children: [
          Padding(
            padding: const EdgeInsets.fromLTRB(16, 8, 16, 4),
            child: SegmentedButton<bool>(
              segments: const [
                ButtonSegment(value: false, label: Text('Growing')),
                ButtonSegment(value: true, label: Text('Previous')),
              ],
              selected: {_showPrevious},
              onSelectionChanged: (selection) {
                setState(() {
                  _showPrevious = selection.first;
                  _future = _load();
                });
              },
            ),
          ),
          Expanded(
            child: RefreshIndicator(
              onRefresh: () async => _refresh(),
              child: AsyncView<List<Crop>>(
                future: _future,
                onRetry: _refresh,
                builder: (context, crops) {
                  final shown = _showPrevious
                      ? (crops.where((c) => c.isHarvested).toList()
                        ..sort((a, b) => b.harvestedOn!.compareTo(a.harvestedOn!)))
                      : crops;
                  if (shown.isEmpty) {
                    return ListView(
                      children: [
                        const SizedBox(height: 120),
                        Center(
                          child: Text(_showPrevious
                              ? 'No harvested crops yet.'
                              : 'Nothing growing yet — add a crop.'),
                        ),
                      ],
                    );
                  }
                  final history = _showPrevious ? _yieldHistory(shown) : <_YieldRow>[];
                  return ListView(
                    physics: const AlwaysScrollableScrollPhysics(),
                    padding: const EdgeInsets.symmetric(vertical: 8),
                    children: [
                      if (history.isNotEmpty) _YieldHistoryCard(rows: history),
                      for (final crop in shown)
                        CropCard(
                          crop: crop,
                          onTap: () => _editCrop(crop),
                          onHarvest: crop.isHarvested ? null : () => _harvestCrop(crop),
                        ),
                    ],
                  );
                },
              ),
            ),
          ),
        ],
      ),
    );
  }
}

class _YieldRow {
  final String key;
  final String label;
  int plantings = 0;
  double totalKg = 0;
  final List<String> varieties = [];

  _YieldRow(this.key, this.label);
}

/// Roll harvested crops up by type: plantings, total kg, varieties grown.
List<_YieldRow> _yieldHistory(List<Crop> harvested) {
  final groups = <String, _YieldRow>{};
  for (final crop in harvested) {
    final row = groups.putIfAbsent(crop.crop, () => _YieldRow(crop.crop, crop.cropLabel));
    row.plantings += 1;
    if (crop.yieldKg != null) row.totalKg += crop.yieldKg!;
    if (crop.variety.isNotEmpty && !row.varieties.contains(crop.variety)) {
      row.varieties.add(crop.variety);
    }
  }
  return groups.values.toList()..sort((a, b) => b.totalKg.compareTo(a.totalKg));
}

class _YieldHistoryCard extends StatelessWidget {
  final List<_YieldRow> rows;
  const _YieldHistoryCard({required this.rows});

  String _kg(double value) =>
      value == value.roundToDouble() ? value.toStringAsFixed(0) : value.toStringAsFixed(2);

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final totalKg = rows.fold<double>(0, (sum, row) => sum + row.totalKg);
    return Card(
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              crossAxisAlignment: CrossAxisAlignment.baseline,
              textBaseline: TextBaseline.alphabetic,
              children: [
                Text('Yield history', style: theme.textTheme.titleMedium),
                if (totalKg > 0)
                  Text('${_kg(totalKg)} kg total',
                      style: theme.textTheme.titleSmall
                          ?.copyWith(color: theme.colorScheme.onSurfaceVariant)),
              ],
            ),
            const SizedBox(height: 8),
            for (final row in rows)
              Padding(
                padding: const EdgeInsets.symmetric(vertical: 4),
                child: Row(
                  crossAxisAlignment: CrossAxisAlignment.baseline,
                  textBaseline: TextBaseline.alphabetic,
                  children: [
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(row.label,
                              style: theme.textTheme.bodyMedium
                                  ?.copyWith(fontWeight: FontWeight.w600)),
                          if (row.varieties.isNotEmpty)
                            Text(row.varieties.join(', '),
                                style: theme.textTheme.bodySmall),
                        ],
                      ),
                    ),
                    Text(
                      '${row.plantings} planting${row.plantings == 1 ? '' : 's'}',
                      style: theme.textTheme.bodySmall,
                    ),
                    if (row.totalKg > 0) ...[
                      const SizedBox(width: 8),
                      Text('${_kg(row.totalKg)} kg',
                          style: theme.textTheme.bodyMedium
                              ?.copyWith(fontWeight: FontWeight.w600)),
                    ],
                  ],
                ),
              ),
          ],
        ),
      ),
    );
  }
}

/// Crop-rotation hint shown under the bed field when the chosen crop's family
/// was grown in that bed recently.
class _RotationWarning extends StatelessWidget {
  final BedHistory clash;
  final String? familyLabel;
  const _RotationWarning({required this.clash, this.familyLabel});

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final amber = Colors.orange.shade800;
    return Container(
      margin: const EdgeInsets.only(top: 8),
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
      decoration: BoxDecoration(
        color: amber.withValues(alpha: 0.10),
        borderRadius: BorderRadius.circular(8),
      ),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Icon(Icons.warning_amber_rounded, size: 18, color: amber),
          const SizedBox(width: 8),
          Expanded(
            child: Text(
              '${familyLabel ?? 'This family'} was grown in ${clash.bed} recently '
              '(${clash.lastCrop}). Rotating to a different bed helps avoid soil '
              'pests and disease.',
              style: theme.textTheme.bodySmall,
            ),
          ),
        ],
      ),
    );
  }
}

/// Add a new crop planting, or edit/delete an existing one when [crop] is given.
class _CropSheet extends StatefulWidget {
  final ApiClient api;
  final Crop? crop;
  const _CropSheet({required this.api, this.crop});

  @override
  State<_CropSheet> createState() => _CropSheetState();
}

class _CropSheetState extends State<_CropSheet> {
  final _formKey = GlobalKey<FormState>();
  late final TextEditingController _variety;
  late final TextEditingController _bed;
  late final TextEditingController _quantity;
  late final TextEditingController _notes;
  List<CropCatalogEntry> _catalog = [];
  List<BedHistory> _beds = [];
  String? _crop;
  late DateTime _plantedOn;
  DateTime? _expectedHarvest;
  bool _saving = false;

  bool get _editing => widget.crop != null;

  @override
  void initState() {
    super.initState();
    final crop = widget.crop;
    _crop = crop?.crop;
    _variety = TextEditingController(text: crop?.variety ?? '');
    _bed = TextEditingController(text: crop?.bed ?? '');
    _quantity = TextEditingController(text: crop?.quantity?.toString() ?? '');
    _notes = TextEditingController(text: crop?.notes ?? '');
    _plantedOn = crop?.plantedOn ?? DateTime.now();
    _expectedHarvest = crop?.expectedHarvest;
    _loadRefs();
  }

  Future<void> _loadRefs() async {
    try {
      final catalog = await widget.api.cropCatalog();
      if (mounted) setState(() => _catalog = catalog);
    } catch (_) {
      // The crop dropdown just stays empty if the catalog can't be loaded.
    }
    try {
      final beds = await widget.api.beds();
      if (mounted) setState(() => _beds = beds);
    } catch (_) {
      // No rotation hint if the bed history can't be loaded — non-essential.
    }
  }

  /// Botanical family of the currently selected crop, from the catalog.
  String? get _selectedFamily {
    for (final entry in _catalog) {
      if (entry.key == _crop) return entry.family;
    }
    return widget.crop?.family;
  }

  String? get _selectedFamilyLabel {
    for (final entry in _catalog) {
      if (entry.key == _crop) return entry.familyLabel;
    }
    return widget.crop?.familyLabel;
  }

  /// The bed history clashing with this planting — same botanical family grown
  /// in the chosen bed recently — or null when rotation looks fine.
  BedHistory? get _rotationClash {
    final family = _selectedFamily;
    final bed = _bed.text.trim().toLowerCase();
    if (family == null || bed.isEmpty) return null;
    // Editing the same planting in its own bed shouldn't flag itself.
    if (_editing && widget.crop!.bed.trim().toLowerCase() == bed) return null;
    for (final b in _beds) {
      if (b.bed.trim().toLowerCase() == bed && b.recentFamilies.contains(family)) {
        return b;
      }
    }
    return null;
  }

  @override
  void dispose() {
    _variety.dispose();
    _bed.dispose();
    _quantity.dispose();
    _notes.dispose();
    super.dispose();
  }

  Future<DateTime?> _pick(DateTime initial) => showDatePicker(
        context: context,
        initialDate: initial,
        firstDate: DateTime(DateTime.now().year - 2),
        lastDate: DateTime(DateTime.now().year + 2),
      );

  Future<void> _save() async {
    if (!_formKey.currentState!.validate()) return;
    setState(() => _saving = true);
    try {
      final quantity = _quantity.text.trim().isEmpty ? null : int.parse(_quantity.text.trim());
      if (_editing) {
        await widget.api.updateCrop(
          widget.crop!.id,
          crop: _crop!,
          variety: _variety.text.trim(),
          plantedOn: _plantedOn,
          bed: _bed.text.trim(),
          quantity: quantity,
          expectedHarvest: _expectedHarvest,
          notes: _notes.text.trim(),
        );
      } else {
        await widget.api.createCrop(
          crop: _crop!,
          variety: _variety.text.trim(),
          plantedOn: _plantedOn,
          bed: _bed.text.trim(),
          quantity: quantity,
          expectedHarvest: _expectedHarvest,
          notes: _notes.text.trim(),
        );
      }
      if (mounted) Navigator.of(context).pop(true);
    } catch (e) {
      if (mounted) {
        setState(() => _saving = false);
        ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text('Failed: $e')));
      }
    }
  }

  Future<void> _delete() async {
    final crop = widget.crop!;
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: Text('Delete ${crop.cropLabel}?'),
        content: const Text('Its watering and harvest reminders go too.'),
        actions: [
          TextButton(
              onPressed: () => Navigator.of(context).pop(false), child: const Text('Cancel')),
          FilledButton(
              onPressed: () => Navigator.of(context).pop(true), child: const Text('Delete')),
        ],
      ),
    );
    if (confirmed != true) return;
    setState(() => _saving = true);
    try {
      await widget.api.deleteCrop(crop.id);
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
    final dateFmt = DateFormat('d MMM y');
    return Padding(
      padding: EdgeInsets.fromLTRB(16, 16, 16, 16 + bottomInset),
      child: Form(
        key: _formKey,
        child: SingleChildScrollView(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(_editing ? 'Edit crop' : 'New crop',
                  style: Theme.of(context).textTheme.titleLarge),
              const SizedBox(height: 12),
              DropdownButtonFormField<String>(
                initialValue: _crop,
                decoration: const InputDecoration(labelText: 'Crop', border: OutlineInputBorder()),
                items: [
                  for (final entry in _catalog)
                    DropdownMenuItem<String>(value: entry.key, child: Text(entry.label)),
                  // Keep the current value selectable while the catalog loads.
                  if (_crop != null && !_catalog.any((e) => e.key == _crop))
                    DropdownMenuItem<String>(
                        value: _crop, child: Text(widget.crop?.cropLabel ?? _crop!)),
                ],
                onChanged: (v) => setState(() => _crop = v),
                validator: (v) => v == null ? 'Pick a crop' : null,
              ),
              const SizedBox(height: 12),
              TextFormField(
                controller: _variety,
                decoration: const InputDecoration(
                  labelText: 'Variety (optional, e.g. Maris Piper)',
                  border: OutlineInputBorder(),
                ),
              ),
              const SizedBox(height: 12),
              TextFormField(
                controller: _bed,
                decoration: const InputDecoration(
                  labelText: 'Bed / row (optional)',
                  border: OutlineInputBorder(),
                ),
                onChanged: (_) => setState(() {}),
              ),
              if (_rotationClash != null) _RotationWarning(
                clash: _rotationClash!,
                familyLabel: _selectedFamilyLabel,
              ),
              const SizedBox(height: 12),
              TextFormField(
                controller: _quantity,
                keyboardType: TextInputType.number,
                decoration: const InputDecoration(
                  labelText: 'Quantity planted (optional)',
                  border: OutlineInputBorder(),
                ),
                validator: (v) {
                  final text = v?.trim() ?? '';
                  if (text.isEmpty) return null;
                  final n = int.tryParse(text);
                  return (n == null || n < 0) ? 'Whole number' : null;
                },
              ),
              const SizedBox(height: 12),
              InkWell(
                onTap: () async {
                  final picked = await _pick(_plantedOn);
                  if (picked != null) setState(() => _plantedOn = picked);
                },
                child: InputDecorator(
                  decoration: const InputDecoration(
                    labelText: 'Planted on',
                    border: OutlineInputBorder(),
                  ),
                  child: Text(dateFmt.format(_plantedOn)),
                ),
              ),
              const SizedBox(height: 12),
              InkWell(
                onTap: () async {
                  final picked = await _pick(_expectedHarvest ?? DateTime.now());
                  if (picked != null) setState(() => _expectedHarvest = picked);
                },
                child: InputDecorator(
                  decoration: InputDecoration(
                    labelText: 'Expected harvest (optional)',
                    helperText: "Leave blank to estimate from the crop's usual season.",
                    border: const OutlineInputBorder(),
                    suffixIcon: _expectedHarvest != null
                        ? IconButton(
                            icon: const Icon(Icons.clear),
                            onPressed: () => setState(() => _expectedHarvest = null),
                          )
                        : null,
                  ),
                  child: Text(
                    _expectedHarvest != null ? dateFmt.format(_expectedHarvest!) : '—',
                  ),
                ),
              ),
              const SizedBox(height: 12),
              TextFormField(
                controller: _notes,
                maxLines: 2,
                decoration: const InputDecoration(
                  labelText: 'Notes (optional)',
                  border: OutlineInputBorder(),
                ),
              ),
              const SizedBox(height: 16),
              Row(
                children: [
                  if (_editing)
                    TextButton(
                      onPressed: _saving ? null : _delete,
                      style: TextButton.styleFrom(
                          foregroundColor: Theme.of(context).colorScheme.error),
                      child: const Text('Delete'),
                    ),
                  const Spacer(),
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
                        : Text(_editing ? 'Save' : 'Add'),
                  ),
                ],
              ),
            ],
          ),
        ),
      ),
    );
  }
}

/// Record a harvest: date + optional yield. Also retires the crop's reminders.
class _HarvestSheet extends StatefulWidget {
  final ApiClient api;
  final Crop crop;
  const _HarvestSheet({required this.api, required this.crop});

  @override
  State<_HarvestSheet> createState() => _HarvestSheetState();
}

class _HarvestSheetState extends State<_HarvestSheet> {
  final _formKey = GlobalKey<FormState>();
  final _yield = TextEditingController();
  final _note = TextEditingController();
  DateTime _date = DateTime.now();
  bool _saving = false;

  @override
  void dispose() {
    _yield.dispose();
    _note.dispose();
    super.dispose();
  }

  Future<void> _save() async {
    if (!_formKey.currentState!.validate()) return;
    setState(() => _saving = true);
    try {
      final text = _yield.text.trim();
      final harvested = await widget.api.harvestCrop(
        widget.crop.id,
        date: _date,
        yieldKg: text.isEmpty ? null : double.parse(text),
        note: _note.text.trim(),
      );
      if (mounted) Navigator.of(context).pop(harvested);
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
            Text('Harvest ${widget.crop.cropLabel}',
                style: Theme.of(context).textTheme.titleLarge),
            const SizedBox(height: 12),
            InkWell(
              onTap: () async {
                final picked = await showDatePicker(
                  context: context,
                  initialDate: _date,
                  firstDate: DateTime(DateTime.now().year - 2),
                  lastDate: DateTime.now(),
                );
                if (picked != null) setState(() => _date = picked);
              },
              child: InputDecorator(
                decoration: const InputDecoration(
                  labelText: 'Harvested on',
                  border: OutlineInputBorder(),
                ),
                child: Text(DateFormat('d MMM y').format(_date)),
              ),
            ),
            const SizedBox(height: 12),
            TextFormField(
              controller: _yield,
              autofocus: true,
              keyboardType: const TextInputType.numberWithOptions(decimal: true),
              decoration: const InputDecoration(
                labelText: 'Yield (kg, optional)',
                border: OutlineInputBorder(),
              ),
              validator: (v) {
                final text = v?.trim() ?? '';
                if (text.isEmpty) return null;
                return double.tryParse(text) == null ? 'Enter a number' : null;
              },
            ),
            const SizedBox(height: 12),
            TextFormField(
              controller: _note,
              maxLines: 2,
              decoration: const InputDecoration(
                labelText: 'Note (optional)',
                border: OutlineInputBorder(),
              ),
            ),
            const SizedBox(height: 8),
            Text(
              "Marking the harvest also clears this crop's watering and harvest reminders.",
              style: Theme.of(context).textTheme.bodySmall,
            ),
            const SizedBox(height: 16),
            Row(
              mainAxisAlignment: MainAxisAlignment.end,
              children: [
                TextButton(
                  onPressed: _saving ? null : () => Navigator.of(context).pop(),
                  child: const Text('Cancel'),
                ),
                const SizedBox(width: 8),
                FilledButton(
                  onPressed: _saving ? null : _save,
                  child: _saving
                      ? const SizedBox(
                          width: 18, height: 18, child: CircularProgressIndicator(strokeWidth: 2))
                      : const Text('Harvest'),
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }
}
