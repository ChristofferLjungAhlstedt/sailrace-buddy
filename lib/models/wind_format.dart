import '../database/database.dart';
import '../settings/app_prefs.dart';

double ktToMs(double kt) => kt * 0.514444;
double msToKt(double ms) => ms / 0.514444;

String windUnitLabel([WindUnit? unit]) =>
    (unit ?? AppPrefs.windUnit.value) == WindUnit.ms ? 'm/s' : 'kt';

/// Wind in the user's chosen unit: whole knots, or m/s with one decimal.
String formatWind(double? kt, {WindUnit? unit}) {
  if (kt == null) return '--';
  final u = unit ?? AppPrefs.windUnit.value;
  if (u == WindUnit.ms) return '${ktToMs(kt).toStringAsFixed(1)} m/s';
  return '${kt.toStringAsFixed(0)} kt';
}

/// e.g. "10-14 kt" or "5.1-7.2 m/s"
String formatWindRange(double minKt, double maxKt, {WindUnit? unit}) {
  final u = unit ?? AppPrefs.windUnit.value;
  final ms = u == WindUnit.ms;
  double conv(double kt) => ms ? ktToMs(kt) : kt;
  final digits = ms ? 1 : 0;
  return '${conv(minKt).toStringAsFixed(digits)}-'
      '${conv(maxKt).toStringAsFixed(digits)} ${windUnitLabel(u)}';
}