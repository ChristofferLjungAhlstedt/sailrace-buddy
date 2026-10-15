import 'package:flutter/material.dart';
import 'package:uuid/uuid.dart';
import '../database/database.dart';

class SettingsScreen extends StatefulWidget {
  const SettingsScreen({super.key, required this.db, required this.boat});
  final AppDatabase db;
  final Boat boat;

  @override
  State<SettingsScreen> createState() => _SettingsScreenState();
}

class _SettingsScreenState extends State<SettingsScreen> {
  WindUnit _windUnit = WindUnit.knots;

  Future<void> _addCustomField() async {
    final nameController = TextEditingController();
    var type = CustomFieldType.floatType;

    final confirmed = await showDialog<bool>(
      context: context,
      builder: (context) => StatefulBuilder(
        builder: (context, setDialogState) => AlertDialog(
          title: const Text('Add custom field'),
          content: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              TextField(
                controller: nameController,
                decoration: const InputDecoration(labelText: 'Field name'),
              ),
              const SizedBox(height: 12),
              DropdownButton<CustomFieldType>(
                value: type,
                items: const [
                  DropdownMenuItem(
                      value: CustomFieldType.intType, child: Text('Whole number')),
                  DropdownMenuItem(
                      value: CustomFieldType.floatType, child: Text('Decimal number')),
                  DropdownMenuItem(
                      value: CustomFieldType.enumType, child: Text('Choice list')),
                  DropdownMenuItem(
                      value: CustomFieldType.textType, child: Text('Free text (note)')),
                ],
                onChanged: (v) => setDialogState(() => type = v!),
              ),
            ],
          ),
          actions: [
            TextButton(
                onPressed: () => Navigator.pop(context, true),
                child: const Text('Add')),
          ],
        ),
      ),
    );

    if (confirmed == true && nameController.text.isNotEmpty) {
      await widget.db.into(widget.db.customFieldDefinitions).insert(
            CustomFieldDefinitionsCompanion.insert(
              id: const Uuid().v4(),
              boatId: widget.boat.id,
              name: nameController.text,
              fieldType: type,
            ),
          );
      setState(() {});
    }
  }

  @override
  Widget build(BuildContext context) {
    final fieldsQuery = widget.db.select(widget.db.customFieldDefinitions)
      ..where((f) => f.boatId.equals(widget.boat.id));

    return Scaffold(
      appBar: AppBar(title: const Text('Settings')),
      body: ListView(
        children: [
          ListTile(
            title: const Text('Wind speed unit'),
            trailing: SegmentedButton<WindUnit>(
              segments: const [
                ButtonSegment(value: WindUnit.knots, label: Text('kt')),
                ButtonSegment(value: WindUnit.ms, label: Text('m/s')),
              ],
              selected: {_windUnit},
              onSelectionChanged: (s) => setState(() => _windUnit = s.first),
            ),
          ),
          const Divider(),
          Padding(
            padding: const EdgeInsets.all(16),
            child: Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Text('Custom fields', style: Theme.of(context).textTheme.titleSmall),
                TextButton.icon(
                  onPressed: _addCustomField,
                  icon: const Icon(Icons.add),
                  label: const Text('Add field'),
                ),
              ],
            ),
          ),
          StreamBuilder<List<CustomFieldDefinition>>(
            stream: fieldsQuery.watch(),
            builder: (context, snapshot) {
              final fields = snapshot.data ?? [];
              if (fields.isEmpty) {
                return const Padding(
                  padding: EdgeInsets.symmetric(horizontal: 16),
                  child: Text('No custom fields yet.'),
                );
              }
              return Column(
                children: fields
                    .map((f) => ListTile(
                          title: Text(f.name),
                          subtitle: Text(f.fieldType.name),
                        ))
                    .toList(),
              );
            },
          ),
          const Divider(),
          ListTile(
            title: const Text('Export all data'),
            subtitle: const Text('Save a backup you can restore later'),
            leading: const Icon(Icons.download),
            onTap: () {
              // TODO: serialize all tables to JSON and share via share_plus,
              // or write to a user-picked location via file_picker.
              ScaffoldMessenger.of(context).showSnackBar(
                  const SnackBar(content: Text('Export coming soon')));
            },
          ),
          ListTile(
            title: const Text('Import data'),
            leading: const Icon(Icons.upload),
            onTap: () {
              // TODO: pick a JSON file via file_picker and restore into
              // the drift database, matching by UUID for idempotent re-import.
              ScaffoldMessenger.of(context).showSnackBar(
                  const SnackBar(content: Text('Import coming soon')));
            },
          ),
        ],
      ),
    );
  }
}
