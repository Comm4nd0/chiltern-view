import 'package:flutter/material.dart';

import '../api/api_client.dart';
import '../models/animal.dart';
import '../widgets/async_view.dart';
import 'egg_log_screen.dart';

const List<List<String>> _speciesChoices = [
  ['chicken', 'Chicken'],
  ['duck', 'Duck'],
  ['goose', 'Goose'],
  ['turkey', 'Turkey'],
  ['goat', 'Goat'],
  ['sheep', 'Sheep'],
  ['pig', 'Pig'],
  ['cow', 'Cow'],
  ['horse', 'Horse'],
  ['rabbit', 'Rabbit'],
  ['tortoise', 'Tortoise'],
  ['dog', 'Dog'],
  ['cat', 'Cat'],
  ['bees', 'Bee colony'],
  ['other', 'Other'],
];

class AnimalsScreen extends StatefulWidget {
  const AnimalsScreen({super.key});

  @override
  State<AnimalsScreen> createState() => _AnimalsScreenState();
}

class _AnimalsScreenState extends State<AnimalsScreen> {
  final ApiClient _api = ApiClient();
  late Future<List<Animal>> _future;
  String _view = 'animals';

  @override
  void initState() {
    super.initState();
    _future = _api.animals();
  }

  void _refresh() => setState(() => _future = _api.animals());

  Future<void> _add() async {
    final created = await showModalBottomSheet<bool>(
      context: context,
      isScrollControlled: true,
      builder: (_) => _AddAnimalSheet(api: _api),
    );
    if (created == true) _refresh();
  }

  Future<void> _confirmDelete(Animal animal) async {
    final yes = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: Text('Remove ${animal.name}?'),
        content: const Text('Their tasks stay but become unassigned.'),
        actions: [
          TextButton(onPressed: () => Navigator.of(context).pop(false), child: const Text('Cancel')),
          FilledButton(onPressed: () => Navigator.of(context).pop(true), child: const Text('Remove')),
        ],
      ),
    );
    if (yes != true) return;
    try {
      await _api.deleteAnimal(animal.id);
      _refresh();
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text('Failed: $e')));
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      floatingActionButton: _view == 'animals'
          ? FloatingActionButton.extended(
              onPressed: _add,
              icon: const Icon(Icons.add),
              label: const Text('Animal'),
            )
          : null,
      body: Column(
        children: [
          Padding(
            padding: const EdgeInsets.all(12),
            child: Center(
              child: SegmentedButton<String>(
                segments: const [
                  ButtonSegment(value: 'animals', label: Text('Animals')),
                  ButtonSegment(value: 'eggs', label: Text('Eggs')),
                ],
                selected: {_view},
                onSelectionChanged: (s) => setState(() => _view = s.first),
              ),
            ),
          ),
          Expanded(
            child: _view == 'animals' ? _animalsBody() : const EggLogScreen(),
          ),
        ],
      ),
    );
  }

  Widget _animalsBody() {
    return RefreshIndicator(
      onRefresh: () async => _refresh(),
      child: AsyncView<List<Animal>>(
        future: _future,
        onRetry: _refresh,
        builder: (context, animals) {
          if (animals.isEmpty) {
            return ListView(
              children: const [
                SizedBox(height: 120),
                Center(child: Text('No animals yet — add your first.')),
              ],
            );
          }
          return ListView.builder(
            physics: const AlwaysScrollableScrollPhysics(),
            padding: const EdgeInsets.symmetric(vertical: 8),
            itemCount: animals.length,
            itemBuilder: (context, i) {
              final animal = animals[i];
              final sub =
                  [animal.speciesDisplay, animal.breed].where((s) => s.isNotEmpty).join(' · ');
              return Card(
                child: ListTile(
                  leading: const Icon(Icons.pets),
                  title: Text(animal.name),
                  subtitle: sub.isEmpty ? null : Text(sub),
                  trailing: IconButton(
                    icon: const Icon(Icons.delete_outline),
                    onPressed: () => _confirmDelete(animal),
                  ),
                ),
              );
            },
          );
        },
      ),
    );
  }
}

class _AddAnimalSheet extends StatefulWidget {
  final ApiClient api;
  const _AddAnimalSheet({required this.api});

  @override
  State<_AddAnimalSheet> createState() => _AddAnimalSheetState();
}

class _AddAnimalSheetState extends State<_AddAnimalSheet> {
  final _formKey = GlobalKey<FormState>();
  final _name = TextEditingController();
  final _breed = TextEditingController();
  String _species = 'chicken';
  bool _saving = false;

  @override
  void dispose() {
    _name.dispose();
    _breed.dispose();
    super.dispose();
  }

  Future<void> _save() async {
    if (!_formKey.currentState!.validate()) return;
    setState(() => _saving = true);
    try {
      await widget.api.createAnimal(
        name: _name.text.trim(),
        species: _species,
        breed: _breed.text.trim(),
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
            Text('New animal', style: Theme.of(context).textTheme.titleLarge),
            const SizedBox(height: 12),
            TextFormField(
              controller: _name,
              decoration: const InputDecoration(labelText: 'Name', border: OutlineInputBorder()),
              validator: (v) => (v == null || v.trim().isEmpty) ? 'Required' : null,
            ),
            const SizedBox(height: 12),
            DropdownButtonFormField<String>(
              initialValue: _species,
              decoration: const InputDecoration(labelText: 'Species', border: OutlineInputBorder()),
              items: [
                for (final s in _speciesChoices)
                  DropdownMenuItem<String>(value: s[0], child: Text(s[1])),
              ],
              onChanged: (v) => setState(() => _species = v ?? 'chicken'),
            ),
            const SizedBox(height: 12),
            TextFormField(
              controller: _breed,
              decoration: const InputDecoration(
                labelText: 'Breed (optional)',
                border: OutlineInputBorder(),
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
