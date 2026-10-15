import 'package:flutter/material.dart';
import 'database/database.dart';
import 'screens/home_screen.dart';

void main() {
  final db = AppDatabase();
  runApp(J70TrimLogApp(db: db));
}

class J70TrimLogApp extends StatelessWidget {
  const J70TrimLogApp({super.key, required this.db});
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
      home: HomeScreen(db: db),
    );
  }
}
