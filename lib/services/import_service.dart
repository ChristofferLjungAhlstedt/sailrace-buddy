import 'dart:convert';
import 'dart:math';
import '../database/database.dart';
import 'backup_service.dart';

class BackupFormatException implements Exception {
  BackupFormatException(this.message);
  final String message;
  @override
  String toString() => message;
}

class ParsedBackup {
  ParsedBackup({
    required this.exportedAt,
    required this.boats,
    required this.regattas,
    required this.races,
    required this.definitions,
    required this.values,
  });
  final DateTime? exportedAt;
  final List<Boat> boats;
  final List<Regatta> regattas;
  final List<RaceEvent> races;
  final List<CustomFieldDefinition> definitions;
  final List<CustomFieldValue> values;
}

class Tally {
  int added = 0, updated = 0, unchanged = 0, skipped = 0;
  int get changed => added + updated;
}

class BoatImportInfo {
  BoatImportInfo(this.boat, {required this.isNew});
  final Boat boat;
  final bool isNew;

  String get label => [
        boat.name,
        boat.boatClass,
        if (boat.sailNumber.isNotEmpty) boat.sailNumber,
      ].join(' · ');
}

class ImportSummary {
  final boatInfos = <BoatImportInfo>[];
  final boatIds = <String>[];
  final boats = Tally();
  final regattas = Tally();
  final races = Tally();
  int customFieldsAdded = 0;
  int customValuesImported = 0;

  bool get changesAnything =>
      boats.changed + regattas.changed + races.changed + customFieldsAdded > 0;

  String _plural(int n, String word) => '$n $word${n == 1 ? '' : 's'}';

  /// e.g. "1 boat, 3 regattas, 14 races"
  String get oneLine {
    final parts = <String>[
      if (boats.changed > 0) _plural(boats.changed, 'boat'),
      if (regattas.changed > 0) _plural(regattas.changed, 'regatta'),
      if (races.changed > 0) _plural(races.changed, 'race'),
      if (customFieldsAdded > 0)
        _plural(customFieldsAdded, 'custom field'),
    ];
    return parts.isEmpty ? 'nothing new' : parts.join(', ');
  }
}

class ImportService {
  ImportService(this.db);
  final AppDatabase db;

  /// Reads and validates a backup. Throws [BackupFormatException] with a
  /// message that is safe to show to the user.
  ParsedBackup parse(String text) {
    final Object? decoded;
    try {
      decoded = jsonDecode(text);
    } on FormatException {
      throw BackupFormatException(
          'This file is not readable. Is it a Sailrace Buddy backup?');
    }

    if (decoded is! Map || decoded['app'] != 'sailrace-buddy') {
      throw BackupFormatException('This is not a Sailrace Buddy backup file.');
    }
    final root = Map<String, dynamic>.from(decoded);

    final version = root['formatVersion'];
    if (version is! int) {
      throw BackupFormatException(
          'This backup has no format version, so it cannot be read safely.');
    }
    if (version > BackupService.formatVersion) {
      throw BackupFormatException(
          'This backup was made by a newer version of the app. '
          'Update the app and try again.');
    }

    try {
      List<T> read<T>(String key, T Function(Map<String, dynamic>) fromJson) {
        final raw = root[key];
        if (raw == null) return <T>[];
        return [
          for (final item in raw as List)
            fromJson(Map<String, dynamic>.from(item as Map)),
        ];
      }

      return ParsedBackup(
        exportedAt: DateTime.tryParse(root['exportedAt']?.toString() ?? ''),
        boats: read('boats', (j) => Boat.fromJson(j)),
        regattas: read('regattas', (j) => Regatta.fromJson(j)),
        races: read('raceEvents', (j) => RaceEvent.fromJson(j)),
        definitions: read('customFieldDefinitions',
            (j) => CustomFieldDefinition.fromJson(j)),
        values: read('customFieldValues', (j) => CustomFieldValue.fromJson(j)),
      );
    } catch (e) {
      throw BackupFormatException(
          'The backup file is damaged or incomplete.\n($e)');
    }
  }

  /// What an import would do, without changing anything.
  Future<ImportSummary> preview(ParsedBackup p) => _merge(p, commit: false);

  /// Performs the import in a single transaction.
  Future<ImportSummary> apply(ParsedBackup p) => _merge(p, commit: true);

