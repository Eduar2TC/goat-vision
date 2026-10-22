
class RangeValidator {
  RangeValidator._();

  // Rangos basados en el estudio Paredes-Chocce et al. (2025) para campos
  // que se usan en el predictor de referencia, y rangos físicos generales
  // para el resto.
  // Las claves coinciden con MorphometricFeatures.toMap() y con
  // FEATURE_COLUMNS de ml/preprocessing/features.py (sufijo _cm).
  static const _ranges = <String, (double, double)>{
    'body_length_cm': (30.0, 120.0),
    'withers_height_cm': (30.0, 90.0),
    'rump_height_cm': (51.0, 89.2),  // Rango del estudio
    'chest_depth_cm': (22.0, 45.0),  // Rango del estudio
    'chest_width_cm': (12.0, 27.0),  // Rango del estudio
    'rump_width_cm': (8.7, 27.0),    // Rango del estudio
    'rump_length_cm': (15.0, 60.0),
    'paw_height_cm': (8.0, 35.0),
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
