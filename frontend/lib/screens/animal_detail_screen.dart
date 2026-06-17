import 'package:flutter/material.dart';
import 'package:intl/intl.dart';

import '../api/api_client.dart';
import '../models/animal.dart';
import '../models/care_task.dart';
import '../models/log_entry.dart';
import '../models/weight_record.dart';
import '../services/notification_service.dart';
import '../util/animal_display.dart';
import '../widgets/animal_sheet.dart';
import '../widgets/care_task_card.dart';
import '../widgets/task_sheet.dart';

/// The note types a person writes by hand (task_completed entries are system-made).
const List<List<String>> noteTypes = [
  ['general', 'General'],
  ['health', 'Health'],
  ['feeding', 'Feeding'],
  ['breeding', 'Breeding'],
];

const Map<String, Color> typeColors = {
  'general': Color(0xFF00796B),
  'health': Color(0xFFFF3B30),
  'feeding': Color(0xFFFF9500),
  'breeding': Color(0xFFAF52DE),
  'task_completed': Color(0xFF8E8E93),
};

class _Filter {
  final String key;
  final String label;
  final String? types;
  const _Filter(this.key, this.label, this.types);
}

/// Chip filters over the journal. "Notes" hides routine task completions.
const List<_Filter> _filters = [
  _Filter('notes', 'Notes', 'general,health,feeding,breeding'),
  _Filter('health', 'Health', 'health'),
  _Filter('feeding', 'Feeding', 'feeding'),
  _Filter('breeding', 'Breeding', 'breeding'),
  _Filter('all', 'Everything', null),
];

/// One animal: who they are plus their journal (health notes, treatments, …).
class AnimalDetailScreen extends StatefulWidget {
  final int animalId;
  const AnimalDetailScreen({super.key, required this.animalId});

  @override
  State<AnimalDetailScreen> createState() => _AnimalDetailScreenState();
}

class _AnimalDetailScreenState extends State<AnimalDetailScreen> {
  final ApiClient _api = ApiClient();
  Animal? _animal;
  String? _animalError;
  final List<LogEntry> _entries = [];
  bool _logLoading = true;
  String? _logError;
  bool _hasMore = false;
  int _page = 1;
  String _filter = 'notes';
  List<CareTask> _tasks = [];
  bool _tasksLoading = true;
  String? _tasksError;
  List<WeightRecord> _weights = [];
  bool _weightsLoading = true;
  List<LogEntry> _withdrawals = [];

  @override
  void initState() {
    super.initState();
    _loadAnimal();
    _loadTasks();
    _loadWeights();
    _loadWithdrawals();
    _loadLog(reset: true);
  }

  Future<void> _loadWeights() async {
    try {
      final weights = await _api.weights(widget.animalId);
      if (mounted) setState(() {
        _weights = weights;
        _weightsLoading = false;
      });
    } catch (_) {
      if (mounted) setState(() => _weightsLoading = false);
    }
  }

  /// Active medication withdrawal periods for this animal, for the food-safety
  /// banner. Pulled from the animal's recent health entries.
  Future<void> _loadWithdrawals() async {
    try {
      final page = await _api.logEntries(animal: widget.animalId, types: 'health', page: 1);
      if (mounted) {
        setState(() => _withdrawals = page.entries.where((e) => e.withdrawalActive).toList());
      }
    } catch (_) {
      // Non-essential; no banner if it can't load.
    }
  }

  Future<void> _loadAnimal() async {
    try {
      final animal = await _api.animal(widget.animalId);
      if (mounted) setState(() => _animal = animal);
    } catch (e) {
      if (mounted) setState(() => _animalError = '$e');
    }
  }

  Future<void> _loadTasks() async {
    try {
      final tasks = await _api.dashboard(animal: widget.animalId);
      if (!mounted) return;
      setState(() {
        _tasks = tasks;
        _tasksLoading = false;
        _tasksError = null;
      });
    } catch (e) {
      if (!mounted) return;
      setState(() {
        _tasksError = '$e';
        _tasksLoading = false;
      });
    }
  }

