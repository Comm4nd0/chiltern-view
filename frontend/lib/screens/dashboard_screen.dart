import 'package:flutter/material.dart';

import '../api/api_client.dart';
import '../config.dart';
import '../models/animal.dart';
import '../models/care_task.dart';
import '../models/person.dart';
import '../widgets/async_view.dart';
import '../widgets/care_task_card.dart';

/// "What needs doing" — care tasks ranked by overdue-ness (most overdue first),
/// optionally filtered to a person.
class DashboardScreen extends StatefulWidget {
  const DashboardScreen({super.key});

  @override
  State<DashboardScreen> createState() => _DashboardScreenState();
}

class _DashboardScreenState extends State<DashboardScreen> {
  final ApiClient _api = ApiClient();
  late Future<List<CareTask>> _future;
  List<Person> _people = [];

  /// null = everyone, 'unassigned', or a person id as a string.
  String? _filter;

  @override
  void initState() {
    super.initState();
    // Default to "my" tasks if this device has been assigned a person.
    _filter = AppConfig.myPersonId?.toString();
    _future = _api.dashboard(assignee: _filter);
    _loadPeople();
  }

  Future<void> _loadPeople() async {
    try {
      final people = await _api.people();
      if (mounted) setState(() => _people = people);
    } catch (_) {
      // The filter bar just stays hidden if people can't be loaded.
    }
  }

  void _refresh() => setState(() => _future = _api.dashboard(assignee: _filter));

  void _setFilter(String? filter) {
    setState(() {
      _filter = filter;
      _future = _api.dashboard(assignee: filter);
    });
  }

