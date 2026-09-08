/// Formato del dataset de recolección (modo desarrollador).
///
/// Cada medición con peso real de báscula se guarda como línea JSON y puede
/// exportarse a CSV para entrenar el modelo propio. Las columnas de features
/// coinciden 1:1 con `FEATURE_COLUMNS` y `TARGET` de `ml/preprocessing/features.py`.
library;

/// Orden de columnas biométricas (coincide con ml/preprocessing/features.py).
const List<String> kDatasetFeatureColumns = [
  'body_length_cm',
  'withers_height_cm',
  'rump_height_cm',
  'chest_depth_cm',
  'chest_width_cm',
  'rump_width_cm',
  'rump_length_cm',
  'paw_height_cm',
];

/// Columnas de metadatos de cada registro.
const List<String> kDatasetMetaColumns = [
  'measurement_id',
  'animal_id',
  'timestamp_iso',
  'real_weight_kg',
];

const String kDatasetTargetColumn = 'real_weight_kg';

/// Construye la fila de dataset a partir de una medición.
///
/// [features] debe usar llaves snake_case de `kDatasetFeatureColumns`.
/// [realWeightKg] es el peso medido en báscula (objetivo de entrenamiento).
Map<String, Object> buildDatasetRow({
  required String measurementId,
  required String animalId,
  required DateTime timestamp,
  double? realWeightKg,
  required Map<String, double> features,
}) {
  final row = <String, Object>{
    'measurement_id': measurementId,
    'animal_id': animalId,
    'timestamp_iso': timestamp.toIso8601String(),
  };
  for (final column in kDatasetFeatureColumns) {
    row[column] = features[column] ?? 0.0;
  }
  row[kDatasetTargetColumn] = realWeightKg ?? double.nan;
  return row;
}

/// A diferencia de `double.toDouble()`, JSON no admite NaN/Infinity: se
/// emiten como strings para no romper el archivo JSONL.
String _jsonNumber(double value) {
  if (value.isNaN) return 'null';
  return value.toString();
}

/// Serializa una fila a una línea JSONL (una por medición).
String encodeJsonl(Map<String, Object> row) {
  final parts = <String>[
    '"measurement_id":${_jsonString(row['measurement_id'] as String)}',
    '"animal_id":${_jsonString(row['animal_id'] as String)}',
    '"timestamp_iso":${_jsonString(row['timestamp_iso'] as String)}',
  ];
  for (final column in kDatasetFeatureColumns) {
    final value = row[column] as double;
    parts.add('"$column":${_jsonNumber(value)}');
  }
  final target = row[kDatasetTargetColumn] as double;
  parts.add('"$kDatasetTargetColumn":${_jsonNumber(target)}');
  return '{${parts.join(',')}}';
}

String _jsonString(String value) {
  const escaped = {
    '"': r'\"',
    '\\': r'\\',
    '\n': r'\n',
    '\r': r'\r',
    '\t': r'\t',
  };
  final buffer = StringBuffer('"');
  for (final char in value.split('')) {
    buffer.write(escaped[char] ?? char);
  }
  buffer.write('"');
  return buffer.toString();
}

String _csvCell(Object value) {
  var text = value is double && value.isNaN
      ? ''
      : value.toString();
  if (text.contains(',') ||
      text.contains('"') ||
      text.contains('\n') ||
      text.contains('\r')) {
    text = text.replaceAll('"', '""');
    return '"$text"';
  }
  return text;
}

/// Convierte las filas en CSV con cabecera: features + metadatos.
String rowsToCsv(List<Map<String, Object>> rows) {
  final columns = [...kDatasetFeatureColumns, ...kDatasetMetaColumns];
  final buffer = StringBuffer()
    ..writeln(columns.map(_csvCell).join(','));
  for (final row in rows) {
    buffer.writeln(columns.map((c) => _csvCell(row[c] ?? '')).join(','));
  }
  return buffer.toString();
}