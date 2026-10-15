import 'package:flutter/material.dart';
import '../database/database.dart';
import 'race_entry_screen.dart';

class ArchiveScreen extends StatelessWidget {
  const ArchiveScreen({super.key, required this.db, required this.boat});
  final AppDatabase db;
  final Boat boat;

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('Archive')),
      body: StreamBuilder<List<RaceEvent>>(
        stream: db.watchArchive(boat.id),
        builder: (context, snapshot) {
          final events = snapshot.data ?? [];
          if (events.isEmpty) {
            return const Center(child: Text('Nothing logged yet.'));
          }
          return ListView.builder(
            itemCount: events.length,
            itemBuilder: (context, i) {
              final e = events[i];
              final isRegatta = e.type == EventType.regattaRace;
              return ListTile(
                leading: Icon(isRegatta ? Icons.emoji_events : Icons.timer),
                title: Text(isRegatta
                    ? 'Regatta race ${e.raceNumber ?? ''}'
                    : 'Practice'),
                subtitle: Text(
                    '${e.date.toString().split(' ').first} · '
                    '${e.windSpeedKt?.toStringAsFixed(0) ?? '--'} kt'),
                trailing:
                    e.boatFeelScore != null ? Text('${e.boatFeelScore}/5') : null,
                onTap: () => Navigator.of(context).push(MaterialPageRoute(
                  builder: (_) => RaceEntryScreen(
                    db: db,
                    draft: e.toCompanion(true),
                    title: isRegatta ? 'Race ${e.raceNumber}' : 'Practice',
                  ),
                )),
              );
            },
          );
        },
      ),
    );
  }
}
