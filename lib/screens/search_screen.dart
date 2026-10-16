import 'package:flutter/material.dart';
import '../database/database.dart';
import '../models/error_tag_x.dart';
import '../models/wind_format.dart';
import '../settings/app_prefs.dart';
import 'race_entry_screen.dart';

enum _Sort { boatFeel, raceScore, wind }

class SearchScreen extends StatefulWidget {
  const SearchScreen({super.key, required this.db, required this.boat});
  final AppDatabase db;
  final Boat boat;

  @override
  State<SearchScreen> createState() => _SearchScreenState();
}

class _SearchScreenState extends State<SearchScreen> {
  // The sliders work in the user's own unit; matching converts to knots.
  final bool _ms = AppPrefs.windUnit.value == WindUnit.ms;
  late double _center = _ms ? 6 : 12;
  late double _tolerance = _ms ? 1 : 2;
  bool _filterByWind = true;
  bool _includeFlagged = true;
  _Sort _sort = _Sort.boatFeel;

  List<RaceEvent> _all = [];
  bool _loading = true;

  @override
  void initState() {
    super.initState();
    _load();
  }

  Future<void> _load() async {
    final events = await (widget.db.select(widget.db.raceEvents)
          ..where((r) => r.boatId.equals(widget.boat.id)))
        .get();
    if (!mounted) return;
    setState(() {
      _all = events;
      _loading = false;
    });
  }

  // --- Unit helpers --------------------------------------------------

  String get _u => _ms ? 'm/s' : 'kt';
  double _toKt(double v) => _ms ? msToKt(v) : v;
  String _centerText(double v) => '${v.toStringAsFixed(_ms ? 1 : 0)} $_u';
  String _tolText(double v) => '${v.toStringAsFixed(_ms ? 2 : 1)} $_u';

  // --- Data helpers --------------------------------------------------

  /// Single representative wind value: the quick-entry value, or the
  /// midpoint of the range if only a range exists.
  double? _windMid(RaceEvent r) {
    if (r.windSpeedKt != null) return r.windSpeedKt;
    if (r.windSpeedMinKt != null && r.windSpeedMaxKt != null) {
      return (r.windSpeedMinKt! + r.windSpeedMaxKt!) / 2;
    }
    return null;
  }

  /// Ranges match if they overlap the search window; single values match
  /// if they fall inside it.
  bool _matchesWind(RaceEvent r) {
    final lo = _toKt(_center - _tolerance);
    final hi = _toKt(_center + _tolerance);
    final min = r.windSpeedMinKt;
    final max = r.windSpeedMaxKt;
    if (min != null && max != null) {
      return min <= hi && max >= lo;
    }
    final single = r.windSpeedKt;
    return single != null && single >= lo && single <= hi;
  }

  String _windLabel(RaceEvent r) {
    final min = r.windSpeedMinKt;
    final max = r.windSpeedMaxKt;
    if (min != null && max != null && min != max) {
      return formatWindRange(min, max);
    }
    final w = _windMid(r);
    return w == null ? 'no wind logged' : formatWind(w);
  }

  /// Compares numbers with missing values always last.
  int _cmp(num? a, num? b, {required bool descending}) {
    if (a == null && b == null) return 0;
    if (a == null) return 1;
    if (b == null) return -1;
    return descending ? b.compareTo(a) : a.compareTo(b);
  }

  List<RaceEvent> get _visible {
    final list = _all.where((r) {
      if (!_includeFlagged && r.errorTags.isNotEmpty) return false;
      if (_filterByWind && !_matchesWind(r)) return false;
      return true;
    }).toList();

    list.sort((a, b) {
      int c;
      switch (_sort) {
        case _Sort.boatFeel:
          c = _cmp(a.boatFeelScore, b.boatFeelScore, descending: true);
          if (c == 0) c = _cmp(a.raceScore, b.raceScore, descending: true);
          break;
        case _Sort.raceScore:
          c = _cmp(a.raceScore, b.raceScore, descending: true);
          if (c == 0) {
            c = _cmp(a.boatFeelScore, b.boatFeelScore, descending: true);
          }
          break;
        case _Sort.wind:
          c = _cmp(_windMid(a), _windMid(b), descending: false);
          if (c == 0) {
            c = _cmp(a.boatFeelScore, b.boatFeelScore, descending: true);
          }
          break;
      }
      // Final tie-break: newest first.
      return c != 0 ? c : b.date.compareTo(a.date);
    });
    return list;
  }

  // --- UI ------------------------------------------------------------

