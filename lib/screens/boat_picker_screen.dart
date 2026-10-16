import 'package:flutter/material.dart';
import '../database/database.dart';
import '../widgets/class_logo.dart';
import 'boat_form_screen.dart';
import 'home_screen.dart';

class BoatPickerScreen extends StatefulWidget {
  const BoatPickerScreen({super.key, required this.db});
  final AppDatabase db;

  @override
  State<BoatPickerScreen> createState() => _BoatPickerScreenState();
}

class _BoatPickerScreenState extends State<BoatPickerScreen> {
  List<Boat>? _boats;
  String? _lastId;

  @override
  void initState() {
    super.initState();
    _load();
  }

  Future<void> _load() async {
    final boats = await widget.db.select(widget.db.boats).get();
    final lastId = await widget.db.getLastBoatId();
    // Last used boat first, then alphabetical.
    boats.sort((a, b) {
      if (a.id == lastId) return -1;
      if (b.id == lastId) return 1;
      return a.name.toLowerCase().compareTo(b.name.toLowerCase());
    });
    if (!mounted) return;
    setState(() {
      _boats = boats;
      _lastId = lastId;
    });
  }

  /// Opens a boat's home screen and clears the navigation stack, so
  /// Back never returns to the picker or a previous boat.
  Future<void> _open(Boat boat) async {
    await widget.db.setLastBoatId(boat.id);
    if (!mounted) return;
    Navigator.of(context).pushAndRemoveUntil(
      MaterialPageRoute(
          builder: (_) => HomeScreen(db: widget.db, boat: boat)),
      (route) => false,
    );
  }

  Future<void> _newBoat() async {
    final boat = await Navigator.of(context).push<Boat>(
      MaterialPageRoute(builder: (_) => BoatFormScreen(db: widget.db)),
    );
    if (boat != null) await _open(boat);
  }

  void _showImportInfo() {
    showDialog<void>(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Import is under development'),
        content: const Text(
          'Restoring a backup is not available yet, it is coming in a '
          'future version. For now, create a new boat to get started.',
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: const Text('OK'),
          ),
        ],
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final boats = _boats;
    if (boats == null) {
      return const Scaffold(body: Center(child: CircularProgressIndicator()));
    }
    return boats.isEmpty ? _welcome(context) : _list(context, boats);
  }

  Widget _welcome(BuildContext context) {
    final theme = Theme.of(context);
    return Scaffold(
      body: SafeArea(
        child: Center(
          child: SingleChildScrollView(
            padding: const EdgeInsets.all(24),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                Icon(Icons.sailing, size: 72, color: theme.colorScheme.primary),
                const SizedBox(height: 16),
                Text('Sailrace Buddy',
                    textAlign: TextAlign.center,
                    style: theme.textTheme.headlineMedium),
                const SizedBox(height: 8),
                Text(
                  'Log your trim between races and find what works.',
                  textAlign: TextAlign.center,
                  style: theme.textTheme.bodyMedium,
                ),
                const SizedBox(height: 40),
                FilledButton.icon(
                  onPressed: _newBoat,
                  icon: const Icon(Icons.add),
                  label: const Text('New boat'),
                ),
                const SizedBox(height: 12),
                OutlinedButton.icon(
                  onPressed: _showImportInfo,
                  icon: const Icon(Icons.upload_file),
                  label: const Text('Import'),
                ),
                const SizedBox(height: 8),
                Text(
                  'Import is under development.',
                  textAlign: TextAlign.center,
                  style: theme.textTheme.bodySmall,
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }

  Widget _list(BuildContext context, List<Boat> boats) {
    return Scaffold(
      appBar: AppBar(title: const Text('Choose boat')),
      body: ListView.builder(
        padding: const EdgeInsets.all(16),
        itemCount: boats.length,
        itemBuilder: (context, i) {
          final b = boats[i];
          final subtitle = b.sailNumber.isEmpty
              ? b.boatClass
              : '${b.boatClass} · ${b.sailNumber}';
          return Card(
            child: ListTile(
              contentPadding:
                  const EdgeInsets.symmetric(horizontal: 16, vertical: 6),
              leading: ClassLogo(className: b.boatClass, size: 36),
              title: Text(b.name),
              subtitle: Text(subtitle),
              trailing: b.id == _lastId
                  ? Text('Last used',
                      style: Theme.of(context).textTheme.bodySmall)
                  : const Icon(Icons.chevron_right),
              onTap: () => _open(b),
            ),
          );
        },
      ),
      bottomNavigationBar: SafeArea(
        child: Padding(
          padding: const EdgeInsets.all(16),
          child: Row(
            children: [
              Expanded(
                child: FilledButton.icon(
                  onPressed: _newBoat,
                  icon: const Icon(Icons.add),
                  label: const Text('New boat'),
                ),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: OutlinedButton.icon(
                  onPressed: _showImportInfo,
                  icon: const Icon(Icons.upload_file),
                  label: const Text('Import'),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}