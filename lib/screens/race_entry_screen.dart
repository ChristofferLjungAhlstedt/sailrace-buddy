import 'package:flutter/material.dart';
import '../database/database.dart';
import '../repositories/race_repository.dart';
import '../widgets/stepper_field.dart';
import '../widgets/wind_speed_field.dart';
import '../widgets/linked_score.dart';
import '../models/custom_field_x.dart';
import '../models/error_tag_x.dart';
import '../settings/app_prefs.dart';

/// Handles both "new regatta race" and "new/edit practice event" - same
/// schema, same form, only the prefill source differs (handled upstream
/// in RaceRepository before this screen is opened).
class RaceEntryScreen extends StatefulWidget {
  const RaceEntryScreen({
    super.key,
    required this.db,
    required this.draft,
    required this.title,
    this.useMs = false,
  });

  final AppDatabase db;
  final RaceEventsCompanion draft;
  final String title;
  final bool useMs;

  @override
  State<RaceEntryScreen> createState() => _RaceEntryScreenState();
}

class _RaceEntryScreenState extends State<RaceEntryScreen> {
  late RaceEventsCompanion _d;
  bool _sailsExpanded = false;
  bool _exists = false;
  List<CustomFieldDefinition> _customDefs = [];
  Map<String, String> _customValues = {};

  void _setCustom(String defId, String? value) {
    setState(() {
      if (value == null || value.isEmpty) {
        _customValues.remove(defId);
      } else {
        _customValues[defId] = value;
      }
    });
  }

  String _trimNum(double v) {
    final s = ((v * 100).round() / 100).toString();
    return s.endsWith('.0') ? s.substring(0, s.length - 2) : s;
  }

  String _plainNum(double v) =>
      v == v.roundToDouble() ? v.toStringAsFixed(0) : v.toString();

  String _baselineCaption(double? b) =>
      b == null ? 'No baseline set' : 'Baseline ${_plainNum(b)}';

