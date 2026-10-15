import 'package:flutter/material.dart';
import 'package:uuid/uuid.dart';
import 'package:intl/intl.dart';
import '../database/database.dart';
import 'regatta_detail_screen.dart';

class RegattaListScreen extends StatefulWidget {
  const RegattaListScreen({super.key, required this.db, required this.boat});
  final AppDatabase db;
  final Boat boat;

  @override
  State<RegattaListScreen> createState() => _RegattaListScreenState();
}

class _RegattaListScreenState extends State<RegattaListScreen> {
  Future<void> _createRegatta() async {
    final regatta = RegattasCompanion.insert(
      id: const Uuid().v4(),
      boatId: widget.boat.id,
      name: 'New regatta',
      startDate: DateTime.now(),
      createdAt: DateTime.now(),
      updatedAt: DateTime.now(),
    );
    final id = await widget.db.into(widget.db.regattas).insertReturning(regatta);
    if (!mounted) return;
    await Navigator.of(context).push(MaterialPageRoute(
        builder: (_) => RegattaDetailScreen(db: widget.db, regattaId: id.id)));
    setState(() {});
  }

  @override
  Widget build(BuildContext context) {
    final query = widget.db.select(widget.db.regattas)
      ..where((r) => r.boatId.equals(widget.boat.id))
      ..orderBy([(r) => OrderingTerm.desc(r.startDate)]);

    return Scaffold(
      appBar: AppBar(title: const Text('Regattas')),
      floatingActionButton: FloatingActionButton(
        onPressed: _createRegatta,
        child: const Icon(Icons.add),
      ),
      body: StreamBuilder<List<Regatta>>(
        stream: query.watch(),
        builder: (context, snapshot) {
          final regattas = snapshot.data ?? [];
          if (regattas.isEmpty) {
            return const Center(child: Text('No regattas yet. Tap + to start one.'));
          }
          return ListView.builder(
            itemCount: regattas.length,
            itemBuilder: (context, i) {
              final r = regattas[i];
              return ListTile(
                title: Text(r.name),
                subtitle: Text(
                    '${r.venue}  ${DateFormat.yMMMd().format(r.startDate)}'),
                trailing: r.overallRating != null
                    ? Text('${r.overallRating}/5')
                    : null,
                onTap: () => Navigator.of(context).push(MaterialPageRoute(
                    builder: (_) =>
                        RegattaDetailScreen(db: widget.db, regattaId: r.id))),
              );
            },
          );
        },
      ),
    );
  }
}
