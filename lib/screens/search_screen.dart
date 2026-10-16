import 'package:flutter/material.dart';
import '../database/database.dart';
import '../models/custom_field_x.dart';
import '../models/error_tag_x.dart';
import '../models/wind_format.dart';
import '../settings/app_prefs.dart';
import 'race_entry_screen.dart';

/// One active custom-field filter.
class _CustomFilter {
  _CustomFilter(this.def);
  final CustomFieldDefinition def;
  double? min;
  double? max;
  Set<String> options = {};

  String get summary {
    if (def.fieldType == CustomFieldType.enumType) {
      return options.join(' or ');
    }
    final unit = (def.unit == null || def.unit!.isEmpty) ? '' : ' ${def.unit}';
    String n(double v) =>
        v == v.roundToDouble() ? v.toStringAsFixed(0) : v.toString();
    if (min != null && max != null) return '${n(min!)}-${n(max!)}$unit';
    if (min != null) return 'at least ${n(min!)}$unit';
    return 'at most ${n(max!)}$unit';
  }
}

class _SortKey {
  const _SortKey(this.id, this.label, {required this.defaultDescending});
  final String id;
  final String label;
  final bool defaultDescending;
}

const _builtInSorts = [
  _SortKey('feel', 'Boat feel', defaultDescending: true),
  _SortKey('score', 'Race score', defaultDescending: true),
  _SortKey('wind', 'Wind speed', defaultDescending: false),
];

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

  String _sortId = 'feel';
  bool _descending = true;
  final List<_CustomFilter> _filters = [];

  List<RaceEvent> _all = [];
  List<CustomFieldDefinition> _defs = [];
  // raceId -> (fieldDefinitionId -> stored value)
  Map<String, Map<String, String>> _values = {};
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
    final defs = await widget.db.allCustomFields(widget.boat.id);

    final ids = events.map((e) => e.id).toSet();
    final rows = await widget.db.select(widget.db.customFieldValues).get();
    final values = <String, Map<String, String>>{};
    for (final v in rows) {
      if (ids.contains(v.raceEventId)) {
        values.putIfAbsent(v.raceEventId, () => {})[v.fieldDefinitionId] =
            v.value;
      }
    }

    if (!mounted) return;
    setState(() {
      _all = events;
      _defs = defs;
      _values = values;
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

  bool _matchesCustom(RaceEvent r) {
    for (final f in _filters) {
      final raw = _values[r.id]?[f.def.id];
      if (raw == null || raw.isEmpty) return false;

      if (f.def.fieldType == CustomFieldType.enumType) {
        if (f.options.isNotEmpty && !f.options.contains(raw)) return false;
      } else {
        final n = double.tryParse(raw);
        if (n == null) return false;
        if (f.min != null && n < f.min!) return false;
        if (f.max != null && n > f.max!) return false;
      }
    }
    return true;
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

  /// Custom values (numbers and choices) for one race, as one line.
  String _customLine(RaceEvent r) {
    final vals = _values[r.id];
    if (vals == null || vals.isEmpty) return '';
    final parts = <String>[];
    for (final d in _defs) {
      if (d.fieldType == CustomFieldType.textType) continue;
      final v = vals[d.id];
      if (v == null || v.isEmpty) continue;
      final unit = (d.unit == null || d.unit!.isEmpty) ? '' : ' ${d.unit}';
      parts.add('${d.name} $v$unit');
    }
    return parts.join(' · ');
  }

  // --- Sorting -------------------------------------------------------

  List<_SortKey> get _sortKeys => [
        ..._builtInSorts,
        for (final d in _defs)
          if (d.fieldType.isNumeric)
            _SortKey('custom:${d.id}', d.name, defaultDescending: false),
      ];

  num? _sortValue(RaceEvent r, String id) {
    switch (id) {
      case 'feel':
        return r.boatFeelScore;
      case 'score':
        return r.raceScore;
      case 'wind':
        return _windMid(r);
      default:
        final defId = id.substring('custom:'.length);
        final raw = _values[r.id]?[defId];
        return raw == null ? null : double.tryParse(raw);
    }
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
      if (!_matchesCustom(r)) return false;
      return true;
    }).toList();

    list.sort((a, b) {
      var c = _cmp(_sortValue(a, _sortId), _sortValue(b, _sortId),
          descending: _descending);
      if (c == 0) {
        // Tie-break on how the boat felt, or on race score if that's
        // what we're already sorting by.
        c = _sortId == 'feel'
            ? _cmp(a.raceScore, b.raceScore, descending: true)
            : _cmp(a.boatFeelScore, b.boatFeelScore, descending: true);
      }
      // Final tie-break: newest first.
      return c != 0 ? c : b.date.compareTo(a.date);
    });
    return list;
  }

  String get _sortSummary {
    final keys = _sortKeys;
    final key = keys.firstWhere((k) => k.id == _sortId,
        orElse: () => _builtInSorts.first);
    return '${key.label}, ${_descending ? 'high to low' : 'low to high'}';
  }

  // --- Custom field filters ------------------------------------------

  String _plain(double v) =>
      v == v.roundToDouble() ? v.toStringAsFixed(0) : v.toString();

  double? _parse(String text) =>
      double.tryParse(text.trim().replaceAll(',', '.'));

  Future<void> _addFilter() async {
    final available = _defs
        .where((d) =>
            d.fieldType != CustomFieldType.textType &&
            !_filters.any((f) => f.def.id == d.id))
        .toList();
    if (available.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(const SnackBar(
          content: Text('You are already filtering on every custom field')));
      return;
    }

    final def = await showModalBottomSheet<CustomFieldDefinition>(
      context: context,
      showDragHandle: true,
      builder: (context) => SafeArea(
        child: ListView(
          shrinkWrap: true,
          children: [
            const Padding(
              padding: EdgeInsets.fromLTRB(24, 0, 24, 8),
              child: Align(
                alignment: Alignment.centerLeft,
                child: Text('Filter by which field?'),
              ),
            ),
            for (final d in available)
              ListTile(
                title: Text(d.name),
                subtitle: Text(
                    '${d.fieldType.label}${d.active ? '' : ' · hidden'}'),
                onTap: () => Navigator.pop(context, d),
              ),
          ],
        ),
      ),
    );
    if (def == null || !mounted) return;

    final filter = _CustomFilter(def);
    final saved = await _editFilter(filter);
    if (saved && mounted) setState(() => _filters.add(filter));
  }

  /// Opens the editor for a filter. Returns true if it was applied.
  Future<bool> _editFilter(_CustomFilter f) async {
    final numeric = f.def.fieldType.isNumeric;
    final minC =
        TextEditingController(text: f.min == null ? '' : _plain(f.min!));
    final maxC =
        TextEditingController(text: f.max == null ? '' : _plain(f.max!));
    final chosen = {...f.options};
    String? error;
    double? newMin;
    double? newMax;

    final ok = await showDialog<bool>(
      context: context,
      builder: (context) => StatefulBuilder(
        builder: (context, setLocal) => AlertDialog(
          title: Text(f.def.name),
          content: SingleChildScrollView(
            child: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                if (numeric) ...[
                  Row(
                    children: [
                      Expanded(
                        child: TextField(
                          controller: minC,
                          keyboardType: const TextInputType.numberWithOptions(
                              decimal: true, signed: true),
                          decoration: const InputDecoration(labelText: 'Min'),
                        ),
                      ),
                      const SizedBox(width: 12),
                      Expanded(
                        child: TextField(
                          controller: maxC,
                          keyboardType: const TextInputType.numberWithOptions(
                              decimal: true, signed: true),
                          decoration: const InputDecoration(labelText: 'Max'),
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 8),
                  Text(
                    'Fill in one or both.'
                    '${(f.def.unit == null || f.def.unit!.isEmpty) ? '' : ' Unit: ${f.def.unit}.'}',
                    style: Theme.of(context).textTheme.bodySmall,
                  ),
                ] else ...[
                  Text('Match any of:',
                      style: Theme.of(context).textTheme.bodySmall),
                  const SizedBox(height: 8),
                  Wrap(
                    spacing: 8,
                    runSpacing: 4,
                    children: [
                      for (final o in f.def.options)
                        FilterChip(
                          label: Text(o),
                          selected: chosen.contains(o),
                          onSelected: (on) => setLocal(() {
                            if (on) {
                              chosen.add(o);
                            } else {
                              chosen.remove(o);
                            }
                          }),
                        ),
                    ],
                  ),
                ],
                if (error != null)
                  Padding(
                    padding: const EdgeInsets.only(top: 12),
                    child: Text(error!,
                        style: TextStyle(
                            color: Theme.of(context).colorScheme.error)),
                  ),
              ],
            ),
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(context, false),
              child: const Text('Cancel'),
            ),
            FilledButton(
              onPressed: () {
                if (numeric) {
                  final minText = minC.text.trim();
                  final maxText = maxC.text.trim();
                  final lo = minText.isEmpty ? null : _parse(minText);
                  final hi = maxText.isEmpty ? null : _parse(maxText);
                  if ((minText.isNotEmpty && lo == null) ||
                      (maxText.isNotEmpty && hi == null)) {
                    setLocal(() => error = 'Enter numbers only');
                    return;
                  }
                  if (lo == null && hi == null) {
                    setLocal(() => error = 'Fill in a min, a max, or both');
                    return;
                  }
                  if (lo != null && hi != null && lo > hi) {
                    setLocal(() => error = 'Min is higher than max');
                    return;
                  }
                  newMin = lo;
                  newMax = hi;
                } else if (chosen.isEmpty) {
                  setLocal(() => error = 'Pick at least one option');
                  return;
                }
                Navigator.pop(context, true);
              },
              child: const Text('Apply'),
            ),
          ],
        ),
      ),
    );

    minC.dispose();
    maxC.dispose();
    if (ok != true) return false;

    f.min = newMin;
    f.max = newMax;
    f.options = chosen;
    return true;
  }

  // --- UI ------------------------------------------------------------

  @override
  Widget build(BuildContext context) {
    final results = _visible;
    final lo = (_center - _tolerance).clamp(0, 999);
    final hi = _center + _tolerance;
    final digits = _ms ? 1 : 0;
    final sortKeys = _sortKeys;
    final currentSort = sortKeys.any((k) => k.id == _sortId) ? _sortId : 'feel';
    final hasFilterableFields =
        _defs.any((d) => d.fieldType != CustomFieldType.textType);

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
                if (hasFilterableFields)
                  Align(
                    alignment: Alignment.centerLeft,
                    child: Wrap(
                      spacing: 8,
                      runSpacing: 4,
                      crossAxisAlignment: WrapCrossAlignment.center,
                      children: [
                        for (final f in _filters)
                          InputChip(
                            label: Text('${f.def.name}: ${f.summary}'),
                            onPressed: () async {
                              final saved = await _editFilter(f);
                              if (saved && mounted) setState(() {});
                            },
                            onDeleted: () =>
                                setState(() => _filters.remove(f)),
                          ),
                        ActionChip(
                          avatar: const Icon(Icons.add, size: 18),
                          label: const Text('Filter by custom field'),
                          onPressed: _addFilter,
                        ),
                      ],
                    ),
                  ),
                const SizedBox(height: 8),
                Row(
                  children: [
                    Expanded(
                      child: DropdownButtonFormField<String>(
                        value: currentSort,
                        isExpanded: true,
                        decoration: const InputDecoration(
                            labelText: 'Sort by', isDense: true),
                        items: [
                          for (final k in sortKeys)
                            DropdownMenuItem(
                              value: k.id,
                              child: Text(k.label,
                                  overflow: TextOverflow.ellipsis),
                            ),
                        ],
                        onChanged: (id) {
                          if (id == null) return;
                          final key = sortKeys.firstWhere((k) => k.id == id);
                          setState(() {
                            _sortId = id;
                            _descending = key.defaultDescending;
                          });
                        },
                      ),
                    ),
                    IconButton(
                      tooltip: _descending
                          ? 'High to low (tap to reverse)'
                          : 'Low to high (tap to reverse)',
                      icon: Icon(_descending
                          ? Icons.arrow_downward
                          : Icons.arrow_upward),
                      onPressed: () =>
                          setState(() => _descending = !_descending),
                    ),
                  ],
                ),
                Align(
                  alignment: Alignment.centerLeft,
                  child: Padding(
                    padding: const EdgeInsets.symmetric(vertical: 8),
                    child: Text(
                      '${results.length} result${results.length == 1 ? '' : 's'}'
                      ' · $_sortSummary',
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
                          (_filterByWind || _filters.isNotEmpty)
                              ? 'No matching trims.\nLoosen the wind range or the filters to see more.'
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
                          final custom = _customLine(r);
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
                              '${custom.isEmpty ? '' : '\n$custom'}'
                              '${flagged ? '\n⚠ ${errorTagsLabel(r.errorTags)}' : ''}',
                            ),
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