import 'package:flutter/material.dart';

import '../api/api_client.dart';
import '../auth_state.dart';
import '../config.dart';
import '../models/person.dart';
import '../services/notification_service.dart';
import 'supplies_screen.dart';

class SettingsScreen extends StatefulWidget {
  const SettingsScreen({super.key});

  @override
  State<SettingsScreen> createState() => _SettingsScreenState();
}

class _SettingsScreenState extends State<SettingsScreen> {
  final ApiClient _api = ApiClient();
  late final TextEditingController _url = TextEditingController(text: AppConfig.baseUrl);
  final TextEditingController _newPerson = TextEditingController();

  late Future<List<Person>> _people;
  int? _myPersonId;
  bool _addingPerson = false;
  bool _remindersEnabled = true;
  TimeOfDay _reminderTime = const TimeOfDay(hour: 8, minute: 0);

  @override
  void initState() {
    super.initState();
    _myPersonId = AppConfig.myPersonId;
    _remindersEnabled = AppConfig.remindersEnabled;
    _reminderTime = TimeOfDay(hour: AppConfig.reminderHour, minute: AppConfig.reminderMinute);
    _people = _api.people();
  }

  @override
  void dispose() {
    _url.dispose();
    _newPerson.dispose();
    super.dispose();
  }

  void _reloadPeople() => setState(() => _people = _api.people());

