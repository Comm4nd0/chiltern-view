import 'package:flutter/material.dart';

import '../api/api_client.dart';
import '../models/animal.dart';
import '../widgets/async_view.dart';

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

const Map<String, String> _speciesEmoji = {
  'chicken': '🐔',
  'duck': '🦆',
  'goose': '🦢',
  'turkey': '🦃',
  'goat': '🐐',
  'sheep': '🐑',
  'pig': '🐷',
  'cow': '🐄',
  'horse': '🐴',
  'rabbit': '🐰',
  'tortoise': '🐢',
  'dog': '🐕',
  'cat': '🐈',
  'bees': '🐝',
  'other': '🐾',
};

/// Age from date of birth, e.g. "2 yr 3 mo" / "5 mo". Null if unknown.
String? _ageLabel(DateTime? dob) {
  if (dob == null) return null;
  final now = DateTime.now();
  int months = (now.year - dob.year) * 12 + (now.month - dob.month);
  if (now.day < dob.day) months -= 1;
  if (months < 0) return null;
  final years = months ~/ 12;
  final rem = months % 12;
  if (years == 0) return '$months mo';
  if (rem == 0) return '$years yr';
  return '$years yr $rem mo';
}

class _SpeciesGroup {
  final String code;
  final String label;
  final List<Animal> animals;
  _SpeciesGroup(this.code, this.label, this.animals);
}

List<_SpeciesGroup> _groupBySpecies(List<Animal> animals) {
  final map = <String, _SpeciesGroup>{};
  for (final a in animals) {
    final g = map.putIfAbsent(a.species, () => _SpeciesGroup(a.species, a.speciesDisplay, []));
    g.animals.add(a);
  }
  final groups = map.values.toList()..sort((x, y) => x.label.compareTo(y.label));
  return groups;
}

class AnimalsScreen extends StatefulWidget {
  const AnimalsScreen({super.key});

  @override
  State<AnimalsScreen> createState() => _AnimalsScreenState();
}

class _AnimalsScreenState extends State<AnimalsScreen> {
  final ApiClient _api = ApiClient();
  late Future<List<Animal>> _future;
  String? _selected; // species code being drilled into; null = tile grid

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
      builder: (_) => _AnimalSheet(api: _api),
    );
    if (created == true) _refresh();
  }

  Future<void> _editAnimal(Animal animal) async {
    final changed = await showModalBottomSheet<bool>(
      context: context,
      isScrollControlled: true,
      builder: (_) => _AnimalSheet(api: _api, animal: animal),
    );
    if (changed == true) _refresh();
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
      floatingActionButton: FloatingActionButton.extended(
        onPressed: _add,
        icon: const Icon(Icons.add),
        label: const Text('Animal'),
      ),
      body: RefreshIndicator(
        onRefresh: () async => _refresh(),
        child: AsyncView<List<Animal>>(
          future: _future,
          onRetry: _refresh,
          builder: (context, animals) {
            if (animals.isEmpty) {
              return ListView(
                physics: const AlwaysScrollableScrollPhysics(),
                children: const [
                  SizedBox(height: 120),
                  Center(child: Text('No animals yet — add your first.')),
                ],
              );
            }
            final groups = _groupBySpecies(animals);
            if (_selected == null) return _tiles(groups);

            _SpeciesGroup? group;
            for (final g in groups) {
              if (g.code == _selected) {
                group = g;
                break;
              }
            }
            return _drilldown(context, group);
          },
        ),
      ),
    );
  }

  Widget _tiles(List<_SpeciesGroup> groups) {
    return GridView.extent(
      maxCrossAxisExtent: 200,
      padding: const EdgeInsets.all(12),
      mainAxisSpacing: 12,
      crossAxisSpacing: 12,
      physics: const AlwaysScrollableScrollPhysics(),
      children: [
        for (final g in groups)
          Card(
            child: InkWell(
              onTap: () => setState(() => _selected = g.code),
              borderRadius: BorderRadius.circular(12),
              child: Padding(
                padding: const EdgeInsets.all(12),
                child: Column(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    Text(_speciesEmoji[g.code] ?? '🐾', style: const TextStyle(fontSize: 40)),
                    const SizedBox(height: 8),
                    Text(g.label,
                        style: Theme.of(context).textTheme.titleMedium,
                        textAlign: TextAlign.center),
                    Text(
                      '${g.animals.length} ${g.animals.length == 1 ? 'animal' : 'animals'}',
                      style: Theme.of(context).textTheme.bodySmall,
                    ),
                  ],
                ),
              ),
            ),
          ),
      ],
    );
  }

  Widget _drilldown(BuildContext context, _SpeciesGroup? group) {
    return ListView(
      physics: const AlwaysScrollableScrollPhysics(),
      padding: const EdgeInsets.all(12),
      children: [
        Row(
          children: [
            IconButton(
              icon: const Icon(Icons.arrow_back),
              tooltip: 'Back to all animals',
              onPressed: () => setState(() => _selected = null),
            ),
            Text(group?.label ?? 'Animals', style: Theme.of(context).textTheme.titleLarge),
          ],
        ),
        const SizedBox(height: 4),
        if (group == null || group.animals.isEmpty)
          const Padding(
            padding: EdgeInsets.all(24),
            child: Center(child: Text('None of these left.')),
          )
        else
          for (final a in group.animals)
            _AnimalRow(
              animal: a,
              onEdit: () => _editAnimal(a),
              onDelete: () => _confirmDelete(a),
            ),
      ],
    );
  }
}

