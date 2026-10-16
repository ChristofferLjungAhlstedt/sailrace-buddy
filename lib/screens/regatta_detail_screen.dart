import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import '../database/database.dart';
import '../repositories/race_repository.dart';
import 'race_entry_screen.dart';
import 'regatta_form_screen.dart';

class RegattaDetailScreen extends StatefulWidget {
  const RegattaDetailScreen({super.key, required this.db, required this.regattaId});
  final AppDatabase db;
  final String regattaId;

  @override
  State<RegattaDetailScreen> createState() => _RegattaDetailScreenState();
}

class _RegattaDetailScreenState extends State<RegattaDetailScreen> {
  Regatta? _regatta;

  @override
  void initState() {
    super.initState();
    _load();
  }

  Future<void> _load() async {
    final r = await (widget.db.select(widget.db.regattas)
          ..where((t) => t.id.equals(widget.regattaId)))
        .getSingle();
    setState(() => _regatta = r);
  }

  Future<void> _addRace() async {
    final repo = RaceRepository(widget.db);
    final draft = await repo.buildDraftForNewRace(
        boatId: _regatta!.boatId, regattaId: widget.regattaId);
    if (!mounted) return;
    await Navigator.of(context).push(MaterialPageRoute(
      builder: (_) => RaceEntryScreen(
        db: widget.db,
        draft: draft,
        title: 'Race ${draft.raceNumber.value}',
      ),
    ));
    setState(() {});
  }

  // Future<void> _editRegattaField(
  //     String field, String initial, void Function(String) apply) async {
  //   final controller = TextEditingController(text: initial);
  //   final result = await showDialog<String>(
  //     context: context,
  //     builder: (context) => AlertDialog(
  //       title: Text('Edit $field'),
  //       content: TextField(controller: controller, autofocus: true),
  //       actions: [
  //         TextButton(
  //             onPressed: () => Navigator.pop(context, controller.text),
  //             child: const Text('Save')),
  //       ],
  //     ),
  //   );
  //   if (result != null) apply(result);
  // }

  @override
  Widget build(BuildContext context) {
    final regatta = _regatta;
    if (regatta == null) {
      return const Scaffold(body: Center(child: CircularProgressIndicator()));
    }

    final raceQuery = widget.db.select(widget.db.raceEvents)
      ..where((r) => r.regattaId.equals(widget.regattaId))
      ..orderBy([(r) => OrderingTerm.asc(r.raceNumber)]);

    return Scaffold(
      appBar: AppBar(
        title: Text(regatta.name),
        actions: [
          IconButton(
            icon: const Icon(Icons.edit),
            tooltip: 'Edit regatta setup',
            onPressed: () async {
              final changed = await Navigator.of(context).push<bool>(
                MaterialPageRoute(
                  builder: (_) => RegattaFormScreen(
                    db: widget.db,
                    boatId: regatta.boatId,
                    existing: regatta,
                  ),
                ),
              );
              if (changed == true) _load();
            },
          ),
        ],
      ),
      floatingActionButton: FloatingActionButton.extended(
        onPressed: _addRace,
        icon: const Icon(Icons.add),
        label: const Text('Add race'),
      ),
      body: ListView(
        padding: const EdgeInsets.all(16),
        children: [
          Card(
            child: Padding(
              padding: const EdgeInsets.all(12),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text('Regatta setup', style: Theme.of(context).textTheme.titleSmall),
                  const SizedBox(height: 8),
                  _infoRow('Rake', '${regatta.rakeMm ?? '--'} mm'),
                  _infoRow('Jib', '${regatta.jibSailmaker} ${regatta.jibDesign}'),
                  _infoRow('Main', '${regatta.mainSailmaker} ${regatta.mainDesign}'),
                  _infoRow('Gennaker',
                      '${regatta.gennakerSailmaker} ${regatta.gennakerDesign}'),
                  const SizedBox(height: 4),
                  Text(
                    'Edit here to change what future races prefill. '
                    'Existing races keep their own copy.',
                    style: Theme.of(context).textTheme.bodySmall,
                  ),
                ],
              ),
            ),
          ),
          const SizedBox(height: 16),
          Text('Races', style: Theme.of(context).textTheme.titleSmall),
          StreamBuilder<List<RaceEvent>>(
            stream: raceQuery.watch(),
            builder: (context, snapshot) {
              final races = snapshot.data ?? [];
              if (races.isEmpty) {
                return const Padding(
                  padding: EdgeInsets.symmetric(vertical: 16),
                  child: Text('No races logged yet.'),
                );
              }
              return Column(
                children: races.map((r) {
                  return ListTile(
                    title: Text('Race ${r.raceNumber ?? '?'}'),
                    subtitle: Text(r.windSpeedKt != null
                        ? '${r.windSpeedKt!.toStringAsFixed(0)} kt · ${r.waveState?.name ?? ''}'
                        : 'No conditions logged'),
                    trailing: r.raceScore != null ? Text('Score: ${r.raceScore}/5') : null,
                    onTap: () async {
                      await Navigator.of(context).push(MaterialPageRoute(
                        builder: (_) => RaceEntryScreen(
                          db: widget.db,
                          draft: r.toCompanion(true),
                          title: 'Race ${r.raceNumber}',
                        ),
                      ));
                      setState(() {});
                    },
                  );
                }).toList(),
              );
            },
          ),
          const SizedBox(height: 24),
          Text('Post-regatta review', style: Theme.of(context).textTheme.titleSmall),
          const SizedBox(height: 8),
          TextFormField(
            initialValue: regatta.reviewNotes ?? '',
            decoration: const InputDecoration(
                labelText: 'How did the regatta go overall?', border: OutlineInputBorder()),
            maxLines: 3,
            onChanged: (v) => widget.db.update(widget.db.regattas).replace(
                regatta.copyWith(reviewNotes: Value(v))),
          ),
        ],
      ),
    );
  }

  Widget _infoRow(String label, String value) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 2),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          Text(label, style: Theme.of(context).textTheme.bodySmall),
          Text(value),
        ],
      ),
    );
  }
}
