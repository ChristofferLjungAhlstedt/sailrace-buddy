import 'package:uuid/uuid.dart';
import '../database/database.dart';

const _uuid = Uuid();

/// Centralizes the prefill rules so they can't drift out of sync between
/// screens:
///  - Regatta race #1  <- seeded from the Regatta (sails, rake, baselines).
///  - Regatta race #2+ <- seeded from the previous race in that regatta
///                        (sails/rig AND trim/conditions). If the previous
///                        race has no shroud baseline, the regatta's is used.
///  - Standalone practice <- blank, except the boat's shroud baselines.
///
/// When a shroud baseline exists, shroud tension starts at 0 turns
/// ("Base") instead of blank.
class RaceRepository {
  RaceRepository(this.db);
  final AppDatabase db;

  Future<RaceEventsCompanion> buildDraftForNewRace({
    required String boatId,
    required String regattaId,
  }) async {
    final previous = await db.lastRaceInRegatta(regattaId);
    final regattaRow = await (db.select(db.regattas)
          ..where((r) => r.id.equals(regattaId)))
        .getSingle();

    if (previous != null) {
      // If the previous race never got a baseline, use the regatta's.
      final innerBase =
          previous.innerShroudBaseline ?? regattaRow.innerShroudBaseline;
      final outerBase =
          previous.outerShroudBaseline ?? regattaRow.outerShroudBaseline;

      // Race 2+: chain everything from the immediately preceding race.
      return RaceEventsCompanion.insert(
        id: _uuid.v4(),
        boatId: boatId,
        regattaId: Value(regattaId),
        type: EventType.regattaRace,
        raceNumber: Value((previous.raceNumber ?? 1) + 1),
        date: DateTime.now(),
        rakeMm: Value(previous.rakeMm),
        innerShroudBaseline: Value(innerBase),
        outerShroudBaseline: Value(outerBase),
        jibSailmaker: Value(previous.jibSailmaker),
        jibDesign: Value(previous.jibDesign),
        jibSailId: Value(previous.jibSailId),
        mainSailmaker: Value(previous.mainSailmaker),
        mainDesign: Value(previous.mainDesign),
        mainSailId: Value(previous.mainSailId),
        gennakerSailmaker: Value(previous.gennakerSailmaker),
        gennakerDesign: Value(previous.gennakerDesign),
        gennakerSailId: Value(previous.gennakerSailId),
        jibCarPosition: Value(previous.jibCarPosition),
        sheetMarker: Value(previous.sheetMarker),
        inhaulerMarker: Value(previous.inhaulerMarker),
        jibHalyardTension: Value(previous.jibHalyardTension),
        innerShroudTurns: Value(
            previous.innerShroudTurns ?? (innerBase != null ? 0.0 : null)),
        outerShroudTurns: Value(
            previous.outerShroudTurns ?? (outerBase != null ? 0.0 : null)),
        windSpeedKt: Value(previous.windSpeedKt),
        waveState: Value(previous.waveState),
        createdAt: DateTime.now(),
        updatedAt: DateTime.now(),
      );
    }

    // Race 1: seed sail/rig fields from the Regatta. Trim and conditions
    // start blank (shrouds start at Base if there is a baseline).
    return RaceEventsCompanion.insert(
      id: _uuid.v4(),
      boatId: boatId,
      regattaId: Value(regattaId),
      type: EventType.regattaRace,
      raceNumber: const Value(1),
      date: DateTime.now(),
      rakeMm: Value(regattaRow.rakeMm),
      innerShroudBaseline: Value(regattaRow.innerShroudBaseline),
      outerShroudBaseline: Value(regattaRow.outerShroudBaseline),
      innerShroudTurns:
          Value(regattaRow.innerShroudBaseline != null ? 0.0 : null),
      outerShroudTurns:
          Value(regattaRow.outerShroudBaseline != null ? 0.0 : null),
      jibSailmaker: Value(regattaRow.jibSailmaker),
      jibDesign: Value(regattaRow.jibDesign),
      jibSailId: Value(regattaRow.jibSailId),
      mainSailmaker: Value(regattaRow.mainSailmaker),
      mainDesign: Value(regattaRow.mainDesign),
      mainSailId: Value(regattaRow.mainSailId),
      gennakerSailmaker: Value(regattaRow.gennakerSailmaker),
      gennakerDesign: Value(regattaRow.gennakerDesign),
      gennakerSailId: Value(regattaRow.gennakerSailId),
      createdAt: DateTime.now(),
      updatedAt: DateTime.now(),
    );
  }

  /// Practice starts blank, except the boat's own shroud baselines.
  Future<RaceEventsCompanion> buildDraftForPractice({
    required String boatId,
  }) async {
    final boat = await (db.select(db.boats)
          ..where((b) => b.id.equals(boatId)))
        .getSingleOrNull();

    return RaceEventsCompanion.insert(
      id: _uuid.v4(),
      boatId: boatId,
      type: EventType.practice,
      date: DateTime.now(),
      innerShroudBaseline: Value(boat?.innerShroudBaseline),
      outerShroudBaseline: Value(boat?.outerShroudBaseline),
      innerShroudTurns:
          Value(boat?.innerShroudBaseline != null ? 0.0 : null),
      outerShroudTurns:
          Value(boat?.outerShroudBaseline != null ? 0.0 : null),
      createdAt: DateTime.now(),
      updatedAt: DateTime.now(),
    );
  }

  Future<void> save(RaceEventsCompanion draft) async {
    await db.into(db.raceEvents).insertOnConflictUpdate(draft);
  }
}