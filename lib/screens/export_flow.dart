import 'package:flutter/material.dart';
import '../database/database.dart';
import '../services/backup_service.dart';

enum _ExportChoice { saveToDevice, share }

/// Asks how to export, then does it. Pass [boat] for a single-boat
/// backup, or leave it null to back up every boat.
///
/// Returns true if a backup was saved or handed to the share sheet,
/// false if the user backed out or something failed.
Future<bool> runExportFlow(
  BuildContext context,
  AppDatabase db, {
  Boat? boat,
}) async {
  final choice = await showModalBottomSheet<_ExportChoice>(
    context: context,
    showDragHandle: true,
    builder: (context) => SafeArea(
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          Padding(
            padding: const EdgeInsets.fromLTRB(24, 0, 24, 8),
            child: Align(
              alignment: Alignment.centerLeft,
              child: Text(
                boat == null
                    ? 'Export all boats'
                    : 'Export "${boat.name}"',
                style: Theme.of(context).textTheme.titleMedium,
              ),
            ),
          ),
          ListTile(
            leading: const Icon(Icons.save_alt),
            title: const Text('Save to this device'),
            subtitle: const Text('Choose a folder, for example Downloads'),
            onTap: () => Navigator.pop(context, _ExportChoice.saveToDevice),
          ),
          ListTile(
            leading: const Icon(Icons.ios_share),
            title: const Text('Share'),
            subtitle: const Text('Drive, email, chat apps...'),
            onTap: () => Navigator.pop(context, _ExportChoice.share),
          ),
          const SizedBox(height: 8),
        ],
      ),
    ),
  );
  if (choice == null || !context.mounted) return false;

  final service = BackupService(db);
  try {
    if (choice == _ExportChoice.saveToDevice) {
      final path = boat == null
          ? await service.saveAllBackup()
          : await service.saveBoatBackup(boat);
      if (!context.mounted) return false;
      if (path == null) return false; // cancelled in the save dialog
      ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Backup saved to your device')));
      return true;
    }

    if (boat == null) {
      await service.shareAllBackup();
    } else {
      await service.shareBoatBackup(boat);
    }
    return true;
  } catch (e) {
    if (context.mounted) {
      ScaffoldMessenger.of(context)
          .showSnackBar(SnackBar(content: Text('Export failed: $e')));
    }
    return false;
  }
}