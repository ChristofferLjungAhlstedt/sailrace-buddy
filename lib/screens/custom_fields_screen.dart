import 'dart:convert';
import 'package:flutter/material.dart';
import 'package:uuid/uuid.dart';
import '../database/database.dart';
import '../models/custom_field_x.dart';

typedef FieldEditorResult = ({
  String name,
  CustomFieldType type,
  String? unit,
  List<String> options,
});

class CustomFieldsScreen extends StatefulWidget {
  const CustomFieldsScreen({super.key, required this.db, required this.boat});
  final AppDatabase db;
  final Boat boat;

  @override
  State<CustomFieldsScreen> createState() => _CustomFieldsScreenState();
}

class _CustomFieldsScreenState extends State<CustomFieldsScreen> {
  Set<String> _otherNames(List<CustomFieldDefinition> all, {String? except}) {
    return {
      for (final d in all)
        if (d.id != except) d.name.toLowerCase(),
    };
  }

  Future<void> _add() async {
    final all = await widget.db.allCustomFields(widget.boat.id);
    if (!mounted) return;
    final result = await showDialog<FieldEditorResult>(
      context: context,
      builder: (_) => _FieldEditorDialog(takenNames: _otherNames(all)),
    );
    if (result == null) return;

    final nextOrder =
        all.fold<int>(-1, (m, d) => d.sortOrder > m ? d.sortOrder : m) + 1;

    await widget.db.into(widget.db.customFieldDefinitions).insert(
          CustomFieldDefinitionsCompanion.insert(
            id: const Uuid().v4(),
            boatId: widget.boat.id,
            name: result.name,
            fieldType: result.type,
            enumOptions: Value(result.type == CustomFieldType.enumType
                ? jsonEncode(result.options)
                : null),
            unit: Value(result.unit),
            sortOrder: Value(nextOrder),
          ),
        );
  }

  Future<void> _edit(CustomFieldDefinition def) async {
    final all = await widget.db.allCustomFields(widget.boat.id);
    if (!mounted) return;
    final result = await showDialog<FieldEditorResult>(
      context: context,
      builder: (_) => _FieldEditorDialog(
        existing: def,
        takenNames: _otherNames(all, except: def.id),
      ),
    );
    if (result == null) return;

    await widget.db.update(widget.db.customFieldDefinitions).replace(
          def.copyWith(
            name: result.name,
            unit: Value(result.unit),
            enumOptions: Value(def.fieldType == CustomFieldType.enumType
                ? jsonEncode(result.options)
                : null),
          ),
        );
  }

  Future<void> _setActive(CustomFieldDefinition def, bool active) {
    return widget.db
        .update(widget.db.customFieldDefinitions)
        .replace(def.copyWith(active: active));
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('Custom fields')),
      floatingActionButton: FloatingActionButton.extended(
        onPressed: _add,
        icon: const Icon(Icons.add),
        label: const Text('Add field'),
      ),
      body: StreamBuilder<List<CustomFieldDefinition>>(
        stream: widget.db.watchCustomFields(widget.boat.id),
        builder: (context, snapshot) {
          final fields = snapshot.data ?? [];
          return ListView(
            padding: const EdgeInsets.only(bottom: 96),
            children: [
              Padding(
                padding: const EdgeInsets.all(16),
                child: Text(
                  'Extra data to log for ${widget.boat.name}. Fields appear on '
                  'every race and practice form. Numbers and choice lists can '
                  'be analysed later, free text cannot, so use it sparingly.\n\n'
                  'Switch a field off to hide it from the forms. Its history '
                  'is kept.',
                  style: Theme.of(context).textTheme.bodySmall,
                ),
              ),
              if (fields.isEmpty)
                const Padding(
                  padding: EdgeInsets.all(16),
                  child: Text('No custom fields yet. Tap Add field.'),
                ),
              for (final f in fields)
                ListTile(
                  title: Text(
                    f.name,
                    style: f.active
                        ? null
                        : TextStyle(color: Theme.of(context).colorScheme.outline),
                  ),
                  subtitle: Text([
                    f.fieldType.label,
                    if (f.unit != null && f.unit!.isNotEmpty) f.unit!,
                    if (!f.active) 'hidden',
                  ].join(' · ')),
                  trailing: Switch(
                    value: f.active,
                    onChanged: (v) => _setActive(f, v),
                  ),
                  onTap: () => _edit(f),
                ),
            ],
          );
        },
      ),
    );
  }
}

