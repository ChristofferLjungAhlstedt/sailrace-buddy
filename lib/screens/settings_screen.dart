import 'package:flutter/material.dart';
import '../database/database.dart';
import 'custom_fields_screen.dart';

class SettingsScreen extends StatefulWidget {
  const SettingsScreen({super.key, required this.db, required this.boat});
  final AppDatabase db;
  final Boat boat;

  @override
  State<SettingsScreen> createState() => _SettingsScreenState();
}

class _SettingsScreenState extends State<SettingsScreen> {
  WindUnit _windUnit = WindUnit.knots;

  void _underDevelopment(String what) {
    ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('$what is under development')));
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
              onSelectionChanged: (s) => setState(() => _windUnit = s.first),
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
            title: const Text('Export all data'),
            subtitle: const Text('Under development'),
            onTap: () => _underDevelopment('Export all'),
          ),
          ListTile(
            leading: const Icon(Icons.upload),
            title: const Text('Import data'),
            subtitle: const Text('Under development'),
            onTap: () => _underDevelopment('Import'),
          ),
        ],
      ),
    );
  }
}