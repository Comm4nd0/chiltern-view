import 'package:flutter/material.dart';
import 'package:intl/intl.dart';

import '../api/api_client.dart';
import '../models/log_entry.dart';
import 'animal_detail_screen.dart'; // typeColors

/// Whole-holding "who did what" timeline: every journal note plus task
/// completions, newest first.
class ActivityScreen extends StatefulWidget {
  const ActivityScreen({super.key});

  @override
  State<ActivityScreen> createState() => _ActivityScreenState();
}

class _ActivityScreenState extends State<ActivityScreen> {
  final ApiClient _api = ApiClient();
  final List<LogEntry> _entries = [];
  bool _loading = true;
  String? _error;
  bool _hasMore = false;
  int _page = 1;

  @override
  void initState() {
    super.initState();
    _load(reset: true);
  }

  Future<void> _load({required bool reset}) async {
    if (reset) {
      setState(() {
        _loading = true;
        _error = null;
        _entries.clear();
        _page = 1;
        _hasMore = false;
      });
    }
    try {
      final page = await _api.logEntries(page: _page);
      if (!mounted) return;
      setState(() {
        _entries.addAll(page.entries);
        _hasMore = page.hasMore;
        _loading = false;
      });
    } catch (e) {
      if (!mounted) return;
      setState(() {
        _error = '$e';
        _loading = false;
      });
    }
  }

  void _loadMore() {
    _page += 1;
    _load(reset: false);
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('Activity')),
      body: RefreshIndicator(
        onRefresh: () async => _load(reset: true),
        child: _loading
            ? const Center(child: CircularProgressIndicator())
            : _error != null
                ? ListView(
                    children: [
                      const SizedBox(height: 80),
                      Center(child: Text('Could not load: $_error')),
                      const SizedBox(height: 8),
                      Center(
                        child: TextButton(
                          onPressed: () => _load(reset: true),
                          child: const Text('Retry'),
                        ),
                      ),
                    ],
                  )
                : _entries.isEmpty
                    ? ListView(
                        children: const [
                          SizedBox(height: 120),
                          Center(child: Text('Nothing has happened yet.')),
                        ],
                      )
                    : ListView.separated(
                        physics: const AlwaysScrollableScrollPhysics(),
                        padding: const EdgeInsets.all(12),
                        itemCount: _entries.length + (_hasMore ? 1 : 0),
                        separatorBuilder: (_, __) => const Divider(height: 1),
                        itemBuilder: (context, i) {
                          if (i >= _entries.length) {
                            return Center(
                              child: TextButton(
                                  onPressed: _loadMore, child: const Text('Load more')),
                            );
                          }
                          return _row(context, _entries[i]);
                        },
                      ),
      ),
    );
  }

  Widget _row(BuildContext context, LogEntry entry) {
    final theme = Theme.of(context);
    final color = typeColors[entry.entryType] ?? const Color(0xFF8E8E93);
    final meta = [
      if (entry.animalName != null) entry.animalName!,
      DateFormat('d MMM y').format(entry.occurredOn),
      if (entry.createdByName != null) entry.createdByName!,
    ].join(' · ');
    return InkWell(
      onTap: entry.animal == null
          ? null
          : () => Navigator.of(context).push(MaterialPageRoute<void>(
                builder: (_) => AnimalDetailScreen(animalId: entry.animal!),
              )),
      child: Padding(
        padding: const EdgeInsets.symmetric(vertical: 10),
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
