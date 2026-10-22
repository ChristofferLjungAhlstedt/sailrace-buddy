# Sailrace Buddy

An offline trim logbook for one-design sailors. Log your rig and sail trim between races in a few taps, rate how the boat felt, and later search your own history for what worked best in a given wind.

Built with Flutter, with Android as the main target. All data lives on the phone in a local SQLite database, so it works on the water with no signal.

> Status: early development, being tested by a small group of sailors. Expect changes.

## Why

Trim notes usually end up scattered across notebooks, phone notes and memory. Sailrace Buddy keeps them in one structured, searchable place, built around one idea: logging must be fast enough to do between two races.

- **Fast entry.** Steppers and one-tap ratings, with everything prefilled from the previous race.
- **Analysable data.** Everything that matters is a number or a fixed choice, never free text. Free text exists only for notes.
- **Nothing gets lost.** Full export and import, so a lost phone does not mean a lost logbook.

## Features

### Boats
- Multiple boat profiles. If you have more than one, you pick a boat each time the app starts, and a **Switch boat** button is always on the home screen.
- Choose a class from a list (J70, RS Feva, Melges 24, RS 21) or type your own.
- Boat name, optional sail number, mast prebend, and default shroud baselines.
- Deleting a boat offers to export a backup first.

### Regattas
- Create a regatta with name, venue and dates.
- Fill in the rig once: rake, shroud baselines, and for jib, main and gennaker the sailmaker, design and sail ID.
- That setup is copied into every race you add. Editing the regatta afterwards only affects **new** races, so history is never rewritten. A mid-regatta sail swap is just an edit on the next race.
- After the regatta: a written review and an overall 1-5 rating.

### Races and practice
One form for both, so all your data is comparable.

| Group | Fields |
|---|---|
| Rig (per race copy) | Rake, shroud baselines, sailmaker, design and sail ID for each sail |
| Trim | Jib car (supports half holes, e.g. 8.5), sheet marker, in-hauler marker, jib halyard, inner and outer shroud |
| Conditions | Wind speed, wave state (flat, slight, moderate, rough) |
| Outcome | Race score (1-5), boat feel score (1-5), error sources, notes |
| Custom | Any extra fields you define |

Details worth knowing:

- **Prefill chain.** Race 1 starts from the regatta setup. Every later race starts from the previous race. Practice events start blank, except the boat's shroud baselines.
- **Shrouds** are logged as turns from a baseline (the device reading for that rig). At zero the stepper reads **Base**.
- **Wind speed** is a single value with +/- buttons for speed. Expand it to give a min and max when you have time. Steppers snap to round numbers (1 kt or 0.5 m/s). Wind is always stored in knots and shown in your chosen unit.
- **Two scores.** Race score is the result, boat feel is how the boat performed. Setting the race score also sets boat feel, until you edit boat feel separately, after which they stay independent.
- **Error sources** (false start, penalty, collision, missed layline, other) can be combined. They explain a result that does not match how the boat felt, and can be excluded in search.

### Custom fields
Add your own data points per boat (Settings, then Custom fields).

- Types: whole number, decimal number, choice list, or free text.
- Optional unit, e.g. mm.
- Fields appear in the race form with the other trim fields. Numbers and choices carry over from the previous race like built-in trim.
- Hide a field without losing its history. The type of an existing field is locked, since changing it would make old values meaningless.
- Included in backups and searchable (except free text).

### Search
Find the trim that worked, e.g. "what did I run at 10-14 knots?"

- Filter by wind range, or switch the range off to list everything.
- Filter by custom fields: number ranges and choice lists, combined with AND.
- Optionally leave out races with error flags.
- Sort by boat feel, race score, wind speed, or any numeric custom field, in either direction. Races missing the sort value always go last.
- Tap a result to open the full race.

### Archive
Every regatta race and practice event for the boat, newest first, tagged by type.

### Backup and restore
- **Export** one boat or all boats to a single JSON file. Save it to the phone or share it through Drive, email or chat.
- **Import** a backup on any device. Before anything is written you see a preview of what is new, updated or already present.
- Import is a merge: nothing is deleted, rows are matched by UUID, and if both sides have a race, the most recently edited version wins. Importing the same file twice changes nothing.
- The import is all-or-nothing: if anything fails, your data is untouched.
- Backups include boats, regattas, races, custom fields and their values. The wind unit is a per-device setting and is not included.

