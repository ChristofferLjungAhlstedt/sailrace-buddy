import 'dart:convert';
import 'dart:io';
import 'package:intl/intl.dart';
import 'package:path/path.dart' as p;
import 'package:path_provider/path_provider.dart';
import 'package:share_plus/share_plus.dart';
import '../database/database.dart';

class BackupService {
  BackupService(this.db);
  final AppDatabase db;

  /// Bump this if the file layout ever changes, so import can adapt.
  static const formatVersion = 1;

  /// Everything belonging to one boat, as a JSON-ready map.
  Future<Map<String, dynamic>> buildBoatBackup(String boatId) async {
    final boat = await (db.select(db.boats)
          ..where((b) => b.id.equals(boatId)))
        .getSingle();
    final regattas = await (db.select(db.regattas)
          ..where((r) => r.boatId.equals(boatId)))
        .get();
    final races = await (db.select(db.raceEvents)
          ..where((r) => r.boatId.equals(boatId)))
        .get();
    final definitions = await (db.select(db.customFieldDefinitions)
          ..where((d) => d.boatId.equals(boatId)))
        .get();

    final raceIds = races.map((r) => r.id).toList();
    final values = raceIds.isEmpty
        ? <CustomFieldValue>[]
        : await (db.select(db.customFieldValues)
              ..where((v) => v.raceEventId.isIn(raceIds)))
            .get();

    return {
      'app': 'sailrace-buddy',
      'formatVersion': formatVersion,
      'exportedAt': DateTime.now().toUtc().toIso8601String(),
      'boats': [boat.toJson()],
      'regattas': regattas.map((r) => r.toJson()).toList(),
      'raceEvents': races.map((r) => r.toJson()).toList(),
      'customFieldDefinitions': definitions.map((d) => d.toJson()).toList(),
      'customFieldValues': values.map((v) => v.toJson()).toList(),
    };
  }

  /// Writes the backup to a file and opens the system share sheet.
  Future<void> shareBoatBackup(Boat boat) async {
    final data = await buildBoatBackup(boat.id);

    final dir = await getTemporaryDirectory();
    final stamp = DateFormat('yyyy-MM-dd').format(DateTime.now());
    var safeName = boat.name
        .replaceAll(RegExp(r'[^A-Za-z0-9]+'), '-')
        .replaceAll(RegExp(r'^-+|-+$'), '');
    if (safeName.isEmpty) safeName = 'boat';

    final file =
        File(p.join(dir.path, 'sailrace-buddy_${safeName}_$stamp.json'));
    await file.writeAsString(jsonEncode(data));

    await Share.shareXFiles(
      [XFile(file.path, mimeType: 'application/json')],
      subject: 'Sailrace Buddy backup: ${boat.name}',
      text: 'Sailrace Buddy backup of ${boat.name}',
    );
  }
}