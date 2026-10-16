import 'package:flutter/material.dart';
import '../database/database.dart';
import '../repositories/race_repository.dart';
import 'race_entry_screen.dart';
import '../models/wind_format.dart';

class PracticeScreen extends StatefulWidget {
  const PracticeScreen({super.key, required this.db, required this.boat});
  final AppDatabase db;
  final Boat boat;

  @override
  State<PracticeScreen> createState() => _PracticeScreenState();
}

class _PracticeScreenState extends State<PracticeScreen> {
  Future<void> _addPractice() async {
    final repo = RaceRepository(widget.db);
    final draft = repo.buildDraftForPractice(boatId: widget.boat.id);
    await Navigator.of(context).push(MaterialPageRoute(
      builder: (_) => RaceEntryScreen(
        db: widget.db,
        draft: draft,
        title: 'New practice',
      ),
    ));
    setState(() {});
  }

  @override
  Widget build(BuildContext context) {
    final query = widget.db.select(widget.db.raceEvents)
      ..where((r) => Expression.and([
            r.boatId.equals(widget.boat.id),
            r.type.equalsValue(EventType.practice),
          ]))
      ..orderBy([(r) => OrderingTerm.desc(r.date)]);

    return Scaffold(
      appBar: AppBar(title: const Text('Practice')),
      floatingActionButton: FloatingActionButton.extended(
        onPressed: _addPractice,
        icon: const Icon(Icons.add),
        label: const Text('Log event'),
      ),
      body: StreamBuilder<List<RaceEvent>>(
        stream: query.watch(),
        builder: (context, snapshot) {
          final events = snapshot.data ?? [];
          if (events.isEmpty) {
            return const Center(
                child: Text('No practice events yet. Tap + to log one.'));
          }
          return ListView.builder(
            itemCount: events.length,
            itemBuilder: (context, i) {
              final e = events[i];
              return ListTile(
                title: Text(e.windSpeedKt != null
                    ? formatWind(e.windSpeedKt)
                    : 'Practice'),
                subtitle: Text(e.date.toString().split(' ').first),
                trailing: e.boatFeelScore != null
                    ? Text('${e.boatFeelScore}/5')
                    : null,
                onTap: () async {
                  await Navigator.of(context).push(MaterialPageRoute(
                    builder: (_) => RaceEntryScreen(
                      db: widget.db,
                      draft: e.toCompanion(true),
                      title: 'Practice',
                    ),
                  ));
                  setState(() {});
                },
              );
            },
          );
        },
      ),
    );
  }
}
