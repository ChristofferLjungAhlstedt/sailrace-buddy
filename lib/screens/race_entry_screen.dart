import 'package:flutter/material.dart';
import '../database/database.dart';
import '../repositories/race_repository.dart';
import '../widgets/stepper_field.dart';
import '../widgets/wind_speed_field.dart';
import '../widgets/linked_score.dart';

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
  }

  void _update(RaceEventsCompanion Function(RaceEventsCompanion) f) {
    setState(() => _d = f(_d));
  }

  Future<void> _save() async {
    final repo = RaceRepository(widget.db);
    await repo.save(_d.copyWith(updatedAt: Value(DateTime.now())));
    if (mounted) Navigator.of(context).pop();
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
                          ? 'Rake ${_d.rakeMm.value ?? '--'}mm  ·  edit sails and rake'
                          : 'Add sail and rake info',
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
                  onChanged: (v) => _update(
                      (d) => d.copyWith(sheetMarker: Value(v.round()))),
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
                  value: _d.innerShroudTurns.value,
                  step: 0.5,
                  decimals: 1,
                  suffix: 't',
                  onChanged: (v) => _update(
                      (d) => d.copyWith(innerShroudTurns: Value(v))),
                ),
                StepperField(
                  label: 'Outer shroud',
                  value: _d.outerShroudTurns.value,
                  step: 0.5,
                  decimals: 1,
                  suffix: 't',
                  onChanged: (v) => _update(
                      (d) => d.copyWith(outerShroudTurns: Value(v))),
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

          // --- Wind speed ---
          WindSpeedField(
            windSpeedKt: _d.windSpeedKt.value,
            minKt: _d.windSpeedMinKt.value,
            maxKt: _d.windSpeedMaxKt.value,
            linked: _d.windSpeedLinked.value,
            useMs: widget.useMs,
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
          Row(
            children: [
              Expanded(
                child: _dropdownCard<WaveState>(
                  label: 'Waves',
                  value: _d.waveState.value,
                  items: WaveState.values,
                  labelBuilder: (w) => w.name,
                  onChanged: (v) =>
                      _update((d) => d.copyWith(waveState: Value(v))),
                ),
              ),
              const SizedBox(width: 8),
              Expanded(child: _errorTagsCard()),
            ],
          ),
          const SizedBox(height: 8),

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
          TextField(
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
    final current = _d.errorTags.value.isEmpty
        ? <String>{}
        : _d.errorTags.value.split(',').toSet();

    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
      decoration: BoxDecoration(
        color: Theme.of(context).colorScheme.surfaceContainerHighest,
        borderRadius: BorderRadius.circular(12),
      ),
      child: DropdownButtonHideUnderline(
        child: DropdownButtonFormField<String>(
          decoration: const InputDecoration(
              labelText: 'Error source', border: InputBorder.none),
          initialValue: current.isEmpty ? null : current.first,
          hint: const Text('None'),
          items: ErrorTag.values
              .map((e) => DropdownMenuItem(value: e.name, child: Text(e.name)))
              .toList(),
          onChanged: (v) =>
              _update((d) => d.copyWith(errorTags: Value(v ?? ''))),
        ),
      ),
    );
  }
}
