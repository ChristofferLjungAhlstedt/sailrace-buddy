import 'package:flutter/material.dart';
import 'package:uuid/uuid.dart';
import '../database/database.dart';
import '../widgets/boat_class_picker.dart';

/// Creates a new boat and returns it (via Navigator.pop) to the caller.
class BoatFormScreen extends StatefulWidget {
  const BoatFormScreen({super.key, required this.db});
  final AppDatabase db;

  @override
  State<BoatFormScreen> createState() => _BoatFormScreenState();
}

class _BoatFormScreenState extends State<BoatFormScreen> {
  final _name = TextEditingController();
  final _sailNumber = TextEditingController();
  String _class = '';
  bool _saving = false;

  @override
  void dispose() {
    _name.dispose();
    _sailNumber.dispose();
    super.dispose();
  }

  void _toast(String message) {
    ScaffoldMessenger.of(context)
        .showSnackBar(SnackBar(content: Text(message)));
  }

  Future<void> _save() async {
    final name = _name.text.trim();
    if (_class.isEmpty) {
      _toast('Choose a boat class');
      return;
    }
    if (name.isEmpty) {
      _toast('Give the boat a name');
      return;
    }

    setState(() => _saving = true);
    final now = DateTime.now();
    final boat = await widget.db.into(widget.db.boats).insertReturning(
          BoatsCompanion.insert(
            id: const Uuid().v4(),
            name: name,
            boatClass: Value(_class),
            sailNumber: Value(_sailNumber.text.trim()),
            createdAt: now,
            updatedAt: now,
          ),
        );
    if (!mounted) return;
    Navigator.of(context).pop(boat);
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('New boat'),
        actions: [
          TextButton(
            onPressed: _saving ? null : _save,
            child: const Text('Done'),
          ),
        ],
      ),
      body: ListView(
        padding: const EdgeInsets.all(16),
        children: [
          BoatClassPicker(onChanged: (v) => _class = v),
          const SizedBox(height: 16),
          TextField(
            controller: _name,
            textCapitalization: TextCapitalization.words,
            decoration: const InputDecoration(labelText: 'Boat name'),
          ),
          const SizedBox(height: 16),
          TextField(
            controller: _sailNumber,
            textCapitalization: TextCapitalization.characters,
            decoration:
                const InputDecoration(labelText: 'Sail number (optional)'),
          ),
        ],
      ),
    );
  }
}