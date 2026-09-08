import 'package:flutter_test/flutter_test.dart';
import 'package:goatvision/data/repositories/drift_measurement_repository.dart';
import 'package:goatvision/features/history/domain/history_filter.dart';

MeasurementRecord _rec({
  required String id,
  required String animalId,
  required double weightKg,
}) {
  return MeasurementRecord(
    id: id,
    animalId: animalId,
    timestamp: DateTime(2026, 1, 1),
    estimatedWeightKg: weightKg,
    lowerWeightKg: weightKg - 5,
    upperWeightKg: weightKg + 5,
    confidence: 0.7,
    modelVersion: 'test',
    datasetVersion: 'test',
  );
}

void main() {
  final records = [
    _rec(id: 'm1', animalId: 'a1', weightKg: 45.0),
    _rec(id: 'm2', animalId: 'a1', weightKg: 52.6),
    _rec(id: 'm3', animalId: 'a2', weightKg: 30.0),
  ];
  const names = {'a1': 'Luna', 'a2': 'Chispa'};

  group('filterHistoryRecords', () {
    test('empty query returns all records unchanged', () {
      expect(filterHistoryRecords(
        records: records,
        animalNamesById: names,
        query: '   ',
      ), records);
    });

    test('matches goat name case-insensitively, trimmed', () {
      final result = filterHistoryRecords(
        records: records,
        animalNamesById: names,
        query: '  luna ',
      );
      expect(result.map((r) => r.id), ['m1', 'm2']);
    });

    test('matches by estimated weight (1 decimal)', () {
      final byWhole = filterHistoryRecords(
        records: records,
        animalNamesById: names,
        query: '45',
      );
      expect(byWhole.map((r) => r.id), ['m1']);

      final byDecimal = filterHistoryRecords(
        records: records,
        animalNamesById: names,
        query: '52.6',
      );
      expect(byDecimal.map((r) => r.id), ['m2']);
    });

    test('returns empty list when nothing matches', () {
      expect(filterHistoryRecords(
        records: records,
        animalNamesById: names,
        query: 'inexistente',
      ), isEmpty);
    });

    test('missing animal name falls back to unknown', () {
      final result = filterHistoryRecords(
        records: records,
        animalNamesById: const {},
        query: 'luna',
      );
      expect(result, isEmpty);
    });
  });
}