import 'package:flutter/material.dart';
import '../database/database.dart';
import 'boat_picker_screen.dart';
import 'home_screen.dart';

/// First screen of the app. Decides where to go:
///  - exactly one boat -> straight to that boat's home screen
///  - zero boats (first launch) or 2+ boats -> boat picker
class StartupGate extends StatefulWidget {
  const StartupGate({super.key, required this.db});
  final AppDatabase db;

  @override
  State<StartupGate> createState() => _StartupGateState();
}

class _StartupGateState extends State<StartupGate> {
  late final Future<List<Boat>> _boats;

  @override
  void initState() {
    super.initState();
    _boats = widget.db.select(widget.db.boats).get();
  }

  @override
  Widget build(BuildContext context) {
    return FutureBuilder<List<Boat>>(
      future: _boats,
      builder: (context, snapshot) {
        if (snapshot.hasError) {
          return Scaffold(
              body: Center(child: Text('Could not open data: ${snapshot.error}')));
        }
        if (!snapshot.hasData) {
          return const Scaffold(
              body: Center(child: CircularProgressIndicator()));
        }
        final boats = snapshot.data!;
        if (boats.length == 1) {
          return HomeScreen(db: widget.db, boat: boats.first);
        }
        return BoatPickerScreen(db: widget.db);
      },
    );
  }
}