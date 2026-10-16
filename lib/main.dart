import 'package:flutter/material.dart';
import 'database/database.dart';
import 'screens/startup_gate.dart';

void main() {
  final db = AppDatabase();
  runApp(SailraceBuddyApp(db: db));
}

class SailraceBuddyApp extends StatelessWidget {
  const SailraceBuddyApp({super.key, required this.db});
  final AppDatabase db;

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: 'Sailrace Buddy',
      theme: ThemeData(
        colorSchemeSeed: Colors.teal,
        useMaterial3: true,
      ),
      darkTheme: ThemeData(
        colorSchemeSeed: Colors.teal,
        brightness: Brightness.dark,
        useMaterial3: true,
      ),
      home: StartupGate(db: db),
    );
  }
}