  Future<void> _complete(CareTask task) async {
    try {
      await _api.completeTask(task.id);
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Marked "${task.name}" done')),
      );
      _refresh();
    } catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text('Failed: $e')));
    }
  }

  Future<void> _addTask() async {
    final created = await showModalBottomSheet<bool>(
      context: context,
      isScrollControlled: true,
      builder: (_) => _AddTaskSheet(api: _api),
    );
    if (created == true) {
      _loadPeople();
      _refresh();
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      floatingActionButton: FloatingActionButton.extended(
        onPressed: _addTask,
        icon: const Icon(Icons.add),
        label: const Text('Task'),
      ),
      body: Column(
        children: [
          _FilterBar(
            people: _people,
            selected: _filter,
            mePersonId: AppConfig.myPersonId,
            onSelected: _setFilter,
          ),
          Expanded(
            child: RefreshIndicator(
              onRefresh: () async => _refresh(),
              child: AsyncView<List<CareTask>>(
                future: _future,
                onRetry: _refresh,
                builder: (context, tasks) {
                  if (tasks.isEmpty) {
                    return ListView(
                      children: const [
                        SizedBox(height: 120),
                        Center(child: Text('Nothing on the list here.')),
                      ],
                    );
                  }
                  return ListView.builder(
                    physics: const AlwaysScrollableScrollPhysics(),
                    padding: const EdgeInsets.symmetric(vertical: 8),
                    itemCount: tasks.length,
                    itemBuilder: (context, i) => CareTaskCard(
                      task: tasks[i],
                      onComplete: () => _complete(tasks[i]),
                    ),
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

class _FilterBar extends StatelessWidget {
  final List<Person> people;
  final String? selected;
  final int? mePersonId;
  final ValueChanged<String?> onSelected;

  const _FilterBar({
    required this.people,
    required this.selected,
    required this.mePersonId,
    required this.onSelected,
  });

  @override
  Widget build(BuildContext context) {
    if (people.isEmpty) return const SizedBox.shrink();
    return SizedBox(
      height: 52,
      child: ListView(
        scrollDirection: Axis.horizontal,
        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
        children: [
          _chip(label: 'Everyone', value: null),
          for (final p in people)
            _chip(
              label: p.id == mePersonId ? '${p.name} (me)' : p.name,
              value: p.id.toString(),
            ),
          _chip(label: 'Unassigned', value: 'unassigned'),
        ],
      ),
    );
  }

  Widget _chip({required String label, required String? value}) {
    return Padding(
      padding: const EdgeInsets.only(right: 8),
      child: ChoiceChip(
        label: Text(label),
        selected: selected == value,
        onSelected: (_) => onSelected(value),
      ),
    );
  }
}

class _AddTaskSheet extends StatefulWidget {
  final ApiClient api;
  const _AddTaskSheet({required this.api});

  @override
  State<_AddTaskSheet> createState() => _AddTaskSheetState();
}

class _AddTaskSheetState extends State<_AddTaskSheet> {
  final _formKey = GlobalKey<FormState>();
  final _name = TextEditingController();
  final _interval = TextEditingController(text: '7');
  Animal? _animal;
  Person? _assignee;
  late Future<List<Animal>> _animals;
  List<Person> _people = [];
  bool _peopleLoaded = false;
  bool _saving = false;

  @override
  void initState() {
    super.initState();
    _animals = widget.api.animals();
    _loadPeople();
  }

  Future<void> _loadPeople() async {
    try {
      final people = await widget.api.people();
      if (!mounted) return;
      setState(() {
        _people = people;
        if (AppConfig.myPersonId != null) {
          final mine = people.where((p) => p.id == AppConfig.myPersonId);
          _assignee = mine.isNotEmpty ? mine.first : null;
        }
        _peopleLoaded = true;
      });
    } catch (_) {
      if (mounted) setState(() => _peopleLoaded = true);
    }
  }

  @override
  void dispose() {
    _name.dispose();
    _interval.dispose();
    super.dispose();
  }

  Future<void> _save() async {
    if (!_formKey.currentState!.validate()) return;
    setState(() => _saving = true);
    try {
      await widget.api.createCareTask(
        name: _name.text.trim(),
        recurrenceIntervalDays: int.parse(_interval.text.trim()),
        animal: _animal?.id,
        assignee: _assignee?.id,
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
            Text('New care task', style: Theme.of(context).textTheme.titleLarge),
            const SizedBox(height: 12),
            TextFormField(
              controller: _name,
              decoration: const InputDecoration(labelText: 'Task name', border: OutlineInputBorder()),
              validator: (v) => (v == null || v.trim().isEmpty) ? 'Required' : null,
            ),
            const SizedBox(height: 12),
            TextFormField(
              controller: _interval,
              keyboardType: TextInputType.number,
              decoration: const InputDecoration(
                labelText: 'Repeat every (days)',
                border: OutlineInputBorder(),
              ),
              validator: (v) {
                final n = int.tryParse(v?.trim() ?? '');
                return (n == null || n <= 0) ? 'Enter a positive number' : null;
              },
            ),
            const SizedBox(height: 12),
            if (_peopleLoaded)
              DropdownButtonFormField<Person?>(
                initialValue: _assignee,
                decoration: const InputDecoration(
                  labelText: 'Assign to',
                  border: OutlineInputBorder(),
                ),
                items: [
                  const DropdownMenuItem<Person?>(value: null, child: Text('Anyone')),
                  for (final p in _people)
                    DropdownMenuItem<Person?>(value: p, child: Text(p.name)),
                ],
                onChanged: (v) => setState(() => _assignee = v),
              )
            else
              const InputDecorator(
                decoration: InputDecoration(labelText: 'Assign to', border: OutlineInputBorder()),
                child: Text('Loading…'),
              ),
            const SizedBox(height: 12),
            FutureBuilder<List<Animal>>(
              future: _animals,
              builder: (context, snapshot) {
                final animals = snapshot.data ?? const <Animal>[];
                return DropdownButtonFormField<Animal?>(
                  initialValue: _animal,
                  decoration: const InputDecoration(
                    labelText: 'Animal (optional)',
                    border: OutlineInputBorder(),
                  ),
                  items: [
                    const DropdownMenuItem<Animal?>(value: null, child: Text('Whole holding')),
                    for (final a in animals)
                      DropdownMenuItem<Animal?>(value: a, child: Text(a.name)),
                  ],
                  onChanged: (v) => setState(() => _animal = v),
                );
              },
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
