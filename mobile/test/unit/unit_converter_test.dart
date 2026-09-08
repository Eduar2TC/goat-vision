import 'package:flutter_test/flutter_test.dart';
import 'package:goatvision/core/storage/app_storage.dart';
import 'package:goatvision/core/utils/unit_converter.dart';

void main() {
  group('UnitConverter', () {
    test('keeps kg figures as-is when unit is kg', () {
      expect(UnitConverter.weight(46.9), startsWith('46.9 kg'));
      expect(UnitConverter.weight(46.9), '46.9 kg');
    });

    test('converts kg to lb when unit is lb', () {
      expect(UnitConverter.weight(46.9, unit: 'lb'), '103.4 lb');
      expect(UnitConverter.toUnit(46.9, unit: 'lb'), closeTo(103.4, 0.1));
    });

    test('range formats both bounds in the requested unit', () {
      expect(
        UnitConverter.range(38.0, 55.0),
        '38.0–55.0 kg',
      );
      expect(
        UnitConverter.range(38.0, 55.0, unit: 'lb'),
        '83.8–121.3 lb',
      );
    });

    test('uses the persisted preference by default', () {
      final previous = AppStorage.preferredUnit;
      AppStorage.preferredUnit = 'lb';
      try {
        expect(UnitConverter.weight(10), '22.0 lb');
      } finally {
        AppStorage.preferredUnit = previous;
      }
    });
  });
}