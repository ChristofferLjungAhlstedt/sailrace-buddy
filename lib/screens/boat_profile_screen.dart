import 'package:flutter/material.dart';
import '../database/database.dart';

class BoatProfileScreen extends StatefulWidget {
  const BoatProfileScreen({super.key, required this.db, required this.boat});
  final AppDatabase db;
  final Boat boat;

  @override
  State<BoatProfileScreen> createState() => _BoatProfileScreenState();
}

class _BoatProfileScreenState extends State<BoatProfileScreen> {
  late TextEditingController _name;
  late TextEditingController _sailNumber;
  late TextEditingController _innerBaseline;
  late TextEditingController _outerBaseline;

  @override
  void initState() {
    super.initState();
    _name = TextEditingController(text: widget.boat.name);
    _sailNumber = TextEditingController(text: widget.boat.sailNumber);
    _innerBaseline =
        TextEditingController(text: widget.boat.innerShroudBaseline?.toString() ?? '');
    _outerBaseline =
        TextEditingController(text: widget.boat.outerShroudBaseline?.toString() ?? '');
  }

  Future<void> _save() async {
    await widget.db.update(widget.db.boats).replace(widget.boat.copyWith(
          name: _name.text,
          sailNumber: _sailNumber.text,
          innerShroudBaseline: Value(double.tryParse(_innerBaseline.text)),
          outerShroudBaseline: Value(double.tryParse(_outerBaseline.text)),
          updatedAt: DateTime.now(),
        ));
    if (mounted) Navigator.of(context).pop();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Boat profile'),
        actions: [TextButton(onPressed: _save, child: const Text('Save'))],
      ),
      body: ListView(
        padding: const EdgeInsets.all(16),
        children: [
          TextField(
              controller: _name,
              decoration: const InputDecoration(labelText: 'Boat name')),
          const SizedBox(height: 12),
          TextField(
              controller: _sailNumber,
              decoration: const InputDecoration(labelText: 'Sail number')),
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
            keyboardType: TextInputType.number,
            decoration: const InputDecoration(labelText: 'Inner shroud baseline'),
          ),
          const SizedBox(height: 12),
          TextField(
            controller: _outerBaseline,
            keyboardType: TextInputType.number,
            decoration: const InputDecoration(labelText: 'Outer shroud baseline'),
          ),
        ],
      ),
    );
  }
}
