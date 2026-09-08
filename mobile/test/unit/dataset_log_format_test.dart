import 'dart:convert';

import 'package:flutter_test/flutter_test.dart';
import 'package:goatvision/core/storage/dataset_log_format.dart';

void main() {
  final features = <String, double>{
    'body_length_cm': 60.5,
    'withers_height_cm': 58.2,
    'rump_height_cm': 60.1,
    'chest_depth_cm': 34.4,
    'chest_width_cm': 19.0,
    'rump_width_cm': 17.2,
    'rump_length_cm': 18.4,
    'paw_height_cm': 12.6,
  };

  group('buildDatasetRow', () {
    test('keeps the 8 ML feature columns in FEATURE_COLUMNS order', () {
      final row = buildDatasetRow(
        measurementId: 'm1',
        animalId: 'a1',
        timestamp: DateTime(2026, 9, 8, 10, 30),
        realWeightKg: 46.2,
        features: features,
      );

      expect(kDatasetFeatureColumns, [
        'body_length_cm',
        'withers_height_cm',
        'rump_height_cm',
        'chest_depth_cm',
        'chest_width_cm',
        'rump_width_cm',
        'rump_length_cm',
        'paw_height_cm',
      ]);

      for (final c in kDatasetFeatureColumns) {
        expect(row[c], features[c], reason: 'missing $c');
      }
      expect(row['real_weight_kg'], 46.2);
      expect(row['measurement_id'], 'm1');
      expect(row['animal_id'], 'a1');
    });

    test('defaults to NaN target when no real weight given', () {
      final row = buildDatasetRow(
        measurementId: 'm1',
        animalId: 'a1',
        timestamp: DateTime(2026, 1, 1),
        features: features,
      );
      expect((row['real_weight_kg'] as double).isNaN, isTrue);
    });
  });

  group('encodeJsonl', () {
    test('produces a parseable JSON line with feature values', () {
      final row = buildDatasetRow(
        measurementId: 'm1',
        animalId: 'a1',
        timestamp: DateTime(2026, 9, 8, 10, 30),
        realWeightKg: 46.2,
        features: features,
      );
      final line = encodeJsonl(row);

      expect(line, startsWith('{'));
      expect(line, endsWith('}'));
      expect(line, contains('"animal_id":"a1"'));
      expect(line, contains('"body_length_cm":60.5'));
      expect(line, contains('"real_weight_kg":46.2'));

      final decoded = const JsonDecoder().convert(line) as Map<String, dynamic>;
      expect(decoded['animal_id'], 'a1');
      expect(decoded['body_length_cm'], 60.5);
      expect(decoded['real_weight_kg'], 46.2);
    });

    test('escapes quotes in animal ids', () {
      final row = buildDatasetRow(
        measurementId: 'm1',
        animalId: 'a"1\\x',
        timestamp: DateTime(2026, 1, 1),
        realWeightKg: 30,
        features: features,
      );
      final line = encodeJsonl(row);
      expect(line, contains(r'"animal_id":"a\"1\\x"'));
    });
  });

  group('rowsToCsv', () {
    test('header lists features then metadata; target is real_weight_kg', () {
      final csv = rowsToCsv([
        buildDatasetRow(
          measurementId: 'm1',
          animalId: 'a1',
          timestamp: DateTime(2026, 1, 1),
          realWeightKg: 46.2,
          features: features,
        ),
      ]);

      final lines = csv.trim().split('\n');
      final header = lines.first.split(',');
      expect(header, [...kDatasetFeatureColumns, ...kDatasetMetaColumns]);
      expect(header.last, 'real_weight_kg');
    });

    test('escapes commas and quotes in strings', () {
      final rows = [
        buildDatasetRow(
          measurementId: 'm1',
          animalId: 'a,1',
          timestamp: DateTime(2026, 1, 1),
          realWeightKg: 46.2,
          features: features,
        ),
      ];
      final csv = rowsToCsv(rows);
      expect(csv, contains('"a,1"'));
    });

    test('handles empty list with only header', () {
      final csv = rowsToCsv([]);
      expect(
        csv.trim(),
        [...kDatasetFeatureColumns, ...kDatasetMetaColumns].join(','),
      );
    });
  });
}