### Settings
Wind unit (kt or m/s), custom fields, export all and import. Switching units never changes stored data.

## Getting started

Requirements: Flutter (stable), and an Android device or emulator.

```bash
git clone <your-repo-url> sailrace-buddy
cd sailrace-buddy

flutter pub get

# Generate lib/database/database.g.dart from the drift schema
dart run build_runner build --delete-conflicting-outputs

flutter run
```

If the `android/` and `ios/` folders are missing, create them without overwriting your code:

```bash
flutter create --project-name sailrace_buddy --org com.yourname --platforms=android,ios .
```

Do not use `--overwrite`, it replaces `lib/main.dart` and `pubspec.yaml`.

### Changing the database

1. Edit the tables in `lib/database/database.dart`.
2. Bump `schemaVersion` and add a step to the `onUpgrade` migration.
3. Run `dart run build_runner build --delete-conflicting-outputs`.
4. Fully restart the app (hot reload is not enough, the migration runs when the database opens).

### App icon

The logo source and generated PNGs live in `assets/logo/`. After changing them:

```bash
dart run flutter_launcher_icons
```

## Building an APK for testers

```bash
flutter build apk --release
```

The file is `build/app/outputs/flutter-apk/app-release.apk`. Bump the number after the `+` in the `version` line of `pubspec.yaml` for each build you send out.

Testers need to allow "install unknown apps" for the app they open the file from, and may need to tap through a Play Protect warning.

Notes for testers:

- Install updates **over** the old version. Uninstalling deletes the local logbook.
- Use Boat profile, then Export backup, before anything risky.
- Release builds use the debug signing key by default. Updates only install over an existing app if they are signed with the same key, so keep building on the same machine, or set up your own signing key.

## Project structure

```
lib/
  main.dart
  data/
    boat_classes.dart          class list, edit here to add a class
  database/
    database.dart              drift schema, migrations and queries
  models/                      small display helpers (wind units, tags, custom fields)
  repositories/
    race_repository.dart       the prefill rules for new races and practice events
  services/
    backup_service.dart        builds and saves/shares backup files
    import_service.dart        validates and merges backups
  settings/
    app_prefs.dart             device preferences (wind unit)
  screens/                     one file per screen, plus export/import/delete flows
  widgets/                     steppers, wind field, linked score, class logo, class picker
assets/
  logo/                        app icon source files
```

### Adding a boat class

Add one line to `lib/data/boat_classes.dart`:

```dart
BoatClass('Laser'),
```

To show a class logo in the dropdown and on the Boat profile tile, add a PNG to `assets/class_logos/`, list that folder under `assets:` in `pubspec.yaml`, and set `logoAsset:` on the class. Classes without a logo (including free-text ones) fall back to a sailboat icon.

### Data model

`Boat`, `Regatta`, `RaceEvent` (regatta races and practice events share one table), `CustomFieldDefinition`, `CustomFieldValue` and `AppSettings`. Every row has a UUID created on the device, and most have created and updated timestamps. That makes merging backups safe now and keeps the door open for syncing between devices later.

### Main dependencies

drift and sqlite3_flutter_libs (local database), path_provider, path, uuid, intl, file_picker, share_plus. Dev: drift_dev, build_runner, flutter_launcher_icons.

## Known limitations

- No photos yet.
- Deleting is permanent and there is no deleted-marker, so importing an old backup brings deleted races back.
- Search filters are not remembered between visits.
- Race numbers are not renumbered after a delete.
- Mast prebend is stored on the boat only, not per regatta or race.
- Every class gets the same trim fields, which are shaped around the J70.
- Search results show a shroud at baseline as `0.0` rather than **Base**.
- iOS shares the same code but has not been built or tested.

## Roadmap

These are ideas and priorities, not promises.

**Next**
- CSV export of all races for analysis in Sheets or Excel.
- Reference photos per race, with backups growing into a zip that includes them.
- Backup reminder if you have not exported in a while.
- Saved searches.

**Later**
- Per-class trim field sets, so an RS Feva does not see J70 controls.
- Mast prebend per regatta and race, handled like the shroud baselines.
- Simple analysis views, such as average boat feel per wind range or per jib car position.
- Class logos, and your own app signing key.
- Deleted-markers, a prerequisite for safe syncing.

**Longer term**
- Teams: several sailors sharing one boat's log through an invite code, with a managed backend such as Firebase or Supabase.
- iOS builds, a web version, and a Play Store release.
