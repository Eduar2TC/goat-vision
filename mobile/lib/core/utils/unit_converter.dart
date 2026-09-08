import 'package:goatvision/core/storage/app_storage.dart';

/// Formats body-weight figures in the user's preferred unit (kg or lb).
/// All stored and computed values are kilograms; conversion only happens at
/// display time.
class UnitConverter {
  UnitConverter._();

  static const double lbsPerKg = 2.2046226218;

  static double toUnit(double kg, {String? unit}) {
    final u = unit ?? currentUnit;
    return u == 'lb' ? kg * lbsPerKg : kg;
  }

  /// e.g. "≈ 46.9 kg" or "≈ 103.4 lb".
  static String weight(double kg, {String? unit}) {
    return '${toUnit(kg, unit: unit).toStringAsFixed(1)} ${unit ?? currentUnit}';
  }

  /// e.g. "38.8–55.0 kg".
  static String range(double lowerKg, double upperKg, {String? unit}) {
    final u = unit ?? currentUnit;
    return '${toUnit(lowerKg, unit: u).toStringAsFixed(1)}–'
        '${toUnit(upperKg, unit: u).toStringAsFixed(1)} $u';
  }

  static String get currentUnit => AppStorage.preferredUnit;
}