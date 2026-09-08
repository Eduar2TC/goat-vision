import 'package:flutter/foundation.dart';

class RangeValidator {
  RangeValidator._();

  static const _ranges = <String, (double, double)>{
    'body_length': (30.0, 120.0),
    'withers_height': (30.0, 90.0),
    'rump_height': (30.0, 90.0),
    'chest_depth': (15.0, 60.0),
    'chest_width': (10.0, 45.0),
    'rump_width': (8.0, 40.0),
    'rump_length': (15.0, 60.0),
    'paw_height': (8.0, 35.0),
  };

  static bool isValid(String feature, double value) {
    final range = _ranges[feature];
    if (range == null) return value.isFinite && value > 0;
    return value >= range.$1 && value <= range.$2;
  }

  static String? validateFeature(String feature, double value) {
    final range = _ranges[feature];
    if (value <= 0) {
      return '$feature debe ser positivo (era $value).';
    }
    if (range != null && (value < range.$1 || value > range.$2)) {
      return '$feature fuera de rango físico plausible '
          '(${range.$1}–${range.$2} cm, era $value cm).';
    }
    return null;
  }

  static Map<String, String> validateAll(Map<String, double> features) {
    final errors = <String, String>{};
    for (final entry in features.entries) {
      final error = validateFeature(entry.key, entry.value);
      if (error != null) errors[entry.key] = error;
    }
    return errors;
  }
}