import 'package:flutter/material.dart';

import '../api/api_client.dart';
import '../config.dart';
import '../models/care_task.dart';
import '../models/person.dart';
import '../services/notification_service.dart';
import '../widgets/async_view.dart';
import '../widgets/care_task_card.dart';
import '../widgets/task_sheet.dart';

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
        SnackBar(
          content: Text('Marked "${task.name}" done'),
          action: SnackBarAction(label: 'Undo', onPressed: () => _undo(task)),
        ),
      );
      _refresh();
      syncReminders(_api); // due date moved — refresh scheduled reminders
    } catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text('Failed: $e')));
    }
  }

  Future<void> _undo(CareTask task) async {
    try {
      await _api.uncompleteTask(task.id);
      _refresh();
      syncReminders(_api); // schedule restored — refresh reminders
    } catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text('Failed: $e')));
    }
  }

  Future<void> _addTask() async {
    final created = await showModalBottomSheet<bool>(
      context: context,
      isScrollControlled: true,
      builder: (_) => TaskSheet(api: _api),
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
      builder: (_) => TaskSheet(api: _api, task: task),
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
