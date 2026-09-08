import 'package:goatvision/data/repositories/drift_measurement_repository.dart';

/// Filtra mediciones por nombre de cabra o peso estimado.
///
/// Pura y sin dependencias de Flutter para poder testearse en la VM.
/// [animalNamesById] asocia id de cabra -> nombre.
List<MeasurementRecord> filterHistoryRecords({
  required List<MeasurementRecord> records,
  required Map<String, String> animalNamesById,
  required String query,
}) {
  final q = query.trim().toLowerCase();
  if (q.isEmpty) return records;

  return records.where((r) {
    final name = (animalNamesById[r.animalId] ?? '').toLowerCase();
    final weight = r.estimatedWeightKg.toStringAsFixed(1).toLowerCase();
    return name.contains(q) || weight.contains(q);
  }).toList();
}