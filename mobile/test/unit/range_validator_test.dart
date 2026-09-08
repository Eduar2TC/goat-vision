import 'package:flutter_test/flutter_test.dart';
import 'package:goatvision/core/utils/range_validator.dart';

void main() {
  group('RangeValidator', () {
    test('accepts valid values', () {
      expect(RangeValidator.isValid('body_length', 75), isTrue);
      expect(RangeValidator.isValid('withers_height', 65), isTrue);
      expect(RangeValidator.isValid('chest_depth', 35), isTrue);
    });

    test('rejects zero and negative', () {
      expect(RangeValidator.isValid('body_length', 0), isFalse);
      expect(RangeValidator.isValid('body_length', -5), isFalse);
    });

    test('rejects absurdly small values', () {
      final error = RangeValidator.validateFeature('body_length', 2);
      expect(error, isNotNull);
    });

    test('rejects absurdly large values', () {
      final error = RangeValidator.validateFeature('body_length', 500);
      expect(error, isNotNull);
    });

    test('validateAll returns errors map', () {
      final errors = RangeValidator.validateAll({
        'body_length': 75,
        'withers_height': 2,
      });
      expect(errors, contains('withers_height'));
      expect(errors, isNot(contains('body_length')));
    });
  });
}