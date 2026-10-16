import 'dart:io';
import 'package:drift/drift.dart';
import 'package:drift/native.dart';
import 'package:path/path.dart' as p;
import 'package:path_provider/path_provider.dart';

export 'package:drift/drift.dart' show Value, OrderingTerm, Insertable, Expression;

part 'database.g.dart';

// ---------------------------------------------------------------------------
// Enums stored as plain text in SQLite (drift doesn't need a native enum
// type - we validate in Dart and store the .name string).
// ---------------------------------------------------------------------------

enum EventType { regattaRace, practice }

enum WaveState { flat, slight, moderate, rough }

enum ErrorTag { falseStart, penalty, collision, missedLayline, other }

enum CustomFieldType { intType, floatType, textType, enumType }

enum WindUnit { knots, ms }

// ---------------------------------------------------------------------------
// Boat
// ---------------------------------------------------------------------------

class Boats extends Table {
  TextColumn get id => text()();
  TextColumn get name => text()();
  TextColumn get sailNumber => text().withDefault(const Constant(''))();
  TextColumn get boatClass => text().withDefault(const Constant('J70'))();

  // Device-measured reference shroud tension. Per-race values are stored
  // as an offset in turns from this baseline (see RaceEvents).
  RealColumn get innerShroudBaseline => real().nullable()();
  RealColumn get outerShroudBaseline => real().nullable()();

  DateTimeColumn get createdAt => dateTime()();
  DateTimeColumn get updatedAt => dateTime()();

  @override
  Set<Column> get primaryKey => {id};
}

// ---------------------------------------------------------------------------
// Regatta
// ---------------------------------------------------------------------------

