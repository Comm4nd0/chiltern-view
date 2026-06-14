import 'package:flutter/material.dart';
import 'package:intl/intl.dart';

import '../api/api_client.dart';
import '../config.dart';
import '../models/animal.dart';
import '../models/care_task.dart';
import '../models/person.dart';

/// Bottom sheet to create a task, or to edit/delete one when [task] is given.
/// [defaultAnimalId] pre-selects the animal when adding from an animal's screen.
/// Pops `true` when something changed (created / saved / deleted).
class TaskSheet extends StatefulWidget {
  final ApiClient api;
  final CareTask? task;
  final int? defaultAnimalId;
  const TaskSheet({super.key, required this.api, this.task, this.defaultAnimalId});

  @override
  State<TaskSheet> createState() => _TaskSheetState();
}

class _TaskSheetState extends State<TaskSheet> {
  final _formKey = GlobalKey<FormState>();
  final _name = TextEditingController();
  final _interval = TextEditingController(text: '7');
  final _timesPerDay = TextEditingController(text: '1');
  bool _repeats = true;
  DateTime _dueDate = DateTime.now();
  TimeOfDay? _dueTime; // null = anytime that day
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
      _timesPerDay.text = t.timesPerDay.toString();
      _dueTime = t.dueTime;
      _animalId = t.animal;
      _assigneeId = t.assignee;
      if (t.isOneOff) {
        _repeats = false;
        _dueDate = t.dueDate!;
      }
    } else {
      _animalId = widget.defaultAnimalId;
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
    _timesPerDay.dispose();
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

  Future<void> _pickTime() async {
    final picked = await showTimePicker(
      context: context,
      initialTime: _dueTime ?? const TimeOfDay(hour: 7, minute: 30),
    );
    if (picked != null) setState(() => _dueTime = picked);
  }

  Future<void> _save() async {
    if (!_formKey.currentState!.validate()) return;
    setState(() => _saving = true);
    final name = _name.text.trim();
    final interval =
        _repeats ? int.parse(_interval.text.trim()) : (widget.task?.recurrenceIntervalDays ?? 7);
    // A clock-timed task happens once at that time; "times a day" only applies to
    // timeless repeating tasks.
    final dueTime = _repeats ? _dueTime : null;
    final timesPerDay = (_repeats && dueTime == null) ? int.parse(_timesPerDay.text.trim()) : 1;
    final dueDate = _repeats ? null : _dueDate;
    try {
      if (_editing) {
        await widget.api.updateCareTask(
          widget.task!.id,
          name: name,
          recurrenceIntervalDays: interval,
          timesPerDay: timesPerDay,
          dueDate: dueDate,
          dueTime: dueTime,
          animal: _animalId,
          assignee: _assigneeId,
        );
      } else {
        await widget.api.createCareTask(
          name: name,
          recurrenceIntervalDays: interval,
          timesPerDay: timesPerDay,
          dueDate: dueDate,
          dueTime: dueTime,
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

  String? _positiveInt(String? v) {
    final n = int.tryParse(v?.trim() ?? '');
    return (n == null || n <= 0) ? 'Enter a positive number' : null;
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
            if (_repeats) ...[
              Row(
                children: [
                  Expanded(
                    child: TextFormField(
                      controller: _interval,
                      keyboardType: TextInputType.number,
                      decoration: const InputDecoration(
                        labelText: 'Repeat every (days)',
                        border: OutlineInputBorder(),
                      ),
                      validator: _positiveInt,
                    ),
                  ),
                  const SizedBox(width: 12),
                  Expanded(
                    child: InkWell(
                      onTap: _pickTime,
                      child: InputDecorator(
                        decoration: InputDecoration(
                          labelText: 'Time (optional)',
                          border: const OutlineInputBorder(),
                          suffixIcon: _dueTime != null
                              ? IconButton(
                                  icon: const Icon(Icons.clear),
                                  onPressed: () => setState(() => _dueTime = null),
                                )
                              : const Icon(Icons.schedule),
                        ),
                        child: Text(_dueTime != null ? _dueTime!.format(context) : 'Any time'),
                      ),
                    ),
                  ),
                ],
              ),
              // A clock time means "once at that time", so times-a-day only shows
              // for timeless tasks (e.g. collect the eggs, sometime today).
              if (_dueTime == null) ...[
                const SizedBox(height: 12),
                TextFormField(
                  controller: _timesPerDay,
                  keyboardType: TextInputType.number,
                  decoration: const InputDecoration(
                    labelText: 'Times a day',
                    helperText: 'e.g. 4 feeds a day',
                    border: OutlineInputBorder(),
                  ),
                  validator: _positiveInt,
                ),
              ],
            ] else
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
