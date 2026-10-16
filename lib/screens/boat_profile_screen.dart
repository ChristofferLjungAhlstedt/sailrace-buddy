import 'package:flutter/material.dart';
import '../database/database.dart';
import '../widgets/boat_class_picker.dart';

class BoatProfileScreen extends StatefulWidget {
  const BoatProfileScreen({super.key, required this.db, required this.boat});
  final AppDatabase db;
  final Boat boat;

  @override
  State<BoatProfileScreen> createState() => _BoatProfileScreenState();
}

class _BoatProfileScreenState extends State<BoatProfileScreen> {
  late final TextEditingController _name;
  late final TextEditingController _sailNumber;
  late final TextEditingController _innerBaseline;
  late final TextEditingController _outerBaseline;
  late String _class;

  @override
  void initState() {
    super.initState();
    _class = widget.boat.boatClass;
    _name = TextEditingController(text: widget.boat.name);
    _sailNumber = TextEditingController(text: widget.boat.sailNumber);
    _innerBaseline = TextEditingController(
        text: widget.boat.innerShroudBaseline?.toString() ?? '');
    _outerBaseline = TextEditingController(
        text: widget.boat.outerShroudBaseline?.toString() ?? '');
  }

  @override
  void dispose() {
    _name.dispose();
    _sailNumber.dispose();
    _innerBaseline.dispose();
    _outerBaseline.dispose();
    super.dispose();
  }

  double? _parse(String text) =>
      double.tryParse(text.trim().replaceAll(',', '.'));

  Future<void> _save() async {
    final name = _name.text.trim();
    if (name.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('The boat needs a name')));
      return;
    }
    await widget.db.update(widget.db.boats).replace(widget.boat.copyWith(
          name: name,
          // Keep the old class if the picker was left empty.
          boatClass: _class.isEmpty ? widget.boat.boatClass : _class,
          sailNumber: _sailNumber.text.trim(),
          innerShroudBaseline: Value(_parse(_innerBaseline.text)),
          outerShroudBaseline: Value(_parse(_outerBaseline.text)),
          updatedAt: DateTime.now(),
        ));
    if (mounted) Navigator.of(context).pop();
  }

  @override
  Widget build(BuildContext context) {
    const decimalKeyboard = TextInputType.numberWithOptions(decimal: true);
    return Scaffold(
      appBar: AppBar(
        title: const Text('Boat profile'),
        actions: [TextButton(onPressed: _save, child: const Text('Save'))],
      ),
      body: ListView(
        padding: const EdgeInsets.all(16),
        children: [
          BoatClassPicker(
            initialClass: widget.boat.boatClass,
            onChanged: (v) => _class = v,
          ),
          const SizedBox(height: 12),
          TextField(
            controller: _name,
            textCapitalization: TextCapitalization.words,
            decoration: const InputDecoration(labelText: 'Boat name'),
          ),
          const SizedBox(height: 12),
          TextField(
            controller: _sailNumber,
            textCapitalization: TextCapitalization.characters,
            decoration:
                const InputDecoration(labelText: 'Sail number (optional)'),
          ),
          const SizedBox(height: 12),
          const Divider(),
          const SizedBox(height: 12),
          Text(
            'Shroud baseline (device-measured tension). Race entries store '
            'their tension as an offset in turns from this value.',
            style: Theme.of(context).textTheme.bodySmall,
          ),
          const SizedBox(height: 12),
          TextField(
            controller: _innerBaseline,
            keyboardType: decimalKeyboard,
            decoration:
                const InputDecoration(labelText: 'Inner shroud baseline'),
          ),
          const SizedBox(height: 12),
          TextField(
            controller: _outerBaseline,
            keyboardType: decimalKeyboard,
            decoration:
                const InputDecoration(labelText: 'Outer shroud baseline'),
          ),
        ],
      ),
    );
  }
}