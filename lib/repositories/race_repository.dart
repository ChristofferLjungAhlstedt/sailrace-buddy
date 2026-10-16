import 'package:uuid/uuid.dart';
import '../database/database.dart';

const _uuid = Uuid();

/// Centralizes the prefill rules so they can't drift out of sync between
/// screens:
///  - Regatta race #1  <- seeded from the Regatta (sails, rake, baselines).
///  - Regatta race #2+ <- seeded from the previous race in that regatta
///                        (sails/rig AND trim/conditions).
///  - Standalone practice <- blank, except the boat's shroud baselines.
class RaceRepository {
  RaceRepository(this.db);
  final AppDatabase db;

  Future<RaceEventsCompanion> buildDraftForNewRace({
    required String boatId,
    required String regattaId,
  }) async {
    final previous = await db.lastRaceInRegatta(regattaId);

    if (previous != null) {
      // Race 2+: chain everything from the immediately preceding race.
      return RaceEventsCompanion.insert(
        id: _uuid.v4(),
        boatId: boatId,
        regattaId: Value(regattaId),
        type: EventType.regattaRace,
        raceNumber: Value((previous.raceNumber ?? 1) + 1),
        date: DateTime.now(),
        rakeMm: Value(previous.rakeMm),
        innerShroudBaseline: Value(previous.innerShroudBaseline),
        outerShroudBaseline: Value(previous.outerShroudBaseline),
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
        innerShroudTurns: Value(previous.innerShroudTurns),
        outerShroudTurns: Value(previous.outerShroudTurns),
        windSpeedKt: Value(previous.windSpeedKt),
        waveState: Value(previous.waveState),
        createdAt: DateTime.now(),
        updatedAt: DateTime.now(),
      );
    }

    // Race 1: seed sail/rig fields from the Regatta. Trim and conditions
    // start blank - they aren't a Regatta-level concept.
    final regatta = await (db.select(db.regattas)
          ..where((r) => r.id.equals(regattaId)))
        .getSingle();

    return RaceEventsCompanion.insert(
      id: _uuid.v4(),
      boatId: boatId,
      regattaId: Value(regattaId),
      type: EventType.regattaRace,
      raceNumber: const Value(1),
      date: DateTime.now(),
      rakeMm: Value(regatta.rakeMm),
      innerShroudBaseline: Value(regatta.innerShroudBaseline),
      outerShroudBaseline: Value(regatta.outerShroudBaseline),
      jibSailmaker: Value(regatta.jibSailmaker),
      jibDesign: Value(regatta.jibDesign),
      jibSailId: Value(regatta.jibSailId),
      mainSailmaker: Value(regatta.mainSailmaker),
      mainDesign: Value(regatta.mainDesign),
      mainSailId: Value(regatta.mainSailId),
      gennakerSailmaker: Value(regatta.gennakerSailmaker),
      gennakerDesign: Value(regatta.gennakerDesign),
      gennakerSailId: Value(regatta.gennakerSailId),
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
      createdAt: DateTime.now(),
      updatedAt: DateTime.now(),
    );
  }

  Future<void> save(RaceEventsCompanion draft) async {
    await db.into(db.raceEvents).insertOnConflictUpdate(draft);
  }
}