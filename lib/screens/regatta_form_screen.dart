import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import 'package:uuid/uuid.dart';
import '../database/database.dart';
import 'regatta_detail_screen.dart';

/// Used both for creating a new regatta (existing == null) and for
/// editing one. Creating only writes to the database when you press
/// Done, so backing out leaves no empty "New regatta" rows behind.
class RegattaFormScreen extends StatefulWidget {
  const RegattaFormScreen({
    super.key,
    required this.db,
    required this.boatId,
    this.existing,
  });

  final AppDatabase db;
  final String boatId;
  final Regatta? existing;

  @override
  State<RegattaFormScreen> createState() => _RegattaFormScreenState();
}

class _RegattaFormScreenState extends State<RegattaFormScreen> {
  late final TextEditingController _name;
  late final TextEditingController _venue;
  late final TextEditingController _rake;
  late final TextEditingController _jibMaker, _jibDesign, _jibId;
  late final TextEditingController _mainMaker, _mainDesign, _mainId;
  late final TextEditingController _gennMaker, _gennDesign, _gennId;
  late final TextEditingController _innerBase, _outerBase;
  late DateTime _start;
  DateTime? _end;

  String _plain(double v) =>
      v == v.roundToDouble() ? v.toStringAsFixed(0) : v.toString();

  double? _parseD(String text) =>
      double.tryParse(text.trim().replaceAll(',', '.'));

  @override
  void initState() {
    super.initState();
    final r = widget.existing;
    _name = TextEditingController(text: r?.name ?? '');
    _venue = TextEditingController(text: r?.venue ?? '');
    _rake = TextEditingController(text: r?.rakeMm?.toString() ?? '');
    _jibMaker = TextEditingController(text: r?.jibSailmaker ?? '');
    _jibDesign = TextEditingController(text: r?.jibDesign ?? '');
    _jibId = TextEditingController(text: r?.jibSailId ?? '');
    _mainMaker = TextEditingController(text: r?.mainSailmaker ?? '');
    _mainDesign = TextEditingController(text: r?.mainDesign ?? '');
    _mainId = TextEditingController(text: r?.mainSailId ?? '');
    _gennMaker = TextEditingController(text: r?.gennakerSailmaker ?? '');
    _gennDesign = TextEditingController(text: r?.gennakerDesign ?? '');
    _gennId = TextEditingController(text: r?.gennakerSailId ?? '');
    _innerBase = TextEditingController(
        text: r?.innerShroudBaseline == null
            ? ''
            : _plain(r!.innerShroudBaseline!));
    _outerBase = TextEditingController(
        text: r?.outerShroudBaseline == null
            ? ''
            : _plain(r!.outerShroudBaseline!));
    _start = r?.startDate ?? DateTime.now();
    _end = r?.endDate;
    if (r == null) _prefillBaselinesFromBoat();
  }

  @override
  void dispose() {
    for (final c in [
      _name,
      _venue,
      _rake,
      _jibMaker,
      _jibDesign,
      _jibId,
      _mainMaker,
      _mainDesign,
      _mainId,
      _gennMaker,
      _gennDesign,
      _gennId,
      _innerBase,
      _outerBase,
    ]) {
      c.dispose();
    }
    super.dispose();
  }

  Future<void> _pickDate({required bool isStart}) async {
    final initial = isStart ? _start : (_end ?? _start);
    final picked = await showDatePicker(
      context: context,
      initialDate: initial,
      firstDate: DateTime(2000),
      lastDate: DateTime(2100),
    );
    if (picked == null) return;
    setState(() {
      if (isStart) {
        _start = picked;
        if (_end != null && _end!.isBefore(_start)) _end = _start;
      } else {
        _end = picked;
      }
    });
  }

  /// A new regatta starts from the boat's own baselines (editable here).
  Future<void> _prefillBaselinesFromBoat() async {
    final boat = await (widget.db.select(widget.db.boats)
          ..where((b) => b.id.equals(widget.boatId)))
        .getSingleOrNull();
    if (boat == null || !mounted) return;
    if (_innerBase.text.isEmpty && boat.innerShroudBaseline != null) {
      _innerBase.text = _plain(boat.innerShroudBaseline!);
    }
    if (_outerBase.text.isEmpty && boat.outerShroudBaseline != null) {
      _outerBase.text = _plain(boat.outerShroudBaseline!);
    }
  }

