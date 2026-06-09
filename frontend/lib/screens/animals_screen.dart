import 'package:flutter/material.dart';

import '../api/api_client.dart';
import '../models/animal.dart';
import '../util/animal_display.dart';
import '../widgets/animal_sheet.dart';
import '../widgets/async_view.dart';
import 'animal_detail_screen.dart';

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
      builder: (_) => AnimalSheet(api: _api),
    );
    if (created == true) _refresh();
  }

  Future<void> _open(Animal animal) async {
    await Navigator.of(context).push(MaterialPageRoute<void>(
      builder: (_) => AnimalDetailScreen(animalId: animal.id),
    ));
    _refresh(); // the animal may have been edited on the detail screen
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
                    Text(speciesEmoji[g.code] ?? '🐾', style: const TextStyle(fontSize: 40)),
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
              onOpen: () => _open(a),
              onDelete: () => _confirmDelete(a),
            ),
      ],
    );
  }
}

class _AnimalRow extends StatelessWidget {
  final Animal animal;
  final VoidCallback onOpen;
  final VoidCallback onDelete;
  const _AnimalRow({required this.animal, required this.onOpen, required this.onDelete});

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final facts = [ageLabel(animal.dateOfBirth), animal.breed]
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
                onTap: onOpen,
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
