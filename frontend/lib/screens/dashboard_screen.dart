import 'package:flutter/material.dart';
import 'package:intl/intl.dart';

import '../api/api_client.dart';
import '../config.dart';
import '../models/animal.dart';
import '../models/care_task.dart';
import '../models/person.dart';
import '../services/notification_service.dart';
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
      syncReminders(_api); // due date moved — refresh scheduled reminders
    } catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text('Failed: $e')));
    }
  }

  Future<void> _addTask() async {
    final created = await showModalBottomSheet<bool>(
      context: context,
      isScrollControlled: true,
      builder: (_) => _TaskSheet(api: _api),
    );
    if (created == true) {
      _loadPeople();
      _refresh();
      syncReminders(_api); // new task may need a reminder
    }
  }

  Future<void> _editTask(CareTask task) async {
    final changed = await showModalBottomSheet<bool>(
      context: context,
      isScrollControlled: true,
      builder: (_) => _TaskSheet(api: _api, task: task),
    );
    if (changed == true) {
      _refresh();
      syncReminders(_api); // interval/assignee change — reschedule reminders
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
                      onEdit: () => _editTask(tasks[i]),
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

/// Bottom sheet to create a task, or to edit/delete one when [task] is given.
class _TaskSheet extends StatefulWidget {
  final ApiClient api;
  final CareTask? task;
  const _TaskSheet({required this.api, this.task});

  @override
  State<_TaskSheet> createState() => _TaskSheetState();
}

class _TaskSheetState extends State<_TaskSheet> {
  final _formKey = GlobalKey<FormState>();
  final _name = TextEditingController();
  final _interval = TextEditingController(text: '7');
  bool _repeats = true;
  DateTime _dueDate = DateTime.now();
  int? _animalId;
  int? _assigneeId;
  List<Animal> _animals = [];
  List<Person> _people = [];
  bool _animalsLoaded = false;
  bool _peopleLoaded = false;
  bool _saving = false;
  bool _deleting = false;

  bool get _editing => widget.task != null;

  @override
  void initState() {
    super.initState();
    final t = widget.task;
    if (t != null) {
      _name.text = t.name;
      _interval.text = t.recurrenceIntervalDays.toString();
      _animalId = t.animal;
      _assigneeId = t.assignee;
      if (t.isOneOff) {
        _repeats = false;
        _dueDate = t.dueDate!;
      }
    }
    _loadAnimals();
    _loadPeople();
  }

  Future<void> _loadAnimals() async {
    try {
      final animals = await widget.api.animals();
      if (mounted) {
        setState(() {
          _animals = animals;
          _animalsLoaded = true;
        });
      }
    } catch (_) {
      if (mounted) setState(() => _animalsLoaded = true);
    }
  }

  Future<void> _loadPeople() async {
    try {
      final people = await widget.api.people();
      if (!mounted) return;
      setState(() {
        _people = people;
        // Default "me" only when creating; an edit keeps the task's assignee.
        if (!_editing && AppConfig.myPersonId != null) {
          _assigneeId = AppConfig.myPersonId;
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

  /// A dropdown's value must match one of its items, so drop an id that isn't
  /// in the loaded list (e.g. an inactive animal) back to "none".
  int? _validId(int? id, Iterable<int> available) =>
      (id != null && available.contains(id)) ? id : null;

  Future<void> _pickDate() async {
    final picked = await showDatePicker(
      context: context,
      initialDate: _dueDate,
      firstDate: DateTime(DateTime.now().year - 1),
      lastDate: DateTime(DateTime.now().year + 5),
    );
    if (picked != null) setState(() => _dueDate = picked);
  }

  Future<void> _save() async {
    if (!_formKey.currentState!.validate()) return;
    setState(() => _saving = true);
    final name = _name.text.trim();
    final interval =
        _repeats ? int.parse(_interval.text.trim()) : (widget.task?.recurrenceIntervalDays ?? 7);
    final dueDate = _repeats ? null : _dueDate;
    try {
      if (_editing) {
        await widget.api.updateCareTask(
          widget.task!.id,
          name: name,
          recurrenceIntervalDays: interval,
          dueDate: dueDate,
          animal: _animalId,
          assignee: _assigneeId,
        );
      } else {
        await widget.api.createCareTask(
          name: name,
          recurrenceIntervalDays: interval,
          dueDate: dueDate,
          animal: _animalId,
          assignee: _assigneeId,
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
    setState(() => _deleting = true);
    try {
      await widget.api.deleteCareTask(widget.task!.id);
      if (mounted) Navigator.of(context).pop(true);
    } catch (e) {
      if (mounted) {
        setState(() => _deleting = false);
        ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text('Failed: $e')));
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    final bottomInset = MediaQuery.of(context).viewInsets.bottom;
    final busy = _saving || _deleting;
    return Padding(
      padding: EdgeInsets.fromLTRB(16, 16, 16, 16 + bottomInset),
      child: Form(
        key: _formKey,
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(_editing ? 'Edit task' : 'New care task',
                style: Theme.of(context).textTheme.titleLarge),
            const SizedBox(height: 12),
            TextFormField(
              controller: _name,
              decoration: const InputDecoration(labelText: 'Task name', border: OutlineInputBorder()),
              validator: (v) => (v == null || v.trim().isEmpty) ? 'Required' : null,
            ),
            const SizedBox(height: 12),
            SegmentedButton<bool>(
              showSelectedIcon: false,
              segments: const [
                ButtonSegment(value: true, label: Text('Repeats')),
                ButtonSegment(value: false, label: Text('One-off')),
              ],
              selected: {_repeats},
              onSelectionChanged: (s) => setState(() => _repeats = s.first),
            ),
            const SizedBox(height: 12),
            if (_repeats)
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
              )
            else
              InkWell(
                onTap: _pickDate,
                child: InputDecorator(
                  decoration: const InputDecoration(
                    labelText: 'Due date',
                    border: OutlineInputBorder(),
                  ),
                  child: Text(DateFormat('d MMM y').format(_dueDate)),
                ),
              ),
            const SizedBox(height: 12),
            if (_peopleLoaded)
              DropdownButtonFormField<int?>(
                initialValue: _validId(_assigneeId, _people.map((p) => p.id)),
                decoration: const InputDecoration(
                  labelText: 'Assign to',
                  border: OutlineInputBorder(),
                ),
                items: [
                  const DropdownMenuItem<int?>(value: null, child: Text('Anyone')),
                  for (final p in _people)
                    DropdownMenuItem<int?>(value: p.id, child: Text(p.name)),
                ],
                onChanged: (v) => setState(() => _assigneeId = v),
              )
            else
              const InputDecorator(
                decoration: InputDecoration(labelText: 'Assign to', border: OutlineInputBorder()),
                child: Text('Loading…'),
              ),
            const SizedBox(height: 12),
            if (_animalsLoaded)
              DropdownButtonFormField<int?>(
                initialValue: _validId(_animalId, _animals.map((a) => a.id)),
                decoration: const InputDecoration(
                  labelText: 'Animal (optional)',
                  border: OutlineInputBorder(),
                ),
                items: [
                  const DropdownMenuItem<int?>(value: null, child: Text('Whole holding')),
                  for (final a in _animals)
                    DropdownMenuItem<int?>(value: a.id, child: Text(a.name)),
                ],
                onChanged: (v) => setState(() => _animalId = v),
              )
            else
              const InputDecorator(
                decoration:
                    InputDecoration(labelText: 'Animal (optional)', border: OutlineInputBorder()),
                child: Text('Loading…'),
              ),
            const SizedBox(height: 16),
            Row(
              children: [
                if (_editing)
                  TextButton(
                    onPressed: busy ? null : _delete,
                    style: TextButton.styleFrom(
                      foregroundColor: Theme.of(context).colorScheme.error,
                    ),
                    child: _deleting
                        ? const SizedBox(
                            width: 18, height: 18, child: CircularProgressIndicator(strokeWidth: 2))
                        : const Text('Delete'),
                  ),
                const Spacer(),
                TextButton(
                  onPressed: busy ? null : () => Navigator.of(context).pop(false),
                  child: const Text('Cancel'),
                ),
                const SizedBox(width: 8),
                FilledButton(
                  onPressed: busy ? null : _save,
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