  @override
  Widget build(BuildContext context) {
    final results = _visible;
    final lo = (_center - _tolerance).clamp(0, 999);
    final hi = _center + _tolerance;
    final digits = _ms ? 1 : 0;

    return Scaffold(
      appBar: AppBar(title: const Text('Search trims')),
      body: Column(
        children: [
          Padding(
            padding: const EdgeInsets.fromLTRB(16, 8, 16, 0),
            child: Column(
              children: [
                SwitchListTile(
                  contentPadding: EdgeInsets.zero,
                  title: const Text('Only show this wind range'),
                  subtitle: Text(_filterByWind
                      ? '${lo.toStringAsFixed(digits)}-${hi.toStringAsFixed(digits)} $_u'
                      : 'Showing everything'),
                  value: _filterByWind,
                  onChanged: (v) => setState(() => _filterByWind = v),
                ),
                Opacity(
                  opacity: _filterByWind ? 1 : 0.4,
                  child: IgnorePointer(
                    ignoring: !_filterByWind,
                    child: Column(
                      children: [
                        Row(
                          children: [
                            const SizedBox(width: 56, child: Text('Wind')),
                            Expanded(
                              child: Slider(
                                value: _center,
                                min: _ms ? 1 : 2,
                                max: _ms ? 15 : 30,
                                divisions: 28,
                                label: _centerText(_center),
                                onChanged: (v) => setState(() => _center = v),
                              ),
                            ),
                            SizedBox(
                                width: 68, child: Text(_centerText(_center))),
                          ],
                        ),
                        Row(
                          children: [
                            const SizedBox(width: 56, child: Text('+/-')),
                            Expanded(
                              child: Slider(
                                value: _tolerance,
                                min: 0,
                                max: _ms ? 3 : 6,
                                divisions: 12,
                                label: _tolText(_tolerance),
                                onChanged: (v) =>
                                    setState(() => _tolerance = v),
                              ),
                            ),
                            SizedBox(
                                width: 68, child: Text(_tolText(_tolerance))),
                          ],
                        ),
                      ],
                    ),
                  ),
                ),
                SwitchListTile(
                  contentPadding: EdgeInsets.zero,
                  title: const Text('Include races with error flags'),
                  value: _includeFlagged,
                  onChanged: (v) => setState(() => _includeFlagged = v),
                ),
                const SizedBox(height: 4),
                SizedBox(
                  width: double.infinity,
                  child: SegmentedButton<_Sort>(
                    segments: const [
                      ButtonSegment(
                          value: _Sort.boatFeel, label: Text('Boat feel')),
                      ButtonSegment(
                          value: _Sort.raceScore, label: Text('Race score')),
                      ButtonSegment(value: _Sort.wind, label: Text('Wind')),
                    ],
                    selected: {_sort},
                    onSelectionChanged: (s) => setState(() => _sort = s.first),
                  ),
                ),
                Align(
                  alignment: Alignment.centerLeft,
                  child: Padding(
                    padding: const EdgeInsets.symmetric(vertical: 8),
                    child: Text(
                      '${results.length} result${results.length == 1 ? '' : 's'}'
                      '${_sort == _Sort.wind ? ' · lowest wind first' : ' · best first'}',
                      style: Theme.of(context).textTheme.bodySmall,
                    ),
                  ),
                ),
              ],
            ),
          ),
          const Divider(height: 1),
          Expanded(
            child: _loading
                ? const Center(child: CircularProgressIndicator())
                : results.isEmpty
                    ? Center(
                        child: Text(
                          _filterByWind
                              ? 'No matching trims in this wind range.\nTurn off the range switch to see everything.'
                              : 'Nothing logged yet.',
                          textAlign: TextAlign.center,
                        ),
                      )
                    : ListView.builder(
                        itemCount: results.length,
                        itemBuilder: (context, i) {
                          final r = results[i];
                          final flagged = r.errorTags.isNotEmpty;
                          final isRegatta = r.type == EventType.regattaRace;
                          return ListTile(
                            leading: CircleAvatar(
                              child: Text('${r.boatFeelScore ?? '-'}'),
                            ),
                            title: Text(
                                '${_windLabel(r)}  ·  jib car ${r.jibCarPosition ?? '--'}  ·  sheet ${r.sheetMarker ?? '--'}'),
                            subtitle: Text(
                              '${isRegatta ? 'Race ${r.raceNumber ?? ''}' : 'Practice'} · '
                              'race score ${r.raceScore ?? '--'} · '
                              'rake ${r.rakeMm ?? '--'}mm · '
                              'in-hauler ${r.inhaulerMarker ?? '--'} · '
                              'shrouds ${r.innerShroudTurns ?? '--'}/${r.outerShroudTurns ?? '--'}'
                              '${flagged ? '  ⚠ ${errorTagsLabel(r.errorTags)}' : ''}',
                            ),
                            isThreeLine: true,
                            onTap: () async {
                              await Navigator.of(context).push(
                                MaterialPageRoute(
                                  builder: (_) => RaceEntryScreen(
                                    db: widget.db,
                                    draft: r.toCompanion(true),
                                    title: isRegatta
                                        ? 'Race ${r.raceNumber}'
                                        : 'Practice',
                                  ),
                                ),
                              );
                              _load();
                            },
                          );
                        },
                      ),
          ),
        ],
      ),
    );
  }
}