  Future<void> _saveUrl() async {
    await AppConfig.setBaseUrl(_url.text);
    if (!mounted) return;
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(content: Text('API set to ${AppConfig.baseUrl}')),
    );
    _reloadPeople();
  }

  Future<void> _addPerson() async {
    final name = _newPerson.text.trim();
    if (name.isEmpty) return;
    setState(() => _addingPerson = true);
    try {
      await _api.createPerson(name);
      _newPerson.clear();
      _reloadPeople();
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text('Failed: $e')));
      }
    } finally {
      if (mounted) setState(() => _addingPerson = false);
    }
  }

  Future<void> _setMe(int? id) async {
    await AppConfig.setMyPersonId(id);
    setState(() => _myPersonId = id);
    await syncReminders(_api); // reminders follow the device's person
  }

  Future<void> _toggleReminders(bool value) async {
    setState(() => _remindersEnabled = value);
    await AppConfig.setRemindersEnabled(value);
    if (value) await NotificationService.instance.requestPermissions();
    await syncReminders(_api);
  }

  Future<void> _pickTime() async {
    final picked = await showTimePicker(context: context, initialTime: _reminderTime);
    if (picked == null) return;
    setState(() => _reminderTime = picked);
    await AppConfig.setReminderTime(picked.hour, picked.minute);
    await syncReminders(_api);
  }

  Future<void> _confirmDelete(Person person) async {
    final yes = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: Text('Remove ${person.name}?'),
        content: const Text('Their tasks stay but become unassigned.'),
        actions: [
          TextButton(onPressed: () => Navigator.of(context).pop(false), child: const Text('Cancel')),
          FilledButton(onPressed: () => Navigator.of(context).pop(true), child: const Text('Remove')),
        ],
      ),
    );
    if (yes != true) return;
    try {
      await _api.deletePerson(person.id);
      if (_myPersonId == person.id) await _setMe(null);
      _reloadPeople();
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text('Failed: $e')));
      }
    }
  }

  Future<void> _signOut() async {
    await _api.logout();
    signedIn.value = false; // RootGate swaps in the login screen
    if (mounted) Navigator.of(context).pop(); // pop Settings to reveal it
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return Scaffold(
      appBar: AppBar(title: const Text('Settings')),
      body: ListView(
        padding: const EdgeInsets.all(16),
        children: [
          Text('Account', style: theme.textTheme.titleMedium),
          const SizedBox(height: 8),
          if (AppConfig.authUsername != null)
            Text('Signed in as ${AppConfig.authUsername}.', style: theme.textTheme.bodyMedium),
          const SizedBox(height: 8),
          Align(
            alignment: Alignment.centerLeft,
            child: OutlinedButton.icon(
              onPressed: _signOut,
              icon: const Icon(Icons.logout),
              label: const Text('Sign out'),
            ),
          ),
          const Divider(height: 32),
          Text('Holding', style: theme.textTheme.titleMedium),
          const SizedBox(height: 8),
          Align(
            alignment: Alignment.centerLeft,
            child: OutlinedButton.icon(
              onPressed: () => Navigator.of(context).push(
                MaterialPageRoute<void>(builder: (_) => const SuppliesScreen()),
              ),
              icon: const Icon(Icons.inventory_2_outlined),
              label: const Text('Feed & supplies'),
            ),
          ),
          const Divider(height: 32),
          Text('API server', style: theme.textTheme.titleMedium),
          const SizedBox(height: 8),
          TextField(
            controller: _url,
            decoration: const InputDecoration(
              labelText: 'Base URL',
              hintText: 'http://luma001:8000/api',
              border: OutlineInputBorder(),
            ),
            keyboardType: TextInputType.url,
            autocorrect: false,
          ),
          const SizedBox(height: 8),
          Align(
            alignment: Alignment.centerRight,
            child: FilledButton(onPressed: _saveUrl, child: const Text('Save')),
          ),
          const Divider(height: 32),
          Text('People', style: theme.textTheme.titleMedium),
          const SizedBox(height: 4),
          Text(
            'Add yourself and one other, then tap the person icon to mark which '
            'one is you on this device.',
            style: theme.textTheme.bodySmall,
          ),
          const SizedBox(height: 8),
          FutureBuilder<List<Person>>(
            future: _people,
            builder: (context, snapshot) {
              if (snapshot.connectionState != ConnectionState.done) {
                return const Padding(
                  padding: EdgeInsets.symmetric(vertical: 8),
                  child: LinearProgressIndicator(),
                );
              }
              if (snapshot.hasError) {
                return Text("Couldn't load people: ${snapshot.error}",
                    style: theme.textTheme.bodySmall);
              }
              final people = snapshot.data ?? const <Person>[];
              if (people.isEmpty) {
                return const Padding(
                  padding: EdgeInsets.symmetric(vertical: 8),
                  child: Text('No people yet.'),
                );
              }
              return Column(
                children: [
                  for (final p in people)
                    ListTile(
                      contentPadding: EdgeInsets.zero,
                      leading: IconButton(
                        tooltip: 'Mark as me on this device',
                        icon: Icon(
                          p.id == _myPersonId ? Icons.person : Icons.person_outline,
                          color: p.id == _myPersonId ? theme.colorScheme.primary : null,
                        ),
                        onPressed: () => _setMe(p.id == _myPersonId ? null : p.id),
                      ),
                      title: Text(p.name),
                      subtitle: p.id == _myPersonId ? const Text('This device') : null,
                      trailing: IconButton(
                        icon: const Icon(Icons.delete_outline),
                        onPressed: () => _confirmDelete(p),
                      ),
                    ),
                ],
              );
            },
          ),
          const SizedBox(height: 8),
          Row(
            children: [
              Expanded(
                child: TextField(
                  controller: _newPerson,
                  decoration: const InputDecoration(
                    labelText: 'Add a person',
                    border: OutlineInputBorder(),
                  ),
                  onSubmitted: (_) => _addPerson(),
                ),
              ),
              const SizedBox(width: 8),
              IconButton.filled(
                onPressed: _addingPerson ? null : _addPerson,
                icon: const Icon(Icons.add),
              ),
            ],
          ),
          const Divider(height: 32),
          Text('Reminders', style: theme.textTheme.titleMedium),
          const SizedBox(height: 4),
          Text(
            "On-device reminders for your tasks: a morning digest plus a ping on "
            "each task's due date. Mark which person is you (above) so this "
            'device knows whose tasks to remind you about.',
            style: theme.textTheme.bodySmall,
          ),
          SwitchListTile(
            contentPadding: EdgeInsets.zero,
            title: const Text('Task reminders'),
            value: _remindersEnabled,
            onChanged: _toggleReminders,
          ),
          ListTile(
            contentPadding: EdgeInsets.zero,
            enabled: _remindersEnabled,
            leading: const Icon(Icons.schedule),
            title: const Text('Reminder time'),
            subtitle: Text(_reminderTime.format(context)),
            trailing: const Icon(Icons.edit_outlined),
            onTap: _remindersEnabled ? _pickTime : null,
          ),
          if (_remindersEnabled && _myPersonId == null)
            Card(
              color: theme.colorScheme.errorContainer,
              child: const Padding(
                padding: EdgeInsets.all(12),
                child: Text(
                  "Pick which person is you above — otherwise reminders can't be "
                  'scheduled on this device.',
                ),
              ),
            ),
        ],
      ),
    );
  }
}
