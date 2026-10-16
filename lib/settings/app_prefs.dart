import 'package:flutter/foundation.dart';
import '../database/database.dart';

class AppPrefs {
  static final ValueNotifier<WindUnit> windUnit = ValueNotifier(WindUnit.knots);

  static Future<void> load(AppDatabase db) async {
    windUnit.value = await db.getWindUnit();
  }

  static Future<void> setWindUnit(AppDatabase db, WindUnit unit) async {
    await db.setWindUnit(unit);
    windUnit.value = unit;
  }
}