class _AnimalRow extends StatelessWidget {
  final Animal animal;
  final VoidCallback onEdit;
  final VoidCallback onDelete;
  const _AnimalRow({required this.animal, required this.onEdit, required this.onDelete});

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final facts = [_ageLabel(animal.dateOfBirth), animal.breed]
        .where((s) => s != null && s.isNotEmpty)
        .join(' · ');
    return Card(
      margin: const EdgeInsets.symmetric(vertical: 4),
      child: Padding(
        padding: const EdgeInsets.fromLTRB(16, 8, 8, 8),
        child: Row(
          children: [
            Expanded(
              child: InkWell(
                onTap: onEdit,
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(animal.name, style: theme.textTheme.titleMedium),
                    Text(facts.isEmpty ? '—' : facts, style: theme.textTheme.bodySmall),
                  ],
                ),
              ),
            ),
            Chip(
              label: Text(animal.active ? 'Active' : 'Retired'),
              visualDensity: VisualDensity.compact,
              backgroundColor: animal.active
                  ? theme.colorScheme.secondaryContainer
                  : theme.colorScheme.surfaceContainerHighest,
            ),
            IconButton(
              icon: const Icon(Icons.delete_outline),
              tooltip: 'Remove ${animal.name}',
              onPressed: onDelete,
            ),
          ],
        ),
      ),
    );
  }
}

class _AnimalSheet extends StatefulWidget {
  final ApiClient api;
  final Animal? animal;
  const _AnimalSheet({required this.api, this.animal});

  @override
  State<_AnimalSheet> createState() => _AnimalSheetState();
}

class _AnimalSheetState extends State<_AnimalSheet> {
  final _formKey = GlobalKey<FormState>();
  final _name = TextEditingController();
  final _breed = TextEditingController();
  String _species = 'chicken';
  bool _active = true;
  bool _saving = false;

  bool get _editing => widget.animal != null;

  @override
  void initState() {
    super.initState();
    final a = widget.animal;
    if (a != null) {
      _name.text = a.name;
      _breed.text = a.breed;
      _species = a.species;
      _active = a.active;
    }
  }

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
      if (_editing) {
        await widget.api.updateAnimal(
          widget.animal!.id,
          name: _name.text.trim(),
          species: _species,
          breed: _breed.text.trim(),
          active: _active,
        );
      } else {
        await widget.api.createAnimal(
          name: _name.text.trim(),
          species: _species,
          breed: _breed.text.trim(),
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
            Text(_editing ? 'Edit animal' : 'New animal',
                style: Theme.of(context).textTheme.titleLarge),
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
            if (_editing)
              SwitchListTile(
                contentPadding: EdgeInsets.zero,
                title: Text(_active ? 'Active' : 'Retired'),
                value: _active,
                onChanged: (v) => setState(() => _active = v),
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
                      : Text(_editing ? 'Save' : 'Add'),
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }
}
