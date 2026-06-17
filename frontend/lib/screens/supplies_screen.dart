import 'package:flutter/material.dart';

import '../api/api_client.dart';
import '../models/supply.dart';
import '../widgets/async_view.dart';

/// Feed & supply inventory: stock levels with low-stock flags, plus add/edit.
class SuppliesScreen extends StatefulWidget {
  const SuppliesScreen({super.key});

  @override
  State<SuppliesScreen> createState() => _SuppliesScreenState();
}

class _SuppliesScreenState extends State<SuppliesScreen> {
  final ApiClient _api = ApiClient();
  late Future<List<Supply>> _future;

  @override
  void initState() {
    super.initState();
    _future = _api.supplies();
  }

  void _refresh() => setState(() => _future = _api.supplies());

  Future<void> _addOrEdit([Supply? supply]) async {
    final changed = await showModalBottomSheet<bool>(
      context: context,
      isScrollControlled: true,
      builder: (_) => _SupplySheet(api: _api, supply: supply),
    );
    if (changed == true) _refresh();
  }

  String _qty(double v) => v == v.roundToDouble() ? v.toStringAsFixed(0) : v.toStringAsFixed(2);

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('Supplies')),
      floatingActionButton: FloatingActionButton.extended(
        onPressed: () => _addOrEdit(),
        icon: const Icon(Icons.add),
        label: const Text('Supply'),
      ),
      body: RefreshIndicator(
        onRefresh: () async => _refresh(),
        child: AsyncView<List<Supply>>(
          future: _future,
          onRetry: _refresh,
          builder: (context, supplies) {
            if (supplies.isEmpty) {
              return ListView(
                children: const [
                  SizedBox(height: 120),
                  Center(child: Text('No supplies tracked yet — add feed, hay, bedding…')),
                ],
              );
            }
            return ListView(
              physics: const AlwaysScrollableScrollPhysics(),
              padding: const EdgeInsets.symmetric(vertical: 8),
              children: [
                for (final s in supplies)
                  Card(
                    child: ListTile(
                      title: Text(s.name),
                      subtitle: s.notes.isNotEmpty ? Text(s.notes) : null,
                      trailing: Row(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          if (s.isLow)
                            Container(
                              padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
                              decoration: BoxDecoration(
                                color: Colors.orange.shade800.withValues(alpha: 0.15),
                                borderRadius: BorderRadius.circular(999),
                              ),
                              child: Text('Low',
                                  style: TextStyle(
                                      color: Colors.orange.shade800,
                                      fontSize: 12,
                                      fontWeight: FontWeight.w600)),
                            ),
                          const SizedBox(width: 8),
                          Text('${_qty(s.quantity)} ${s.unit}'.trim()),
                        ],
                      ),
                      onTap: () => _addOrEdit(s),
                    ),
                  ),
              ],
            );
          },
        ),
      ),
    );
  }
}

class _SupplySheet extends StatefulWidget {
  final ApiClient api;
  final Supply? supply;
  const _SupplySheet({required this.api, this.supply});

  @override
  State<_SupplySheet> createState() => _SupplySheetState();
}

class _SupplySheetState extends State<_SupplySheet> {
  final _formKey = GlobalKey<FormState>();
  late final TextEditingController _name;
  late final TextEditingController _unit;
  late final TextEditingController _quantity;
  late final TextEditingController _reorder;
  late final TextEditingController _notes;
  bool _saving = false;

  bool get _editing => widget.supply != null;

  @override
  void initState() {
    super.initState();
    final s = widget.supply;
    String num(double? v) => v == null ? '' : (v == v.roundToDouble() ? v.toStringAsFixed(0) : '$v');
    _name = TextEditingController(text: s?.name ?? '');
    _unit = TextEditingController(text: s?.unit ?? '');
    _quantity = TextEditingController(text: s != null ? num(s.quantity) : '');
    _reorder = TextEditingController(text: s != null ? num(s.reorderAt) : '');
    _notes = TextEditingController(text: s?.notes ?? '');
  }

  @override
  void dispose() {
    _name.dispose();
    _unit.dispose();
    _quantity.dispose();
    _reorder.dispose();
    _notes.dispose();
    super.dispose();
  }

  Future<void> _save() async {
    if (!_formKey.currentState!.validate()) return;
    setState(() => _saving = true);
    try {
      final quantity = double.tryParse(_quantity.text.trim()) ?? 0;
      final reorder = double.tryParse(_reorder.text.trim()) ?? 0;
      if (_editing) {
        await widget.api.updateSupply(
          widget.supply!.id,
          name: _name.text.trim(),
          unit: _unit.text.trim(),
          quantity: quantity,
          reorderAt: reorder,
          notes: _notes.text.trim(),
        );
      } else {
        await widget.api.createSupply(
          name: _name.text.trim(),
          unit: _unit.text.trim(),
          quantity: quantity,
          reorderAt: reorder,
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
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: Text('Delete ${widget.supply!.name}?'),
        actions: [
          TextButton(onPressed: () => Navigator.of(context).pop(false), child: const Text('Cancel')),
          FilledButton(onPressed: () => Navigator.of(context).pop(true), child: const Text('Delete')),
        ],
      ),
    );
    if (confirmed != true) return;
    setState(() => _saving = true);
    try {
      await widget.api.deleteSupply(widget.supply!.id);
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
        child: SingleChildScrollView(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(_editing ? 'Edit supply' : 'New supply',
                  style: Theme.of(context).textTheme.titleLarge),
              const SizedBox(height: 12),
              TextFormField(
                controller: _name,
                autofocus: !_editing,
                decoration: const InputDecoration(
                    labelText: 'Name (e.g. Layer pellets)', border: OutlineInputBorder()),
                validator: (v) => (v == null || v.trim().isEmpty) ? 'Give it a name' : null,
              ),
              const SizedBox(height: 12),
              TextFormField(
                controller: _unit,
                decoration: const InputDecoration(
                    labelText: 'Unit (e.g. kg, bags, bales)', border: OutlineInputBorder()),
              ),
              const SizedBox(height: 12),
              Row(
                children: [
                  Expanded(
                    child: TextFormField(
                      controller: _quantity,
                      keyboardType: const TextInputType.numberWithOptions(decimal: true),
                      decoration:
                          const InputDecoration(labelText: 'In stock', border: OutlineInputBorder()),
                    ),
                  ),
                  const SizedBox(width: 12),
                  Expanded(
                    child: TextFormField(
                      controller: _reorder,
                      keyboardType: const TextInputType.numberWithOptions(decimal: true),
                      decoration: const InputDecoration(
                          labelText: 'Reorder at', border: OutlineInputBorder()),
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 12),
              TextFormField(
                controller: _notes,
                maxLines: 2,
                decoration:
                    const InputDecoration(labelText: 'Notes (optional)', border: OutlineInputBorder()),
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
