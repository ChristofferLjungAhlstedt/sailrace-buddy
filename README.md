# sailrace-buddy

Offline sailing trim logbook. Cross-platform via Flutter (iOS + Android now,
web later with the same codebase).

## ⚠️ Important: this was written without a Flutter environment

The sandbox this was built in has no Flutter/Dart SDK and no network
access, so **none of this code has been compiled or run**. The drift
schema syntax, widget APIs, and query builders are written carefully
against current package APIs, but you should expect a handful of small
fixes on first build (missing imports, minor API drift between package
versions, etc.) — normal for hand-written Flutter code, just flagging
that it hasn't had a compiler check yet.

## Getting started

```bash
flutter create --project-name sailrace_buddy --org com.yourdomain --overwrite .
# (this regenerates ios/, android/, platform boilerplate around the
#  lib/ and pubspec.yaml already provided here)

flutter pub get

# Generates lib/database/database.g.dart from the drift schema.
dart run build_runner build --delete-conflicting-outputs

flutter run
```

If you'd rather have Claude do this build/fix/run loop for you, this is
exactly what **Claude Code** is for — point it at this project folder
and it can install Flutter, run the build, and fix any compile errors
it hits, rather than iterating blind like I just did.

## Project structure

```
lib/
  database/
    database.dart          drift schema: Boat, Regatta, RaceEvent,
                            CustomFieldDefinition/Value, AppSettings
  repositories/
    race_repository.dart   prefill-chain logic (Case A: copy-forward,
                            no live links back to the parent regatta)
  widgets/
    stepper_field.dart      +/- stepper for trim values
    wind_speed_field.dart   quick entry + expandable min/max range
    linked_score.dart       race score / boat feel linking behavior
  screens/
    home_screen.dart
    boat_profile_screen.dart
    regatta_list_screen.dart
    regatta_detail_screen.dart
    race_entry_screen.dart  the fast quick-entry form
    practice_screen.dart
    search_screen.dart      best trim for a wind speed range
    archive_screen.dart
    settings_screen.dart    wind unit, custom fields, export/import
```

## What's implemented vs. stubbed

**Implemented:**
- Full schema matching everything we spec'd: boats, regattas, race events
  (shared by regatta races and practice), custom fields, the linked
  race-score/boat-feel behavior, the linked/unlinked wind speed range.
- The prefill chain: regatta race 1 seeds from the regatta, every race
  after seeds from the previous race, practice never prefills trim.
- Search by wind speed range, sorted by boat feel score, with the option
  to include/exclude error-flagged races.

**Stubbed / TODO — flagged in code with `// TODO`:**
- **Export/import**: the buttons exist in Settings but don't serialize
  yet. Straightforward next step — dump all tables to JSON via drift's
  generated data classes, write via `file_picker` or share via
  `share_plus`. Re-import should upsert by UUID so it's safe to
  re-import a backup without duplicating rows.
- **Wind unit setting isn't persisted** — `SettingsScreen` holds it in
  local widget state rather than the `AppSettings` table. Small fix:
  read/write it through `db.select(db.appSettings)` on load/change.
- **Custom field values aren't rendered in the race entry form yet** —
  the definitions can be created in Settings, but `RaceEntryScreen`
  doesn't yet pull them in and render steppers/dropdowns for them. The
  `CustomFieldValues` table is ready for this.
- **No cloud sync** — by design, this is phase two. The schema is
  already sync-shaped (UUID primary keys, `created_at`/`updated_at` on
  every row) specifically so this doesn't require a schema rewrite
  later.

## Suggested next steps

1. Get it compiling and running on a device/simulator — expect small
   fixes, nothing structural.
2. Wire up export/import — this is the most important thing to land
   before you trust this with real regatta data, since offline-only
   means no automatic backup.
3. Wire custom fields into the race entry form.
4. Real-world test the timing of the quick-entry form between races —
   if it's not fast enough, that's the thing to iterate on first.
