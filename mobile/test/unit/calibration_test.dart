import 'package:flutter_test/flutter_test.dart';
import 'package:goatvision/core/calibration/calibration_providers.dart';
import 'package:goatvision/domain/entities/calibration.dart';

void main() {
  group('MarkerCalibrationProvider', () {
    final provider = MarkerCalibrationProvider();

    test('computes cmPerPixel correctly', () async {
      final calibration = await provider.calibrate(
        markerWidthPixels: 600,
        markerHeightPixels: 600,
        realWidthCm: 30,
      );

      expect(calibration.cmPerPixel, closeTo(0.05, 0.001));
      expect(calibration.realWidthCm, 30);
    });

    test('pixelsToCm converts correctly', () async {
      final calibration = await provider.calibrate(
        markerWidthPixels: 600,
        markerHeightPixels: 600,
        realWidthCm: 30,
      );

      expect(calibration.pixelsToCm(100), closeTo(5.0, 0.1));
      expect(calibration.cmToPixels(5), closeTo(100, 1));
    });

    test('rejects zero marker width', () async {
      expect(
        () => provider.calibrate(
          markerWidthPixels: 0,
          markerHeightPixels: 600,
          realWidthCm: 30,
        ),
        throwsException,
      );
    });

    test('validates ideal marker', () async {
      final calibration = await provider.calibrate(
        markerWidthPixels: 600,
        markerHeightPixels: 600,
        realWidthCm: 30,
      );
      expect(provider.validate(calibration), isTrue);
    });

    test('calibration confidence decreases with perspective distortion',
        () async {
      final calibration = await provider.calibrate(
        markerWidthPixels: 600,
        markerHeightPixels: 480,
        realWidthCm: 30,
      );
      expect(calibration.confidence, lessThan(0.9));
    });
  });

  group('Calibration entity', () {
    test('stores timestamp', () {
      final now = DateTime(2026, 9, 7);
      final calibration = Calibration(
        markerWidthPixels: 100,
        markerHeightPixels: 100,
        realWidthCm: 30,
        cmPerPixel: 0.3,
        confidence: 0.9,
        timestamp: now,
      );
      expect(calibration.timestamp, now);
      expect(calibration.pixelsToCm(10), 3.0);
    });
  });
}