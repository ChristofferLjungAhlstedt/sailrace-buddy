import 'dart:convert';
import 'dart:io';
import 'package:file_picker/file_picker.dart';
import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import '../database/database.dart';
import '../services/import_service.dart';

/// Returns the summary of what was imported, or null if the user backed
/// out, the file was unusable, or there was nothing new in it.
Future<ImportSummary?> runImportFlow(
  BuildContext context,
  AppDatabase db,
) async {
  final service = ImportService(db);

  // Any file type: backups sent through chat apps can lose their
  // .json extension, and we check the content ourselves anyway.
  final picked = await FilePicker.pickFiles();
  if (picked.isEmpty) return null; // user cancelled
  final file = picked.first;

  List<int>? bytes;
  try {
    bytes = await file.readAsBytes();
  } catch (_) {
    bytes = null;
  }
  if (!context.mounted) return null;
  if (bytes == null) {
    await _info(context, 'Could not read the file', 'Try picking it again.');
    return null;
  }

  final ParsedBackup parsed;
  try {
    final text = utf8.decode(bytes).replaceFirst('\uFEFF', '');
    parsed = service.parse(text);
  } on BackupFormatException catch (e) {
    await _info(context, "Can't import this file", e.message);
    return null;
  } on FormatException {
    await _info(context, "Can't import this file",
        'This is not a Sailrace Buddy backup file.');
    return null;
  }

  final preview = await service.preview(parsed);
  if (!context.mounted) return null;

  if (!preview.changesAnything) {
    await _info(
      context,
      'Nothing to import',
      'Everything in this backup is already in the app, and your copies are '
          'the same or newer.',
    );
    return null;
  }

  final confirmed = await showDialog<bool>(
    context: context,
    builder: (context) => AlertDialog(
      title: const Text('Import backup?'),
      content: SingleChildScrollView(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            if (parsed.exportedAt != null)
              Padding(
                padding: const EdgeInsets.only(bottom: 8),
                child: Text(
                  'Backup made ${DateFormat.yMMMd().format(parsed.exportedAt!.toLocal())}',
                  style: Theme.of(context).textTheme.bodySmall,
                ),
              ),
            for (final b in preview.boatInfos)
              Padding(
                padding: const EdgeInsets.only(bottom: 4),
                child: Text(
                  '• ${b.label}  ${b.isNew ? '(new boat)' : '(already here, will be merged)'}',
                  style: const TextStyle(fontWeight: FontWeight.w500),
                ),
              ),
            const SizedBox(height: 12),
            for (final line in _summaryLines(preview))
              Padding(
                padding: const EdgeInsets.only(bottom: 4),
                child: Text(line),
              ),
            const SizedBox(height: 12),
            Text(
              'Nothing is deleted. If a regatta or race exists in both '
              'places, the most recently edited version is kept.',
              style: Theme.of(context).textTheme.bodySmall,
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
          onPressed: () => Navigator.pop(context, true),
          child: const Text('Import'),
        ),
      ],
    ),
  );
  if (confirmed != true) return null;

  try {
    return await service.apply(parsed);
  } catch (e) {
    if (context.mounted) {
      await _info(context, 'Import failed', 'Nothing was changed.\n($e)');
    }
    return null;
  }
}

List<String> _summaryLines(ImportSummary s) {
  final lines = <String?>[
    _tallyText('Regattas', s.regattas),
    _tallyText('Races and practice', s.races),
    if (s.customFieldsAdded > 0) 'Custom fields: ${s.customFieldsAdded} new',
  ];
  return lines.whereType<String>().toList();
}

String? _tallyText(String label, Tally t) {
  final parts = <String>[
    if (t.added > 0) '${t.added} new',
    if (t.updated > 0) '${t.updated} updated',
    if (t.unchanged > 0) '${t.unchanged} already up to date',
    if (t.skipped > 0) '${t.skipped} skipped (incomplete data)',
  ];
  return parts.isEmpty ? null : '$label: ${parts.join(', ')}';
}

Future<void> _info(BuildContext context, String title, String message) {
  return showDialog<void>(
    context: context,
    builder: (context) => AlertDialog(
      title: Text(title),
      content: Text(message),
      actions: [
        TextButton(
          onPressed: () => Navigator.pop(context),
          child: const Text('OK'),
        ),
      ],
    ),
  );
}