  Future<ImportSummary> _merge(ParsedBackup p, {required bool commit}) async {
    final s = ImportSummary();

    final localBoats = {
      for (final b in await db.select(db.boats).get()) b.id: b
    };
    final localRegattas = {
      for (final r in await db.select(db.regattas).get()) r.id: r
    };
    final localRaces = {
      for (final r in await db.select(db.raceEvents).get()) r.id: r
    };
    final localDefs = await db.select(db.customFieldDefinitions).get();
    final localDefIds = localDefs.map((d) => d.id).toSet();

    // --- Boats ---
    final boatsToWrite = <Boat>[];
    final knownBoatIds = {...localBoats.keys};
    for (final b in p.boats) {
      final local = localBoats[b.id];
      knownBoatIds.add(b.id);
      s.boatIds.add(b.id);
      s.boatInfos.add(BoatImportInfo(b, isNew: local == null));
      if (local == null) {
        s.boats.added++;
        boatsToWrite.add(b);
      } else if (b.updatedAt.isAfter(local.updatedAt)) {
        s.boats.updated++;
        boatsToWrite.add(b);
      } else {
        s.boats.unchanged++;
      }
    }

    // --- Regattas ---
    final regattasToWrite = <Regatta>[];
    final knownRegattaIds = {...localRegattas.keys};
    for (final r in p.regattas) {
      if (!knownBoatIds.contains(r.boatId)) {
        s.regattas.skipped++;
        continue;
      }
      knownRegattaIds.add(r.id);
      final local = localRegattas[r.id];
      if (local == null) {
        s.regattas.added++;
        regattasToWrite.add(r);
      } else if (r.updatedAt.isAfter(local.updatedAt)) {
        s.regattas.updated++;
        regattasToWrite.add(r);
      } else {
        s.regattas.unchanged++;
      }
    }

    // --- Custom field definitions ---
    // Existing ids are kept as they are. A local field with the same
    // name and type on the same boat counts as the same field.
    final defIdMap = <String, String>{}; // id in file -> id to use here
    final defsToWrite = <CustomFieldDefinition>[];
    for (final d in p.definitions) {
      if (!knownBoatIds.contains(d.boatId)) continue;
      if (localDefIds.contains(d.id)) {
        defIdMap[d.id] = d.id;
        continue;
      }
      final twin = localDefs
          .where((l) =>
              l.boatId == d.boatId &&
              l.fieldType == d.fieldType &&
              l.name.toLowerCase() == d.name.toLowerCase())
          .firstOrNull;
      if (twin != null) {
        defIdMap[d.id] = twin.id;
        continue;
      }
      defIdMap[d.id] = d.id;
      defsToWrite.add(d);
      s.customFieldsAdded++;
    }

    // --- Races and practice events ---
    final racesToWrite = <RaceEvent>[];
    final importedRaceIds = <String>{};
    for (final r in p.races) {
      final boatOk = knownBoatIds.contains(r.boatId);
      final regattaOk =
          r.regattaId == null || knownRegattaIds.contains(r.regattaId);
      if (!boatOk || !regattaOk) {
        s.races.skipped++;
        continue;
      }
      final local = localRaces[r.id];
      if (local == null) {
        s.races.added++;
      } else if (r.updatedAt.isAfter(local.updatedAt)) {
        s.races.updated++;
      } else {
        s.races.unchanged++;
        continue;
      }
      racesToWrite.add(r);
      importedRaceIds.add(r.id);
    }

    // --- Custom field values (only for races we are importing) ---
    final valuesToWrite = <CustomFieldValue>[];
    for (final v in p.values) {
      if (!importedRaceIds.contains(v.raceEventId)) continue;
      final defId = defIdMap[v.fieldDefinitionId] ??
          (localDefIds.contains(v.fieldDefinitionId)
              ? v.fieldDefinitionId
              : null);
      if (defId == null) continue;
      valuesToWrite.add(
          defId == v.fieldDefinitionId ? v : v.copyWith(fieldDefinitionId: defId));
    }
    s.customValuesImported = valuesToWrite.length;

    if (commit) {
      await db.transaction(() async {
        for (final b in boatsToWrite) {
          await db.into(db.boats).insertOnConflictUpdate(b);
        }
        for (final r in regattasToWrite) {
          await db.into(db.regattas).insertOnConflictUpdate(r);
        }
        for (final d in defsToWrite) {
          await db.into(db.customFieldDefinitions).insertOnConflictUpdate(d);
        }
        for (final r in racesToWrite) {
          await db.into(db.raceEvents).insertOnConflictUpdate(r);
        }

        // Replace the values of every imported race with the backup's.
        final ids = importedRaceIds.toList();
        for (var i = 0; i < ids.length; i += 500) {
          final chunk = ids.sublist(i, min(i + 500, ids.length));
          await (db.delete(db.customFieldValues)
                ..where((v) => v.raceEventId.isIn(chunk)))
              .go();
        }
        for (final v in valuesToWrite) {
          await db.into(db.customFieldValues).insertOnConflictUpdate(v);
        }
      });
    }

    return s;
  }
}