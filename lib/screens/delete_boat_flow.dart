import 'package:flutter/material.dart';
import '../database/database.dart';
import '../services/backup_service.dart';

enum _Choice { exportFirst, withoutBackup }

/// Runs the whole delete-boat conversation. Returns true if the boat
/// was deleted, false if the user backed out (or the export failed).
Future<bool> confirmAndDeleteBoat(
  BuildContext context,
  AppDatabase db,
  Boat boat,
) async {
  final counts = await db.countBoatData(boat.id);
  if (!context.mounted) return false;

  // --- Step 1: what will be lost, and the backup choice ---
  final choice = await showDialog<_Choice>(
    context: context,
    builder: (context) => AlertDialog(
      title: Text('Delete "${boat.name}"?'),
      content: Text(
        'This permanently deletes the boat, its ${counts.regattas} '
        'regatta${counts.regattas == 1 ? '' : 's'} and ${counts.races} '
        'race/practice event${counts.races == 1 ? '' : 's'}. '
        'It cannot be undone.\n\n'
        'Export a backup first so you can restore it later.',
      ),
      actions: [
        TextButton(
          onPressed: () => Navigator.pop(context),
          child: const Text('Cancel'),
        ),
        TextButton(
          onPressed: () => Navigator.pop(context, _Choice.withoutBackup),
          child: const Text('Delete without backup'),
        ),
        FilledButton(
          onPressed: () => Navigator.pop(context, _Choice.exportFirst),
          child: const Text('Export backup first'),
        ),
      ],
    ),
  );
  if (choice == null || !context.mounted) return false;

  // --- Step 2 (optional): export ---
  if (choice == _Choice.exportFirst) {
    try {
      await BackupService(db).shareBoatBackup(boat);
    } catch (e) {
      if (context.mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Export failed, nothing was deleted: $e')),
        );
      }
      return false;
    }
    if (!context.mounted) return false;
  }

  // --- Step 3: final confirmation ---
  final backedUp = choice == _Choice.exportFirst;
  final confirmed = await showDialog<bool>(
    context: context,
    builder: (context) => AlertDialog(
      title: Text(backedUp ? 'Delete "${boat.name}" now?' : 'Last chance'),
      content: Text(backedUp
          ? 'Only continue if the backup file was saved or sent somewhere '
              'safe. Once the boat is deleted it cannot be recovered '
              'without that file.'
          : 'You chose not to back up. "${boat.name}" and all its data '
              'will be gone for good.'),
      actions: [
        TextButton(
          onPressed: () => Navigator.pop(context, false),
          child: const Text('Cancel'),
        ),
        FilledButton(
          style: FilledButton.styleFrom(
            backgroundColor: Theme.of(context).colorScheme.error,
            foregroundColor: Theme.of(context).colorScheme.onError,
          ),
          onPressed: () => Navigator.pop(context, true),
          child: const Text('Delete boat'),
        ),
      ],
    ),
  );
  if (confirmed != true) return false;

  await db.deleteBoat(boat.id);
  return true;
}