  Future<void> _completeTask(CareTask task) async {
    try {
      await _api.completeTask(task.id);
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('Marked "${task.name}" done'),
          action: SnackBarAction(label: 'Undo', onPressed: () => _undoTask(task)),
        ),
      );
      _loadTasks();
      _loadLog(reset: true); // completion lands in the journal too
      syncReminders(_api); // due date moved — refresh scheduled reminders
    } catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text('Failed: $e')));
    }
  }

  Future<void> _undoTask(CareTask task) async {
    try {
      await _api.uncompleteTask(task.id);
      _loadTasks();
      _loadLog(reset: true); // the completion entry is removed from the journal
      syncReminders(_api); // schedule restored — refresh reminders
    } catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text('Failed: $e')));
    }
  }

  Future<void> _addOrEditTask([CareTask? task]) async {
    final changed = await showModalBottomSheet<bool>(
      context: context,
      isScrollControlled: true,
      builder: (_) => TaskSheet(api: _api, task: task, defaultAnimalId: widget.animalId),
    );
    if (changed == true) {
      _loadTasks();
      syncReminders(_api); // new/changed task may need a reminder
    }
  }

  String? get _types => _filters.firstWhere((f) => f.key == _filter).types;

  Future<void> _loadLog({required bool reset}) async {
    if (reset) {
      setState(() {
        _logLoading = true;
        _logError = null;
        _entries.clear();
        _page = 1;
        _hasMore = false;
      });
    }
    try {
      final page = await _api.logEntries(animal: widget.animalId, types: _types, page: _page);
      if (!mounted) return;
      setState(() {
        _entries.addAll(page.entries);
        _hasMore = page.hasMore;
        _logLoading = false;
      });
    } catch (e) {
      if (!mounted) return;
      setState(() {
        _logError = '$e';
        _logLoading = false;
      });
    }
  }

  void _loadMore() {
    _page += 1;
    _loadLog(reset: false);
  }

  Future<void> _editAnimal() async {
    final animal = _animal;
    if (animal == null) return;
    final changed = await showModalBottomSheet<bool>(
      context: context,
      isScrollControlled: true,
      builder: (_) => AnimalSheet(api: _api, animal: animal),
    );
    if (changed == true) _loadAnimal();
  }

  Future<void> _addOrEditNote([LogEntry? entry]) async {
    final changed = await showModalBottomSheet<bool>(
      context: context,
      isScrollControlled: true,
      builder: (_) => _LogEntrySheet(api: _api, animalId: widget.animalId, entry: entry),
    );
    if (changed == true) {
      _loadLog(reset: true);
      _loadWithdrawals(); // a health note may add/clear a withdrawal banner
    }
  }

  Future<void> _logWeight() async {
    final added = await showModalBottomSheet<bool>(
      context: context,
      isScrollControlled: true,
      builder: (_) => _WeightSheet(api: _api, animalId: widget.animalId),
    );
    if (added == true) _loadWeights();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: Text(_animal?.name ?? 'Animal')),
      floatingActionButton: FloatingActionButton.extended(
        onPressed: () => _addOrEditNote(),
        icon: const Icon(Icons.add),
        label: const Text('Note'),
      ),
      body: RefreshIndicator(
        onRefresh: () async {
          await _loadAnimal();
          await _loadTasks();
          await _loadWeights();
          await _loadWithdrawals();
          await _loadLog(reset: true);
        },
        child: ListView(
          physics: const AlwaysScrollableScrollPhysics(),
          padding: const EdgeInsets.symmetric(vertical: 8),
          children: [
            _header(context),
            for (final w in _withdrawals) _withdrawalBanner(context, w),
            _weightSection(context),
            _taskSection(context),
            _journal(context),
            const SizedBox(height: 80), // room for the FAB
          ],
        ),
      ),
    );
  }

  Widget _header(BuildContext context) {
    final theme = Theme.of(context);
    final animal = _animal;
    if (animal == null) {
      return Card(
        child: Padding(
          padding: const EdgeInsets.all(16),
          child: _animalError != null
              ? Text('Could not load: $_animalError')
              : const Center(
                  child: SizedBox(
                      width: 24, height: 24, child: CircularProgressIndicator(strokeWidth: 2))),
        ),
      );
    }
    final facts = [
      animal.speciesDisplay,
      animal.breed,
      ageLabel(animal.dateOfBirth),
    ].where((s) => s != null && s.isNotEmpty).join(' · ');
    return Card(
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Row(
          children: [
            if (animal.photo != null)
              ClipRRect(
                borderRadius: BorderRadius.circular(8),
                child: Image.network(animal.photo!, width: 56, height: 56, fit: BoxFit.cover),
              )
            else
              Text(speciesEmoji[animal.species] ?? '🐾', style: const TextStyle(fontSize: 36)),
            const SizedBox(width: 12),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(animal.name, style: theme.textTheme.titleLarge),
                  Text(facts, style: theme.textTheme.bodySmall),
                ],
              ),
            ),
            Chip(
              label: Text(animal.active ? 'Active' : 'Retired'),
              visualDensity: VisualDensity.compact,
              backgroundColor: animal.active
                  ? theme.colorScheme.secondaryContainer
                  : theme.colorScheme.surfaceContainerHighest,
            ),
            TextButton(onPressed: _editAnimal, child: const Text('Edit')),
          ],
        ),
      ),
    );
  }

  Widget _withdrawalBanner(BuildContext context, LogEntry entry) {
    final theme = Theme.of(context);
    final amber = Colors.orange.shade800;
    final until = entry.withdrawalUntil;
    final medicine = entry.medicine.isNotEmpty ? ' (${entry.medicine})' : '';
    return Card(
      color: amber.withValues(alpha: 0.10),
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Row(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Icon(Icons.no_food, color: amber, size: 20),
            const SizedBox(width: 10),
            Expanded(
              child: Text(
                "Don't eat eggs/meat from ${_animal?.name ?? 'this animal'} until "
                '${until != null ? DateFormat('d MMM y').format(until) : 'further notice'}'
                '$medicine.',
                style: theme.textTheme.bodyMedium?.copyWith(fontWeight: FontWeight.w600),
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _weightSection(BuildContext context) {
    final theme = Theme.of(context);
    final latest = _weights.isNotEmpty ? _weights.last : null;
    final previous = _weights.length > 1 ? _weights[_weights.length - 2] : null;
    final delta = latest != null && previous != null ? latest.weightKg - previous.weightKg : null;
    String kg(double v) =>
        v == v.roundToDouble() ? v.toStringAsFixed(0) : v.toStringAsFixed(2);
    final recent = _weights.reversed.take(6).toList();
    return Card(
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Expanded(child: Text('Weight', style: theme.textTheme.titleLarge)),
                FilledButton.tonalIcon(
                  onPressed: _logWeight,
                  icon: const Icon(Icons.add, size: 18),
                  label: const Text('Log weight'),
                ),
              ],
            ),
            const SizedBox(height: 8),
            if (_weightsLoading)
              const Padding(
                padding: EdgeInsets.all(16),
                child: Center(
                    child: SizedBox(
                        width: 24, height: 24, child: CircularProgressIndicator(strokeWidth: 2))),
              )
            else if (latest == null)
              Text('No weights logged yet.', style: theme.textTheme.bodyMedium)
            else ...[
              Row(
                crossAxisAlignment: CrossAxisAlignment.baseline,
                textBaseline: TextBaseline.alphabetic,
                children: [
                  Text('${kg(latest.weightKg)} kg',
                      style: theme.textTheme.headlineSmall
                          ?.copyWith(fontWeight: FontWeight.bold)),
                  const SizedBox(width: 8),
                  if (delta != null && delta != 0)
                    Text(
                      '${delta > 0 ? '▲' : '▼'} ${kg(delta.abs())} kg',
                      style: theme.textTheme.bodyMedium?.copyWith(
                        color: delta > 0 ? Colors.green.shade700 : Colors.orange.shade800,
                        fontWeight: FontWeight.w600,
                      ),
                    ),
                  const Spacer(),
                  Text(DateFormat('d MMM y').format(latest.date),
                      style: theme.textTheme.bodySmall),
                ],
              ),
              if (recent.length > 1)
                for (final w in recent.skip(1))
                  Padding(
                    padding: const EdgeInsets.only(top: 6),
                    child: Row(
                      children: [
                        Expanded(
                          child: Text(
                            '${DateFormat('d MMM y').format(w.date)}'
                            '${w.note.isNotEmpty ? ' · ${w.note}' : ''}',
                            style: theme.textTheme.bodySmall,
                          ),
                        ),
                        Text('${kg(w.weightKg)} kg', style: theme.textTheme.bodyMedium),
                      ],
                    ),
                  ),
            ],
          ],
        ),
      ),
    );
  }

  Widget _taskSection(BuildContext context) {
    final theme = Theme.of(context);
    return Card(
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Expanded(child: Text('Tasks', style: theme.textTheme.titleLarge)),
                FilledButton.tonalIcon(
                  onPressed: () => _addOrEditTask(),
                  icon: const Icon(Icons.add, size: 18),
                  label: const Text('Add task'),
                ),
              ],
            ),
            const SizedBox(height: 8),
            if (_tasksLoading)
              const Padding(
                padding: EdgeInsets.all(24),
                child: Center(
                    child: SizedBox(
                        width: 24, height: 24, child: CircularProgressIndicator(strokeWidth: 2))),
              )
            else if (_tasksError != null)
              Padding(
                padding: const EdgeInsets.symmetric(vertical: 12),
                child: Row(
                  children: [
                    Expanded(child: Text('Could not load the tasks: $_tasksError')),
                    TextButton(onPressed: _loadTasks, child: const Text('Retry')),
                  ],
                ),
              )
            else if (_tasks.isEmpty)
              Padding(
                padding: const EdgeInsets.all(16),
                child: Center(
                  child: Text(
                    'No tasks for ${_animal?.name ?? 'this animal'} yet — add the first one.',
                    style: theme.textTheme.bodyMedium,
                  ),
                ),
              )
            else
              for (final task in _tasks)
                CareTaskCard(
                  task: task,
                  onComplete: () => _completeTask(task),
                  onEdit: () => _addOrEditTask(task),
                ),
          ],
        ),
      ),
    );
  }

  Widget _journal(BuildContext context) {
    final theme = Theme.of(context);
    return Card(
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text('Journal', style: theme.textTheme.titleLarge),
            const SizedBox(height: 8),
            SingleChildScrollView(
              scrollDirection: Axis.horizontal,
              child: Row(
                children: [
                  for (final f in _filters) ...[
                    FilterChip(
                      label: Text(f.label),
                      selected: _filter == f.key,
                      onSelected: (_) {
                        setState(() => _filter = f.key);
                        _loadLog(reset: true);
                      },
                    ),
                    const SizedBox(width: 8),
                  ],
                ],
              ),
            ),
            const SizedBox(height: 8),
            if (_logLoading)
              const Padding(
                padding: EdgeInsets.all(24),
                child: Center(
                    child: SizedBox(
                        width: 24, height: 24, child: CircularProgressIndicator(strokeWidth: 2))),
              )
            else if (_logError != null)
              Padding(
                padding: const EdgeInsets.symmetric(vertical: 12),
                child: Row(
                  children: [
                    Expanded(child: Text('Could not load the journal: $_logError')),
                    TextButton(onPressed: () => _loadLog(reset: true), child: const Text('Retry')),
                  ],
                ),
              )
            else if (_entries.isEmpty)
              Padding(
                padding: const EdgeInsets.all(24),
                child: Center(
                  child: Text('Nothing in the journal yet — add the first note.',
                      style: theme.textTheme.bodyMedium),
                ),
              )
            else ...[
              for (final entry in _entries) _entryRow(context, entry),
              if (_hasMore)
                Center(
                  child: TextButton(onPressed: _loadMore, child: const Text('Load more')),
                ),
            ],
          ],
        ),
      ),
    );
  }

  Widget _entryRow(BuildContext context, LogEntry entry) {
    final theme = Theme.of(context);
    final color = typeColors[entry.entryType] ?? const Color(0xFF8E8E93);
    final meta = [
      DateFormat('d MMM y').format(entry.occurredOn),
      if (entry.createdByName != null) entry.createdByName!,
    ].join(' · ');
    return InkWell(
      onTap: entry.isSystem ? null : () => _addOrEditNote(entry),
      child: Padding(
        padding: const EdgeInsets.symmetric(vertical: 8),
        child: Row(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
              decoration: BoxDecoration(
                color: color.withValues(alpha: 0.10),
                borderRadius: BorderRadius.circular(8),
              ),
              child: Text(
                entry.entryTypeDisplay,
                style: TextStyle(color: color, fontSize: 12, fontWeight: FontWeight.w600),
              ),
            ),
            const SizedBox(width: 10),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(entry.note, style: theme.textTheme.bodyMedium),
                  Text(meta, style: theme.textTheme.bodySmall),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }
}

/// Add a journal note, or edit/delete an existing one when [entry] is given.
class _LogEntrySheet extends StatefulWidget {
  final ApiClient api;
  final int animalId;
  final LogEntry? entry;
  const _LogEntrySheet({required this.api, required this.animalId, this.entry});

  @override
  State<_LogEntrySheet> createState() => _LogEntrySheetState();
}

class _LogEntrySheetState extends State<_LogEntrySheet> {
  final _formKey = GlobalKey<FormState>();
  final _note = TextEditingController();
  final _medicine = TextEditingController();
  final _withdrawal = TextEditingController();
  String _type = 'general';
  DateTime _occurredOn = DateTime.now();
  bool _saving = false;

  bool get _editing => widget.entry != null;

  @override
  void initState() {
    super.initState();
    final entry = widget.entry;
    if (entry != null) {
      _note.text = entry.note;
      _type = entry.entryType;
      _occurredOn = entry.occurredOn;
      _medicine.text = entry.medicine;
      _withdrawal.text = entry.withdrawalDays?.toString() ?? '';
    }
  }

  @override
  void dispose() {
    _note.dispose();
    _medicine.dispose();
    _withdrawal.dispose();
    super.dispose();
  }

  Future<void> _save() async {
    if (!_formKey.currentState!.validate()) return;
    setState(() => _saving = true);
    // Medicine/withdrawal only apply to health entries.
    final isHealth = _type == 'health';
    final medicine = isHealth ? _medicine.text.trim() : '';
    final withdrawal =
        isHealth && _withdrawal.text.trim().isNotEmpty ? int.tryParse(_withdrawal.text.trim()) : null;
    try {
      if (_editing) {
        await widget.api.updateLogEntry(
          widget.entry!.id,
          entryType: _type,
          note: _note.text.trim(),
          occurredOn: _occurredOn,
          medicine: medicine,
          withdrawalDays: withdrawal,
        );
      } else {
        await widget.api.createLogEntry(
          entryType: _type,
          note: _note.text.trim(),
          animal: widget.animalId,
          occurredOn: _occurredOn,
          medicine: medicine,
          withdrawalDays: withdrawal,
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
    setState(() => _saving = true);
    try {
      await widget.api.deleteLogEntry(widget.entry!.id);
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
            Text(_editing ? 'Edit note' : 'New note',
                style: Theme.of(context).textTheme.titleLarge),
            const SizedBox(height: 12),
            DropdownButtonFormField<String>(
              initialValue: _type,
              decoration: const InputDecoration(labelText: 'Type', border: OutlineInputBorder()),
              items: [
                for (final t in noteTypes) DropdownMenuItem(value: t[0], child: Text(t[1])),
              ],
              onChanged: (v) => setState(() => _type = v ?? 'general'),
            ),
            const SizedBox(height: 12),
            TextFormField(
              controller: _note,
              autofocus: !_editing,
              maxLines: 3,
              minLines: 2,
              decoration: const InputDecoration(labelText: 'Note', border: OutlineInputBorder()),
              validator: (v) => (v == null || v.trim().isEmpty) ? 'Write a note' : null,
            ),
            if (_type == 'health') ...[
              const SizedBox(height: 12),
              TextFormField(
                controller: _medicine,
                decoration: const InputDecoration(
                  labelText: 'Medicine / treatment (optional)',
                  border: OutlineInputBorder(),
                ),
              ),
              const SizedBox(height: 12),
              TextFormField(
                controller: _withdrawal,
                keyboardType: TextInputType.number,
                decoration: const InputDecoration(
                  labelText: 'Egg/meat withdrawal (days, optional)',
                  helperText: "Days produce mustn't be eaten after treatment.",
                  border: OutlineInputBorder(),
                ),
                validator: (v) {
                  final text = v?.trim() ?? '';
                  if (text.isEmpty) return null;
                  final n = int.tryParse(text);
                  return (n == null || n < 0) ? 'Whole number of days' : null;
                },
              ),
            ],
            const SizedBox(height: 12),
            InkWell(
              onTap: () async {
                final picked = await showDatePicker(
                  context: context,
                  initialDate: _occurredOn,
                  firstDate: DateTime(DateTime.now().year - 5),
                  lastDate: DateTime.now(),
                );
                if (picked != null) setState(() => _occurredOn = picked);
              },
              child: InputDecorator(
                decoration: const InputDecoration(labelText: 'When', border: OutlineInputBorder()),
                child: Text(DateFormat('d MMM y').format(_occurredOn)),
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
    );
  }
}

/// Log a weight reading for an animal (date + kg + optional note).
class _WeightSheet extends StatefulWidget {
  final ApiClient api;
  final int animalId;
  const _WeightSheet({required this.api, required this.animalId});

  @override
  State<_WeightSheet> createState() => _WeightSheetState();
}

class _WeightSheetState extends State<_WeightSheet> {
  final _formKey = GlobalKey<FormState>();
  final _kg = TextEditingController();
  final _note = TextEditingController();
  DateTime _date = DateTime.now();
  bool _saving = false;

  @override
  void dispose() {
    _kg.dispose();
    _note.dispose();
    super.dispose();
  }

  Future<void> _save() async {
    if (!_formKey.currentState!.validate()) return;
    setState(() => _saving = true);
    try {
      await widget.api.createWeight(
        animal: widget.animalId,
        weightKg: double.parse(_kg.text.trim()),
        date: _date,
        note: _note.text.trim(),
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
            Text('Log weight', style: Theme.of(context).textTheme.titleLarge),
            const SizedBox(height: 12),
            TextFormField(
              controller: _kg,
              autofocus: true,
              keyboardType: const TextInputType.numberWithOptions(decimal: true),
              decoration: const InputDecoration(labelText: 'Weight (kg)', border: OutlineInputBorder()),
              validator: (v) {
                final text = v?.trim() ?? '';
                if (text.isEmpty) return 'Enter a weight';
                final n = double.tryParse(text);
                return (n == null || n < 0) ? 'Enter a number' : null;
              },
            ),
            const SizedBox(height: 12),
            InkWell(
              onTap: () async {
                final picked = await showDatePicker(
                  context: context,
                  initialDate: _date,
                  firstDate: DateTime(DateTime.now().year - 10),
                  lastDate: DateTime.now(),
                );
                if (picked != null) setState(() => _date = picked);
              },
              child: InputDecorator(
                decoration: const InputDecoration(labelText: 'When', border: OutlineInputBorder()),
                child: Text(DateFormat('d MMM y').format(_date)),
              ),
            ),
            const SizedBox(height: 12),
            TextFormField(
              controller: _note,
              decoration: const InputDecoration(labelText: 'Note (optional)', border: OutlineInputBorder()),
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
                      : const Text('Save'),
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }
}