class Regattas extends Table {
  TextColumn get id => text()();
  TextColumn get boatId => text().references(Boats, #id)();

  TextColumn get name => text()();
  TextColumn get venue => text().withDefault(const Constant(''))();
  DateTimeColumn get startDate => dateTime()();
  DateTimeColumn get endDate => dateTime().nullable()();

  IntColumn get rakeMm => integer().nullable()();

  TextColumn get jibSailmaker => text().withDefault(const Constant(''))();
  TextColumn get jibDesign => text().withDefault(const Constant(''))();
  TextColumn get jibSailId => text().withDefault(const Constant(''))();

  TextColumn get mainSailmaker => text().withDefault(const Constant(''))();
  TextColumn get mainDesign => text().withDefault(const Constant(''))();
  TextColumn get mainSailId => text().withDefault(const Constant(''))();

  TextColumn get gennakerSailmaker => text().withDefault(const Constant(''))();
  TextColumn get gennakerDesign => text().withDefault(const Constant(''))();
  TextColumn get gennakerSailId => text().withDefault(const Constant(''))();

  TextColumn get reviewNotes => text().nullable()();
  IntColumn get overallRating => integer().nullable()(); // 1-5

  DateTimeColumn get createdAt => dateTime()();
  DateTimeColumn get updatedAt => dateTime()();

  @override
  Set<Column> get primaryKey => {id};
}

// ---------------------------------------------------------------------------
// RaceEvent - covers both regatta races and standalone practice events.
// regattaId == null  ->  standalone practice, no prefill of any kind.
// regattaId != null  ->  race 1 seeds sail/rig fields from the Regatta;
//                         every later race seeds from the previous race.
//                         Trim/condition fields ALWAYS chain from the
//                         previous race in the same regatta, never from
//                         the regatta row itself.
// Every sail/rig/trim field is its own independent copy at creation time -
// editing the parent Regatta later never rewrites existing races.
// ---------------------------------------------------------------------------

class RaceEvents extends Table {
  TextColumn get id => text()();
  TextColumn get boatId => text().references(Boats, #id)();
  TextColumn get regattaId =>
      text().nullable().references(Regattas, #id)();

  TextColumn get type => textEnum<EventType>()();
  IntColumn get raceNumber => integer().nullable()();
  DateTimeColumn get date => dateTime()();

  // --- Sail / rig info: own copy, never live-linked to the regatta ---
  IntColumn get rakeMm => integer().nullable()();
  TextColumn get jibSailmaker => text().withDefault(const Constant(''))();
  TextColumn get jibDesign => text().withDefault(const Constant(''))();
  TextColumn get jibSailId => text().withDefault(const Constant(''))();
  TextColumn get mainSailmaker => text().withDefault(const Constant(''))();
  TextColumn get mainDesign => text().withDefault(const Constant(''))();
  TextColumn get mainSailId => text().withDefault(const Constant(''))();
  TextColumn get gennakerSailmaker => text().withDefault(const Constant(''))();
  TextColumn get gennakerDesign => text().withDefault(const Constant(''))();
  TextColumn get gennakerSailId => text().withDefault(const Constant(''))();

  // --- Trim variables ---
  // Jib car supports half-hole positions on drilled tracks (7, 7.5, 8...).
  RealColumn get jibCarPosition => real().nullable()();
  IntColumn get sheetMarker => integer().nullable()();
  IntColumn get inhaulerMarker => integer().nullable()();
  IntColumn get jibHalyardTension => integer().nullable()();

  // Shroud tension stored as offset in turns from the boat's baseline.
  RealColumn get innerShroudTurns => real().nullable()();
  RealColumn get outerShroudTurns => real().nullable()();

  // --- Conditions ---
  // Always stored in knots regardless of the user's display unit setting.
  RealColumn get windSpeedKt => real().nullable()();
  RealColumn get windSpeedMinKt => real().nullable()();
  RealColumn get windSpeedMaxKt => real().nullable()();
  BoolColumn get windSpeedLinked => boolean().withDefault(const Constant(true))();

  TextColumn get waveState => textEnum<WaveState>().nullable()();

  // --- Outcome ---
  IntColumn get raceScore => integer().nullable()(); // 1-5
  IntColumn get boatFeelScore => integer().nullable()(); // 1-5
  BoolColumn get scoreLinked => boolean().withDefault(const Constant(true))();

  // Comma-separated ErrorTag.name values. Kept simple since it's a small,
  // fixed set - a join table would be overkill here.
  TextColumn get errorTags => text().withDefault(const Constant(''))();

  TextColumn get notes => text().nullable()();
  // Newline-separated list of local file paths/URIs.
  TextColumn get photoRefs => text().withDefault(const Constant(''))();

  DateTimeColumn get createdAt => dateTime()();
  DateTimeColumn get updatedAt => dateTime()();

  @override
  Set<Column> get primaryKey => {id};
}

// ---------------------------------------------------------------------------
// User-defined custom fields (Settings -> Add custom field)
// ---------------------------------------------------------------------------

class CustomFieldDefinitions extends Table {
  TextColumn get id => text()();
  TextColumn get boatId => text().references(Boats, #id)();
  TextColumn get name => text()();
  TextColumn get fieldType => textEnum<CustomFieldType>()();
  // JSON-encoded list of strings, only used when fieldType == enumType.
  TextColumn get enumOptions => text().nullable()();
  TextColumn get unit => text().nullable()();
  BoolColumn get active => boolean().withDefault(const Constant(true))();
  IntColumn get sortOrder => integer().withDefault(const Constant(0))();

  @override
  Set<Column> get primaryKey => {id};
}

class CustomFieldValues extends Table {
  TextColumn get id => text()();
  TextColumn get raceEventId => text().references(RaceEvents, #id)();
  TextColumn get fieldDefinitionId =>
      text().references(CustomFieldDefinitions, #id)();
  // Stored as text, cast according to the field definition's fieldType
  // when read back out.
  TextColumn get value => text()();

  @override
  Set<Column> get primaryKey => {id};
}

// ---------------------------------------------------------------------------
// App-wide settings (single row)
// ---------------------------------------------------------------------------

class AppSettings extends Table {
  IntColumn get id => integer().withDefault(const Constant(0))();
  TextColumn get windUnit => textEnum<WindUnit>().withDefault(
      const Constant('knots'))();

  // Which boat was open last. Used to put it first in the boat picker.
  TextColumn get lastBoatId => text().nullable()();

  @override
  Set<Column> get primaryKey => {id};
}

// ---------------------------------------------------------------------------
// Database
// ---------------------------------------------------------------------------

@DriftDatabase(tables: [
  Boats,
  Regattas,
  RaceEvents,
  CustomFieldDefinitions,
  CustomFieldValues,
  AppSettings,
])
class AppDatabase extends _$AppDatabase {
  AppDatabase() : super(_openConnection());

    @override
  int get schemaVersion => 2;

  @override
  MigrationStrategy get migration => MigrationStrategy(
        onCreate: (m) => m.createAll(),
        onUpgrade: (m, from, to) async {
          if (from < 2) {
            await m.addColumn(appSettings, appSettings.lastBoatId);
          }
        },
      );

  Future<String?> getLastBoatId() async {
    final row = await (select(appSettings)..where((s) => s.id.equals(0)))
        .getSingleOrNull();
    return row?.lastBoatId;
  }

  Future<void> setLastBoatId(String boatId) {
    return into(appSettings).insertOnConflictUpdate(
      AppSettingsCompanion(id: const Value(0), lastBoatId: Value(boatId)),
    );
  }
  // -------------------------------------------------------------------
  // Convenience queries. Keep query logic here, not scattered through
  // the UI layer, so the "best trim for this wind speed" feature has a
  // single, testable source of truth.
  // -------------------------------------------------------------------

  /// Returns races/practice events whose wind range overlaps
  /// [minKt, maxKt], sorted by boat feel score (best first).
  ///
  /// Falls back to wind_speed_kt as both min and max when the detailed
  /// range wasn't filled in, so quick-entry and detailed-entry races are
  /// covered by the same query.
      Future<List<RaceEvent>> bestTrimsForWind({
    required double minKt,
    required double maxKt,
    bool includeFlagged = true,
  }) {
    final query = select(raceEvents)
      ..where((r) {
        // Races with a logged min/max range: match if it overlaps the search range.
        final hasRange = Expression.and([
          r.windSpeedMinKt.isNotNull(),
          r.windSpeedMaxKt.isNotNull(),
        ]);
        final rangeOverlaps = Expression.and([
          r.windSpeedMinKt.isSmallerOrEqualValue(maxKt),
          r.windSpeedMaxKt.isBiggerOrEqualValue(minKt),
        ]);

        // Quick-entry races with a single wind value: match if it falls in the range.
        final noRange = Expression.or([
          r.windSpeedMinKt.isNull(),
          r.windSpeedMaxKt.isNull(),
        ]);
        final singleInRange = Expression.and([
          r.windSpeedKt.isBiggerOrEqualValue(minKt),
          r.windSpeedKt.isSmallerOrEqualValue(maxKt),
        ]);

        return Expression.and([
          r.boatFeelScore.isNotNull(),
          Expression.or([
            Expression.and([hasRange, rangeOverlaps]),
            Expression.and([noRange, singleInRange]),
          ]),
        ]);
      })
      ..orderBy([(r) => OrderingTerm.desc(r.boatFeelScore)]);

    if (!includeFlagged) {
      query.where((r) => r.errorTags.equals(''));
    }
    return query.get();
  }

  /// All events for a boat, newest first - powers the Archive screen.
  Stream<List<RaceEvent>> watchArchive(String boatId) {
    return (select(raceEvents)
          ..where((r) => r.boatId.equals(boatId))
          ..orderBy([(r) => OrderingTerm.desc(r.date)]))
        .watch();
  }

  /// The most recent race in a regatta, used to build the prefill chain
  /// for the next race (Case A: copy values forward, no live link back
  /// to the Regatta row after race 1).
  Future<RaceEvent?> lastRaceInRegatta(String regattaId) {
    return (select(raceEvents)
          ..where((r) => r.regattaId.equals(regattaId))
          ..orderBy([(r) => OrderingTerm.desc(r.createdAt)])
          ..limit(1))
        .getSingleOrNull();
  }
}

LazyDatabase _openConnection() {
  return LazyDatabase(() async {
    final dbFolder = await getApplicationDocumentsDirectory();
    final file = File(p.join(dbFolder.path, 'sailrace_buddy.sqlite'));
    return NativeDatabase.createInBackground(file);
  });
}
