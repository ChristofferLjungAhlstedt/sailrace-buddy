import 'package:flutter/material.dart';
import '../database/database.dart';

class SearchScreen extends StatefulWidget {
  const SearchScreen({super.key, required this.db, required this.boat});
  final AppDatabase db;
  final Boat boat;

  @override
  State<SearchScreen> createState() => _SearchScreenState();
}

class _SearchScreenState extends State<SearchScreen> {
  double _center = 12;
  double _tolerance = 2;
  List<RaceEvent> _results = [];
  bool _includeFlagged = true;

  Future<void> _search() async {
    final results = await widget.db.bestTrimsForWind(
      minKt: _center - _tolerance,
      maxKt: _center + _tolerance,
      includeFlagged: _includeFlagged,
    );
    setState(() => _results = results.where((r) => r.boatId == widget.boat.id).toList());
  }

  @override
  void initState() {
    super.initState();
    _search();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('Search best trim')),
      body: Column(
        children: [
          Padding(
            padding: const EdgeInsets.all(16),
            child: Column(
              children: [
                Row(
                  children: [
                    const Text('Wind speed'),
                    Expanded(
                      child: Slider(
                        value: _center,
                        min: 2,
                        max: 30,
                        divisions: 28,
                        label: '${_center.round()} kt',
                        onChanged: (v) => setState(() => _center = v),
                        onChangeEnd: (_) => _search(),
                      ),
                    ),
                    Text('${_center.round()} kt'),
                  ],
                ),
                Row(
                  children: [
                    const Text('+/- range'),
                    Expanded(
                      child: Slider(
                        value: _tolerance,
                        min: 0,
                        max: 6,
                        divisions: 12,
                        label: '${_tolerance.toStringAsFixed(1)} kt',
                        onChanged: (v) => setState(() => _tolerance = v),
                        onChangeEnd: (_) => _search(),
                      ),
                    ),
                  ],
                ),
                SwitchListTile(
                  title: const Text('Include races with error flags'),
                  value: _includeFlagged,
                  onChanged: (v) {
                    setState(() => _includeFlagged = v);
                    _search();
                  },
                ),
              ],
            ),
          ),
          const Divider(height: 1),
          Expanded(
            child: _results.isEmpty
                ? const Center(child: Text('No matching trims found for this range.'))
                : ListView.builder(
                    itemCount: _results.length,
                    itemBuilder: (context, i) {
                      final r = _results[i];
                      final flagged = r.errorTags.isNotEmpty;
                      return ListTile(
                        leading: CircleAvatar(
                          child: Text('${r.boatFeelScore ?? '-'}'),
                        ),
                        title: Text(
                            'Jib car ${r.jibCarPosition ?? '--'}  ·  sheet ${r.sheetMarker ?? '--'}'),
                        subtitle: Text(
                            'Rake ${r.rakeMm ?? '--'}mm · in-hauler ${r.inhaulerMarker ?? '--'} · '
                            'shrouds ${r.innerShroudTurns ?? '--'}/${r.outerShroudTurns ?? '--'} · '
                            '${r.windSpeedKt?.toStringAsFixed(0) ?? '--'} kt'
                            '${flagged ? '  ⚠ ${r.errorTags}' : ''}'),
                      );
                    },
                  ),
          ),
        ],
      ),
    );
  }
}
