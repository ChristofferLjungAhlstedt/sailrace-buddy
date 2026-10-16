import 'package:flutter/material.dart';
import '../database/database.dart';
import 'export_flow.dart';
import 'custom_fields_screen.dart';
import 'import_flow.dart';
import '../settings/app_prefs.dart';

class SettingsScreen extends StatefulWidget {
  const SettingsScreen({super.key, required this.db, required this.boat});
  final AppDatabase db;
  final Boat boat;

  @override
  State<SettingsScreen> createState() => _SettingsScreenState();
}

class _SettingsScreenState extends State<SettingsScreen> {
  WindUnit _windUnit = AppPrefs.windUnit.value;
  void _toast(String message) {
    ScaffoldMessenger.of(context)
        .showSnackBar(SnackBar(content: Text(message)));
  }

  Future<void> _exportAll() async {
    final boats = await widget.db.select(widget.db.boats).get();
    if (boats.isEmpty) {
      if (mounted) _toast('Nothing to export yet');
      return;
    }
    if (!mounted) return;
    await runExportFlow(context, widget.db);
  }

  Future<void> _import() async {
    final summary = await runImportFlow(context, widget.db);
    if (summary == null || !mounted) return;
    _toast('Import complete: ${summary.oneLine}. '
        'Use Switch boat to see boats you added.');
  }

  @override
  Widget build(BuildContext context) {
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
              onSelectionChanged: (s) {
                setState(() => _windUnit = s.first);
                AppPrefs.setWindUnit(widget.db, s.first);
              },
            ),
          ),
          const Divider(),
          ListTile(
            leading: const Icon(Icons.tune),
            title: const Text('Custom fields'),
            subtitle: Text('Extra trim data for ${widget.boat.name}'),
            trailing: const Icon(Icons.chevron_right),
            onTap: () => Navigator.of(context).push(MaterialPageRoute(
              builder: (_) =>
                  CustomFieldsScreen(db: widget.db, boat: widget.boat),
            )),
          ),
          const Divider(),
          ListTile(
            leading: const Icon(Icons.download),
            title: const Text('Export all boats'),
            subtitle: const Text('One backup file with everything'),
            onTap: _exportAll,
          ),
          ListTile(
            leading: const Icon(Icons.upload),
            title: const Text('Import backup'),
            subtitle: const Text('Adds to what is on this device'),
            onTap: _import,
          ),
        ],
      ),
    );
  }
}