  Widget _decimalField(
      String label, double? value, ValueChanged<double?> onChanged) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 8),
      child: TextFormField(
        initialValue: value == null ? '' : _plainNum(value),
        keyboardType: const TextInputType.numberWithOptions(decimal: true),
        decoration: InputDecoration(labelText: label, isDense: true),
        onChanged: (text) {
          final t = text.trim();
          if (t.isEmpty) {
            onChanged(null);
            return;
          }
          // Ignore half-typed input like "-" until it parses.
          final parsed = double.tryParse(t.replaceAll(',', '.'));
          if (parsed != null) onChanged(parsed);
        },
      ),
    );
  }

  Widget _customFieldsSection() {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Padding(
          padding: const EdgeInsets.only(bottom: 8),
          child: Text('Custom fields',
              style: Theme.of(context).textTheme.labelLarge),
        ),
        LayoutBuilder(builder: (context, constraints) {
          final half = (constraints.maxWidth - 8) / 2;
          return Wrap(
            spacing: 8,
            runSpacing: 8,
            children: [
              for (final def in _customDefs)
                SizedBox(
                  width: def.fieldType == CustomFieldType.textType
                      ? constraints.maxWidth
                      : half,
                  child: _customFieldWidget(def),
                ),
            ],
          );
        }),
      ],
    );
  }

  Widget _customFieldWidget(CustomFieldDefinition def) {
    final raw = _customValues[def.id];

    switch (def.fieldType) {
      case CustomFieldType.intType:
      case CustomFieldType.floatType:
        final isInt = def.fieldType == CustomFieldType.intType;
        final unit = def.unit;
        return StepperField(
          label: def.name,
          value: raw == null ? null : double.tryParse(raw),
          step: isInt ? 1 : 0.5,
          decimals: isInt ? 0 : 2,
          trimZeros: !isInt,
          suffix: unit == null || unit.isEmpty ? '' : ' $unit',
          onChanged: (v) =>
              _setCustom(def.id, isInt ? v.round().toString() : _trimNum(v)),
          onCleared: () => _setCustom(def.id, null),
        );

      case CustomFieldType.enumType:
        final options = def.options;
        final current = (raw == null || raw.isEmpty) ? null : raw;
        return Container(
          padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
          decoration: BoxDecoration(
            color: Theme.of(context).colorScheme.surfaceContainerHighest,
            borderRadius: BorderRadius.circular(12),
          ),
          child: DropdownButtonHideUnderline(
            child: DropdownButtonFormField<String>(
              decoration: InputDecoration(
                  labelText: def.name, border: InputBorder.none),
              isExpanded: true,
              value: current,
              items: [
                const DropdownMenuItem<String>(value: null, child: Text('—')),
                for (final o in options)
                  DropdownMenuItem(value: o, child: Text(o)),
                // A value from an option that was later removed.
                if (current != null && !options.contains(current))
                  DropdownMenuItem(
                      value: current, child: Text('$current (removed)')),
              ],
              onChanged: (v) => _setCustom(def.id, v),
            ),
          ),
        );

      case CustomFieldType.textType:
        return TextFormField(
          key: ValueKey('custom-${def.id}'),
          initialValue: raw ?? '',
          decoration: InputDecoration(
            labelText: def.name,
            border: const OutlineInputBorder(),
            isDense: true,
          ),
          // No setState here, so the cursor doesn't jump while typing.
          onChanged: (v) => _customValues[def.id] = v,
        );
    }
  }

  @override
  void initState() {
    super.initState();
    final d = widget.draft;

    // Absent fields have a null .value. Fill in the same defaults the
    // database would apply, so the form can read them safely.
    Value<T> orDefault<T>(Value<T> v, T fallback) =>
        v.present ? v : Value(fallback);

    _d = d.copyWith(
      windSpeedLinked: orDefault(d.windSpeedLinked, true),
      scoreLinked: orDefault(d.scoreLinked, true),
      errorTags: orDefault(d.errorTags, ''),
      jibSailmaker: orDefault(d.jibSailmaker, ''),
      jibDesign: orDefault(d.jibDesign, ''),
      jibSailId: orDefault(d.jibSailId, ''),
      mainSailmaker: orDefault(d.mainSailmaker, ''),
      mainDesign: orDefault(d.mainDesign, ''),
      mainSailId: orDefault(d.mainSailId, ''),
      gennakerSailmaker: orDefault(d.gennakerSailmaker, ''),
      gennakerDesign: orDefault(d.gennakerDesign, ''),
      gennakerSailId: orDefault(d.gennakerSailId, ''),
    );

    _checkExists();
  }

  void _update(RaceEventsCompanion Function(RaceEventsCompanion) f) {
    setState(() => _d = f(_d));
  }

  Future<void> _save() async {
    final repo = RaceRepository(widget.db);
    await repo.save(_d.copyWith(updatedAt: Value(DateTime.now())));
    await widget.db.saveCustomValues(
      raceId: _d.id.value,
      definitionIds: _customDefs.map((d) => d.id),
      values: _customValues,
    );
    if (mounted) Navigator.of(context).pop();
  }

  Future<void> _checkExists() async {
    final id = widget.draft.id.value;
    final row = await (widget.db.select(widget.db.raceEvents)
          ..where((r) => r.id.equals(id)))
        .getSingleOrNull();
    final exists = row != null;
    if (mounted) setState(() => _exists = exists);
    await _loadCustomFields(exists: exists);
  }

  Future<void> _loadCustomFields({required bool exists}) async {
    final defs = await widget.db.activeCustomFields(widget.draft.boatId.value);
    var values = <String, String>{};

    if (exists) {
      values = await widget.db.customValuesForRace(widget.draft.id.value);
    } else {
      // New regatta race: chain numbers and choices from the previous race.
      // Practice events (no regatta) start blank. Free text isn't copied.
      final regattaId = widget.draft.regattaId.value;
      if (regattaId != null) {
        final previous = await widget.db.lastRaceInRegatta(regattaId);
        if (previous != null) {
          final all = await widget.db.customValuesForRace(previous.id);
          final textIds = {
            for (final d in defs)
              if (d.fieldType == CustomFieldType.textType) d.id,
          };
          values = {
            for (final e in all.entries)
              if (!textIds.contains(e.key)) e.key: e.value,
          };
        }
      }
    }

    if (!mounted) return;
    setState(() {
      _customDefs = defs;
      _customValues = values;
    });
  }

  Future<void> _confirmDelete() async {
    final ok = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: Text('Delete "${widget.title}"?'),
        content: const Text(
            'This permanently removes its trim, conditions and scores. '
            'It cannot be undone.'),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context, false),
            child: const Text('Cancel'),
          ),
          FilledButton(
            onPressed: () => Navigator.pop(context, true),
            child: const Text('Delete'),
          ),
        ],
      ),
    );
    if (ok != true) return;
    await widget.db.deleteRaceEvent(widget.draft.id.value);
    if (!mounted) return;
    Navigator.of(context).pop();
  }

  @override
  Widget build(BuildContext context) {
    final hasSailInfo =
        (_d.jibDesign.present && _d.jibDesign.value.isNotEmpty) ||
            (_d.mainDesign.present && _d.mainDesign.value.isNotEmpty);

    return Scaffold(
      appBar: AppBar(
        title: Text(widget.title),
        actions: [
          if (_exists)
            IconButton(
              icon: const Icon(Icons.delete_outline),
              tooltip: 'Delete',
              onPressed: _confirmDelete,
            ),
          TextButton(onPressed: _save, child: const Text('Save race')),
        ],
      ),
      body: ListView(
        padding: const EdgeInsets.all(16),
        children: [
          // --- Sail/rig summary, collapsed by default ---
          InkWell(
            onTap: () => setState(() => _sailsExpanded = !_sailsExpanded),
            child: Container(
              padding: const EdgeInsets.all(12),
              decoration: BoxDecoration(
                color: Theme.of(context).colorScheme.surfaceContainerHigh,
                borderRadius: BorderRadius.circular(12),
              ),
              child: Row(
                children: [
                  Expanded(
                    child: Text(
                      hasSailInfo
                          ? 'Rake ${_d.rakeMm.value ?? '--'}mm  ·  edit sails, rake and baselines'
                          : 'Add sail, rake and baseline info',
                      style: Theme.of(context).textTheme.bodySmall,
                    ),
                  ),
                  Icon(_sailsExpanded
                      ? Icons.keyboard_arrow_up
                      : Icons.keyboard_arrow_down),
                ],
              ),
            ),
          ),
          if (_sailsExpanded) ...[
            const SizedBox(height: 8),
            _sailRigEditor(),
          ],
          const SizedBox(height: 16),

          // --- Trim variables ---
          LayoutBuilder(
            builder: (context, constraints) {
              final cardWidth = (constraints.maxWidth - 8) / 2;
              final fields = <Widget>[
                StepperField(
                  label: 'Jib car',
                  value: _d.jibCarPosition.value,
                  step: 0.5,
                  decimals: 1,
                  onChanged: (v) =>
                      _update((d) => d.copyWith(jibCarPosition: Value(v))),
                ),
                StepperField(
                  label: 'Sheet marker',
                  value: _d.sheetMarker.value?.toDouble(),
                  onChanged: (v) =>
                      _update((d) => d.copyWith(sheetMarker: Value(v.round()))),
                ),
                StepperField(
                  label: 'In-hauler',
                  value: _d.inhaulerMarker.value?.toDouble(),
                  onChanged: (v) => _update(
                      (d) => d.copyWith(inhaulerMarker: Value(v.round()))),
                ),
                StepperField(
                  label: 'Jib halyard',
                  value: _d.jibHalyardTension.value?.toDouble(),
                  onChanged: (v) => _update(
                      (d) => d.copyWith(jibHalyardTension: Value(v.round()))),
                ),
                StepperField(
                  label: 'Inner shroud',
                  caption: _baselineCaption(_d.innerShroudBaseline.value),
                  value: _d.innerShroudTurns.value,
                  step: 0.5,
                  decimals: 1,
                  suffix: 't',
                  onChanged: (v) =>
                      _update((d) => d.copyWith(innerShroudTurns: Value(v))),
                ),
                StepperField(
                  label: 'Outer shroud',
                  value: _d.outerShroudTurns.value,
                  caption: _baselineCaption(_d.outerShroudBaseline.value),
                  step: 0.5,
                  decimals: 1,
                  suffix: 't',
                  onChanged: (v) =>
                      _update((d) => d.copyWith(outerShroudTurns: Value(v))),
                ),
              ];
              return Wrap(
                spacing: 8,
                runSpacing: 8,
                children: fields
                    .map((f) => SizedBox(width: cardWidth, child: f))
                    .toList(),
              );
            },
          ),
          const SizedBox(height: 8),

          if (_customDefs.isNotEmpty) ...[
            _customFieldsSection(),
            const SizedBox(height: 8),
          ],

          // --- Wind speed ---
          WindSpeedField(
            windSpeedKt: _d.windSpeedKt.value,
            minKt: _d.windSpeedMinKt.value,
            maxKt: _d.windSpeedMaxKt.value,
            linked: _d.windSpeedLinked.value,
            useMs: AppPrefs.windUnit.value == WindUnit.ms,
            onChanged: ({windSpeedKt, minKt, maxKt, required linked}) {
              _update((d) => d.copyWith(
                    windSpeedKt: windSpeedKt != null
                        ? Value(windSpeedKt)
                        : d.windSpeedKt,
                    windSpeedMinKt: Value(minKt),
                    windSpeedMaxKt: Value(maxKt),
                    windSpeedLinked: Value(linked),
                  ));
            },
          ),
          const SizedBox(height: 8),

          // --- Waves + error source ---
          // --- Waves ---
          _dropdownCard<WaveState>(
            label: 'Waves',
            value: _d.waveState.value,
            items: WaveState.values,
            labelBuilder: (w) => w.name,
            onChanged: (v) => _update((d) => d.copyWith(waveState: Value(v))),
          ),
          const SizedBox(height: 8),

          // --- Error source (multi-select) ---
          _errorTagsCard(),

          // --- Scores (linked by default) ---
          LinkedScore(
            label: 'Race score',
            hint: '(sets boat feel too)',
            value: _d.raceScore.value,
            onChanged: (v) => _update((d) => d.copyWith(
                  raceScore: Value(v),
                  boatFeelScore:
                      d.scoreLinked.value ? Value(v) : d.boatFeelScore,
                )),
          ),
          const SizedBox(height: 8),
          LinkedScore(
            label: 'Boat feel',
            hint: _d.scoreLinked.value
                ? '(linked to race score)'
                : '(independent)',
            value: _d.boatFeelScore.value,
            onChanged: (v) => _update((d) => d.copyWith(
                  boatFeelScore: Value(v),
                  scoreLinked: const Value(false),
                )),
          ),
          const SizedBox(height: 8),

          // --- Notes ---
          TextFormField(
            initialValue: _d.notes.value ?? '',
            decoration: const InputDecoration(
              labelText: 'Notes (not analyzed, free text)',
              border: OutlineInputBorder(),
            ),
            maxLines: 3,
            onChanged: (v) => _update((d) => d.copyWith(notes: Value(v))),
          ),
        ],
      ),
    );
  }

  Widget _sailRigEditor() {
    return Column(
      children: [
        _numberField('Rake (mm)', _d.rakeMm.value,
            (v) => _update((d) => d.copyWith(rakeMm: Value(v)))),
        _decimalField('Inner shroud baseline', _d.innerShroudBaseline.value,
            (v) => _update((d) => d.copyWith(innerShroudBaseline: Value(v)))),
        _decimalField('Outer shroud baseline', _d.outerShroudBaseline.value,
            (v) => _update((d) => d.copyWith(outerShroudBaseline: Value(v)))),
        _textField('Jib sailmaker', _d.jibSailmaker.value,
            (v) => _update((d) => d.copyWith(jibSailmaker: Value(v)))),
        _textField('Jib design', _d.jibDesign.value,
            (v) => _update((d) => d.copyWith(jibDesign: Value(v)))),
        _textField('Jib sail ID', _d.jibSailId.value,
            (v) => _update((d) => d.copyWith(jibSailId: Value(v)))),
        _textField('Main sailmaker', _d.mainSailmaker.value,
            (v) => _update((d) => d.copyWith(mainSailmaker: Value(v)))),
        _textField('Main design', _d.mainDesign.value,
            (v) => _update((d) => d.copyWith(mainDesign: Value(v)))),
        _textField('Gennaker sailmaker', _d.gennakerSailmaker.value,
            (v) => _update((d) => d.copyWith(gennakerSailmaker: Value(v)))),
        _textField('Gennaker design', _d.gennakerDesign.value,
            (v) => _update((d) => d.copyWith(gennakerDesign: Value(v)))),
      ],
    );
  }

  Widget _textField(
      String label, String value, ValueChanged<String> onChanged) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 8),
      child: TextFormField(
        initialValue: value,
        decoration: InputDecoration(labelText: label, isDense: true),
        onChanged: onChanged,
      ),
    );
  }

  Widget _numberField(String label, int? value, ValueChanged<int?> onChanged) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 8),
      child: TextFormField(
        initialValue: value?.toString() ?? '',
        keyboardType: TextInputType.number,
        decoration: InputDecoration(labelText: label, isDense: true),
        onChanged: (v) => onChanged(int.tryParse(v)),
      ),
    );
  }

  Widget _dropdownCard<T>({
    required String label,
    required T? value,
    required List<T> items,
    required String Function(T) labelBuilder,
    required ValueChanged<T?> onChanged,
  }) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
      decoration: BoxDecoration(
        color: Theme.of(context).colorScheme.surfaceContainerHighest,
        borderRadius: BorderRadius.circular(12),
      ),
      child: DropdownButtonHideUnderline(
        child: DropdownButtonFormField<T>(
          decoration:
              InputDecoration(labelText: label, border: InputBorder.none),
          initialValue: value,
          items: items
              .map((e) =>
                  DropdownMenuItem(value: e, child: Text(labelBuilder(e))))
              .toList(),
          onChanged: onChanged,
        ),
      ),
    );
  }

  Widget _errorTagsCard() {
    final selected = _d.errorTags.value.isEmpty
        ? <String>{}
        : _d.errorTags.value.split(',').toSet();

    void toggle(ErrorTag tag, bool on) {
      final next = {...selected};
      if (on) {
        next.add(tag.name);
      } else {
        next.remove(tag.name);
      }
      // Store in a fixed order so the value is stable.
      final ordered = ErrorTag.values
          .where((t) => next.contains(t.name))
          .map((t) => t.name)
          .join(',');
      _update((d) => d.copyWith(errorTags: Value(ordered)));
    }

    return Container(
      width: double.infinity,
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
      decoration: BoxDecoration(
        color: Theme.of(context).colorScheme.surfaceContainerHighest,
        borderRadius: BorderRadius.circular(12),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text('Error source (tap any that apply)',
              style: Theme.of(context).textTheme.labelSmall),
          const SizedBox(height: 6),
          Wrap(
            spacing: 8,
            runSpacing: 4,
            children: [
              for (final tag in ErrorTag.values)
                FilterChip(
                  label: Text(tag.label),
                  selected: selected.contains(tag.name),
                  onSelected: (on) => toggle(tag, on),
                ),
            ],
          ),
        ],
      ),
    );
  }
}
