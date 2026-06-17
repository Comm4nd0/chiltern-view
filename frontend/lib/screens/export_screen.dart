import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

import '../api/api_client.dart';

/// Export the holding's data as CSV. Mobile can't trigger a file download like
/// the web, so each dataset is fetched and copied to the clipboard to paste
/// into a note or email — a lightweight, dependency-free backup.
class ExportScreen extends StatefulWidget {
  const ExportScreen({super.key});

  @override
  State<ExportScreen> createState() => _ExportScreenState();
}

class _ExportScreenState extends State<ExportScreen> {
  final ApiClient _api = ApiClient();
  String? _busy;

  static const _datasets = ['animals', 'crops', 'eggs', 'weights', 'supplies', 'journal'];

  Future<void> _copy(String dataset) async {
    setState(() => _busy = dataset);
    try {
      final csv = await _api.exportCsv(dataset);
      await Clipboard.setData(ClipboardData(text: csv));
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Copied $dataset CSV to the clipboard')),
        );
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text('Failed: $e')));
      }
    } finally {
      if (mounted) setState(() => _busy = null);
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('Export data')),
      body: ListView(
        padding: const EdgeInsets.all(16),
        children: [
          Text(
            'Copy a CSV backup of any part of the holding, then paste it into a '
            'note or email.',
            style: Theme.of(context).textTheme.bodyMedium,
          ),
          const SizedBox(height: 8),
          for (final dataset in _datasets)
            Card(
              child: ListTile(
                title: Text(dataset[0].toUpperCase() + dataset.substring(1)),
                trailing: _busy == dataset
                    ? const SizedBox(
                        width: 18, height: 18, child: CircularProgressIndicator(strokeWidth: 2))
                    : const Icon(Icons.copy),
                onTap: _busy == null ? () => _copy(dataset) : null,
              ),
            ),
        ],
      ),
    );
  }
}