  Future<void> _save() async {
    final name = _name.text.trim();
    if (name.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Give the regatta a name')));
      return;
    }
    final rake = int.tryParse(_rake.text.trim());
    final now = DateTime.now();
    final existing = widget.existing;
    final innerBase = _parseD(_innerBase.text);
    final outerBase = _parseD(_outerBase.text);

    if (existing == null) {
      final id = const Uuid().v4();
      await widget.db.into(widget.db.regattas).insert(
            RegattasCompanion.insert(
              id: id,
              boatId: widget.boatId,
              name: name,
              startDate: _start,
              endDate: Value(_end),
              venue: Value(_venue.text.trim()),
              rakeMm: Value(rake),
              innerShroudBaseline: Value(innerBase),
              outerShroudBaseline: Value(outerBase),
              jibSailmaker: Value(_jibMaker.text.trim()),
              jibDesign: Value(_jibDesign.text.trim()),
              jibSailId: Value(_jibId.text.trim()),
              mainSailmaker: Value(_mainMaker.text.trim()),
              mainDesign: Value(_mainDesign.text.trim()),
              mainSailId: Value(_mainId.text.trim()),
              gennakerSailmaker: Value(_gennMaker.text.trim()),
              gennakerDesign: Value(_gennDesign.text.trim()),
              gennakerSailId: Value(_gennId.text.trim()),
              createdAt: now,
              updatedAt: now,
            ),
          );
      if (!mounted) return;
      // Replace the form with the regatta screen, so Back goes to the list.
      Navigator.of(context).pushReplacement(MaterialPageRoute(
        builder: (_) => RegattaDetailScreen(db: widget.db, regattaId: id),
      ));
    } else {
      await widget.db.update(widget.db.regattas).replace(existing.copyWith(
            name: name,
            startDate: _start,
            endDate: Value(_end),
            venue: _venue.text.trim(),
            rakeMm: Value(rake),
            innerShroudBaseline: Value(innerBase),
            outerShroudBaseline: Value(outerBase),
            jibSailmaker: _jibMaker.text.trim(),
            jibDesign: _jibDesign.text.trim(),
            jibSailId: _jibId.text.trim(),
            mainSailmaker: _mainMaker.text.trim(),
            mainDesign: _mainDesign.text.trim(),
            mainSailId: _mainId.text.trim(),
            gennakerSailmaker: _gennMaker.text.trim(),
            gennakerDesign: _gennDesign.text.trim(),
            gennakerSailId: _gennId.text.trim(),
            updatedAt: now,
          ));
      if (!mounted) return;
      Navigator.of(context).pop(true);
    }
  }

  Widget _field(TextEditingController c, String label,
      {TextInputType? keyboard}) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 12),
      child: TextField(
        controller: c,
        keyboardType: keyboard,
        textCapitalization: TextCapitalization.sentences,
        decoration: InputDecoration(labelText: label, isDense: true),
      ),
    );
  }

  Widget _sailGroup(String title, TextEditingController maker,
      TextEditingController design, TextEditingController id) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Padding(
          padding: const EdgeInsets.only(top: 8, bottom: 8),
          child: Text(title, style: Theme.of(context).textTheme.titleSmall),
        ),
        _field(maker, 'Sailmaker'),
        Row(
          children: [
            Expanded(child: _field(design, 'Design (e.g. J6)')),
            const SizedBox(width: 12),
            Expanded(child: _field(id, 'Sail ID')),
          ],
        ),
      ],
    );
  }

  @override
  Widget build(BuildContext context) {
    final fmt = DateFormat.yMMMd();
    final editing = widget.existing != null;

    return Scaffold(
      appBar: AppBar(
        title: Text(editing ? 'Edit regatta' : 'New regatta'),
        actions: [TextButton(onPressed: _save, child: const Text('Done'))],
      ),
      body: ListView(
        padding: const EdgeInsets.all(16),
        children: [
          _field(_name, 'Regatta name'),
          _field(_venue, 'Venue'),
          Row(
            children: [
              Expanded(
                child: OutlinedButton.icon(
                  icon: const Icon(Icons.event),
                  label: Text('Start  ${fmt.format(_start)}'),
                  onPressed: () => _pickDate(isStart: true),
                ),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: OutlinedButton.icon(
                  icon: const Icon(Icons.event_available),
                  label: Text(
                      _end == null ? 'End date' : 'End  ${fmt.format(_end!)}'),
                  onPressed: () => _pickDate(isStart: false),
                ),
              ),
            ],
          ),
          const SizedBox(height: 24),
          Text('Boat setup', style: Theme.of(context).textTheme.titleMedium),
          const SizedBox(height: 4),
          Text(
            'Copied into every race you add. Changing it later only affects '
            'new races, existing ones keep their own values.',
            style: Theme.of(context).textTheme.bodySmall,
          ),
          const SizedBox(height: 12),
          _field(_rake, 'Rake (mm)', keyboard: TextInputType.number),
          Text(
            'Shroud baselines (device readings) for this rig. Can differ '
            'with sailmaker or mast setup.',
            style: Theme.of(context).textTheme.bodySmall,
          ),
          const SizedBox(height: 8),
          Row(
            children: [
              Expanded(
                child: _field(_innerBase, 'Inner baseline',
                    keyboard:
                        const TextInputType.numberWithOptions(decimal: true)),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: _field(_outerBase, 'Outer baseline',
                    keyboard:
                        const TextInputType.numberWithOptions(decimal: true)),
              ),
            ],
          ),
          _sailGroup('Jib', _jibMaker, _jibDesign, _jibId),
          _sailGroup('Main', _mainMaker, _mainDesign, _mainId),
          _sailGroup('Gennaker', _gennMaker, _gennDesign, _gennId),
          const SizedBox(height: 24),
        ],
      ),
    );
  }
}
