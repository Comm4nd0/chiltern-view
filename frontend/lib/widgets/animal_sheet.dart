import 'package:flutter/material.dart';
import 'package:image_picker/image_picker.dart';

import '../api/api_client.dart';
import '../models/animal.dart';
import '../util/animal_display.dart';

/// Add a new animal, or edit an existing one when [animal] is given.
/// Pops with `true` when something was saved.
class AnimalSheet extends StatefulWidget {
  final ApiClient api;
  final Animal? animal;
  const AnimalSheet({super.key, required this.api, this.animal});

  @override
  State<AnimalSheet> createState() => _AnimalSheetState();
}

class _AnimalSheetState extends State<AnimalSheet> {
  final _formKey = GlobalKey<FormState>();
  final _name = TextEditingController();
  final _breed = TextEditingController();
  String _species = 'chicken';
  bool _active = true;
  bool _saving = false;
  String? _photoPath;

  bool get _editing => widget.animal != null;

  Future<void> _pickPhoto() async {
    final picked =
        await ImagePicker().pickImage(source: ImageSource.gallery, maxWidth: 1600, imageQuality: 85);
    if (picked != null) setState(() => _photoPath = picked.path);
  }

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
      int id;
      if (_editing) {
        await widget.api.updateAnimal(
          widget.animal!.id,
          name: _name.text.trim(),
          species: _species,
          breed: _breed.text.trim(),
          active: _active,
        );
        id = widget.animal!.id;
      } else {
        final created = await widget.api.createAnimal(
          name: _name.text.trim(),
          species: _species,
          breed: _breed.text.trim(),
        );
        id = created.id;
      }
      if (_photoPath != null) {
        await widget.api.uploadAnimalPhoto(id, _photoPath!);
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
                for (final s in speciesChoices)
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
            const SizedBox(height: 12),
            Align(
              alignment: Alignment.centerLeft,
              child: OutlinedButton.icon(
                onPressed: _saving ? null : _pickPhoto,
                icon: const Icon(Icons.photo_camera_outlined, size: 18),
                label: Text(_photoPath != null
                    ? 'Photo selected'
                    : (widget.animal?.photo != null ? 'Replace photo' : 'Add photo')),
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