class _FieldEditorDialog extends StatefulWidget {
  const _FieldEditorDialog({this.existing, required this.takenNames});

  final CustomFieldDefinition? existing;

  /// Lower-case names already used by this boat's other fields.
  final Set<String> takenNames;

  @override
  State<_FieldEditorDialog> createState() => _FieldEditorDialogState();
}

class _FieldEditorDialogState extends State<_FieldEditorDialog> {
  late final TextEditingController _name;
  late final TextEditingController _unit;
  late final TextEditingController _options;
  late CustomFieldType _type;
  String? _error;

  bool get _editing => widget.existing != null;

  @override
  void initState() {
    super.initState();
    final e = widget.existing;
    _name = TextEditingController(text: e?.name ?? '');
    _unit = TextEditingController(text: e?.unit ?? '');
    _options = TextEditingController(text: e?.options.join('\n') ?? '');
    _type = e?.fieldType ?? CustomFieldType.intType;
  }

  @override
  void dispose() {
    _name.dispose();
    _unit.dispose();
    _options.dispose();
    super.dispose();
  }

  void _submit() {
    final name = _name.text.trim();
    if (name.isEmpty) {
      setState(() => _error = 'Give the field a name');
      return;
    }
    if (widget.takenNames.contains(name.toLowerCase())) {
      setState(() => _error = 'You already have a field with that name');
      return;
    }

    final options = <String>[];
    if (_type == CustomFieldType.enumType) {
      for (final line in _options.text.split('\n')) {
        final o = line.trim();
        if (o.isNotEmpty && !options.contains(o)) options.add(o);
      }
      if (options.length < 2) {
        setState(() => _error = 'Add at least two options, one per line');
        return;
      }
    }

    final unit = _unit.text.trim();
    Navigator.pop<FieldEditorResult>(context, (
      name: name,
      type: _type,
      unit: _type.isNumeric && unit.isNotEmpty ? unit : null,
      options: options,
    ));
  }

  @override
  Widget build(BuildContext context) {
    return AlertDialog(
      title: Text(_editing ? 'Edit field' : 'Add custom field'),
      content: SingleChildScrollView(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            TextField(
              controller: _name,
              autofocus: !_editing,
              textCapitalization: TextCapitalization.sentences,
              decoration: const InputDecoration(labelText: 'Field name'),
            ),
            const SizedBox(height: 16),
            if (_editing)
              Text('Type: ${_type.label} (cannot be changed)',
                  style: Theme.of(context).textTheme.bodySmall)
            else
              DropdownButtonFormField<CustomFieldType>(
                value: _type,
                decoration: const InputDecoration(labelText: 'Type'),
                items: [
                  for (final t in CustomFieldType.values)
                    DropdownMenuItem(value: t, child: Text(t.label)),
                ],
                onChanged: (v) => setState(() => _type = v!),
              ),
            if (_type.isNumeric) ...[
              const SizedBox(height: 12),
              TextField(
                controller: _unit,
                decoration:
                    const InputDecoration(labelText: 'Unit (optional, e.g. mm)'),
              ),
            ],
            if (_type == CustomFieldType.enumType) ...[
              const SizedBox(height: 12),
              TextField(
                controller: _options,
                minLines: 3,
                maxLines: 6,
                decoration: const InputDecoration(
                  labelText: 'Options, one per line',
                  helperText:
                      'Removing an option later does not change races that used it.',
                  helperMaxLines: 2,
                  alignLabelWithHint: true,
                ),
              ),
            ],
            if (_type == CustomFieldType.textType)
              Padding(
                padding: const EdgeInsets.only(top: 12),
                child: Text(
                  'Notes only. Numbers and choice lists can be searched and '
                  'analysed later.',
                  style: Theme.of(context).textTheme.bodySmall,
                ),
              ),
            if (_error != null)
              Padding(
                padding: const EdgeInsets.only(top: 12),
                child: Text(_error!,
                    style: TextStyle(color: Theme.of(context).colorScheme.error)),
              ),
          ],
        ),
      ),
      actions: [
        TextButton(
          onPressed: () => Navigator.pop(context),
          child: const Text('Cancel'),
        ),
        FilledButton(onPressed: _submit, child: const Text('Save')),
      ],
    );
  }
}