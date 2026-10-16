import 'dart:convert';
import 'dart:io';
import 'dart:typed_data';
import 'package:file_picker/file_picker.dart';
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

  /// Builds a JSON-ready backup. Pass [boatIds] to limit it to some boats,
  /// or leave it null for every boat on the device.
  Future<Map<String, dynamic>> buildBackup({Set<String>? boatIds}) async {
    var boats = await db.select(db.boats).get();
    if (boatIds != null) {
      boats = boats.where((b) => boatIds.contains(b.id)).toList();
    }
    final ids = boats.map((b) => b.id).toSet();

    final regattas = (await db.select(db.regattas).get())
        .where((r) => ids.contains(r.boatId))
        .toList();
    final races = (await db.select(db.raceEvents).get())
        .where((r) => ids.contains(r.boatId))
        .toList();
    final definitions = (await db.select(db.customFieldDefinitions).get())
        .where((d) => ids.contains(d.boatId))
        .toList();

    final raceIds = races.map((r) => r.id).toSet();
    final values = (await db.select(db.customFieldValues).get())
        .where((v) => raceIds.contains(v.raceEventId))
        .toList();

    return {
      'app': 'sailrace-buddy',
      'formatVersion': formatVersion,
      'exportedAt': DateTime.now().toUtc().toIso8601String(),
      'boats': boats.map((b) => b.toJson()).toList(),
      'regattas': regattas.map((r) => r.toJson()).toList(),
      'raceEvents': races.map((r) => r.toJson()).toList(),
      'customFieldDefinitions': definitions.map((d) => d.toJson()).toList(),
      'customFieldValues': values.map((v) => v.toJson()).toList(),
    };
  }

  // --- Public entry points -------------------------------------------

  /// Opens the share sheet (Drive, email, chat apps...).
  Future<void> shareBoatBackup(Boat boat) =>
      _share(boatIds: {boat.id}, label: boat.name);

  Future<void> shareAllBackup() => _share(boatIds: null, label: 'all boats');

  /// Opens the system "Save as" dialog. Returns the saved path, or null
  /// if the user cancelled.
  Future<String?> saveBoatBackup(Boat boat) =>
      _save(boatIds: {boat.id}, label: boat.name);

  Future<String?> saveAllBackup() => _save(boatIds: null, label: 'all boats');

  // --- Internals -----------------------------------------------------

  String _fileName(String label) {
    final stamp = DateFormat('yyyy-MM-dd').format(DateTime.now());
    var safe = label
        .replaceAll(RegExp(r'[^A-Za-z0-9]+'), '-')
        .replaceAll(RegExp(r'^-+|-+$'), '');
    if (safe.isEmpty) safe = 'backup';
    return 'sailrace-buddy_${safe}_$stamp.json';
  }

  Future<void> _share({
    required Set<String>? boatIds,
    required String label,
  }) async {
    final data = await buildBackup(boatIds: boatIds);
    final dir = await getTemporaryDirectory();
    final file = File(p.join(dir.path, _fileName(label)));
    await file.writeAsString(jsonEncode(data));

    final subject = 'Sailrace Buddy backup: $label';
    await SharePlus.instance.share(
      ShareParams(
        files: [XFile(file.path, mimeType: 'application/json')],
        subject: subject,
        text: subject,
      ),
    );
  }

  Future<String?> _save({
    required Set<String>? boatIds,
    required String label,
  }) async {
    final data = await buildBackup(boatIds: boatIds);
    final bytes = Uint8List.fromList(utf8.encode(jsonEncode(data)));
    final saved = await FilePicker.saveFile(
      dialogTitle: 'Save backup',
      fileName: _fileName(label),
      bytes: bytes,
    );
    // v13 returns a Uri (null if the user cancelled). Callers only care
    // whether it was saved, so hand back a string or null.
    return saved?.toString();
  }
}
