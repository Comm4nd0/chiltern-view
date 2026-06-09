import 'package:flutter/material.dart';
import 'package:intl/intl.dart';

import '../api/api_client.dart';
import '../models/crop.dart';
import '../models/crop_catalog.dart';
import '../widgets/async_view.dart';
import '../widgets/crop_card.dart';

class CropsScreen extends StatefulWidget {
  const CropsScreen({super.key});

  @override
  State<CropsScreen> createState() => _CropsScreenState();
}

class _CropsScreenState extends State<CropsScreen> {
  final ApiClient _api = ApiClient();
  late Future<List<Crop>> _future;

  @override
  void initState() {
    super.initState();
    _future = _api.crops();
  }

  void _refresh() => setState(() => _future = _api.crops());

  Future<void> _addCrop() async {
    final created = await showModalBottomSheet<bool>(
      context: context,
      isScrollControlled: true,
      builder: (_) => _AddCropSheet(api: _api),
    );
    if (created == true) _refresh();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      floatingActionButton: FloatingActionButton.extended(
        onPressed: _addCrop,
        icon: const Icon(Icons.add),
        label: const Text('Crop'),
      ),
      body: RefreshIndicator(
        onRefresh: () async => _refresh(),
        child: AsyncView<List<Crop>>(
          future: _future,
          onRetry: _refresh,
          builder: (context, crops) {
            if (crops.isEmpty) {
              return ListView(
                children: const [
                  SizedBox(height: 120),
                  Center(child: Text('Nothing growing yet — add a crop.')),
                ],
              );
            }
            return ListView.builder(
              physics: const AlwaysScrollableScrollPhysics(),
              padding: const EdgeInsets.symmetric(vertical: 8),
              itemCount: crops.length,
              itemBuilder: (context, i) => CropCard(crop: crops[i]),
            );
          },
        ),
      ),
    );
  }
}

class _AddCropSheet extends StatefulWidget {
  final ApiClient api;
  const _AddCropSheet({required this.api});

  @override
  State<_AddCropSheet> createState() => _AddCropSheetState();
}

class _AddCropSheetState extends State<_AddCropSheet> {
  final _formKey = GlobalKey<FormState>();
  final _variety = TextEditingController();
  final _bed = TextEditingController();
  List<CropCatalogEntry> _catalog = [];
  String? _crop;
  DateTime _plantedOn = DateTime.now();
  bool _saving = false;

  @override
  void initState() {
    super.initState();
    _loadCatalog();
  }

  Future<void> _loadCatalog() async {
    try {
      final catalog = await widget.api.cropCatalog();
      if (mounted) setState(() => _catalog = catalog);
    } catch (_) {
      // The crop dropdown just stays empty if the catalog can't be loaded.
    }
  }

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
      await widget.api.createCrop(
        crop: _crop!,
        variety: _variety.text.trim(),
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
            Text('New crop', style: Theme.of(context).textTheme.titleLarge),
            const SizedBox(height: 12),
            DropdownButtonFormField<String>(
              initialValue: _crop,
              decoration: const InputDecoration(labelText: 'Crop', border: OutlineInputBorder()),
              items: [
                for (final entry in _catalog)
                  DropdownMenuItem<String>(value: entry.key, child: Text(entry.label)),
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
