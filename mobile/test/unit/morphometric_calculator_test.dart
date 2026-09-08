import 'package:flutter_test/flutter_test.dart';
import 'package:goatvision/core/vision/morphometric_calculator.dart';
import 'package:goatvision/domain/entities/calibration.dart';
import 'package:goatvision/domain/entities/landmark.dart';

Calibration _calibration() => Calibration(
      markerWidthPixels: 100,
      markerHeightPixels: 100,
      realWidthCm: 10,
      cmPerPixel: 0.1,
      confidence: 0.9,
      timestamp: DateTime(2026, 9, 7),
    );

void main() {
  group('MorphometricCalculator', () {
    test('computes bodyLength from withers to tail', () {
      final calibration = _calibration();
      final landmarks = [
        const Landmark(
          type: LandmarkType.withers,
          x: 100,
          y: 50,
          confidence: 0.9,
        ),
        const Landmark(
          type: LandmarkType.tailBase,
          x: 300,
          y: 60,
          confidence: 0.9,
        ),
      ];

      final features = MorphometricCalculator.extract(
        landmarks,
        calibration,
        0,
      );

      expect(
        features.bodyLengthCm,
        closeTo(20.0, 0.5),
      );
    });

    test('computes withersHeight from withers to hoof', () {
      final calibration = _calibration();
      final landmarks = [
        const Landmark(
          type: LandmarkType.withers,
          x: 100,
          y: 100,
          confidence: 0.9,
        ),
        const Landmark(
          type: LandmarkType.hoof,
          x: 100,
          y: 300,
          confidence: 0.9,
        ),
      ];

      final features = MorphometricCalculator.extract(
        landmarks,
        calibration,
        0,
      );

      expect(features.withersHeightCm, closeTo(20.0, 0.5));
    });

    test('handles missing landmarks gracefully', () {
      final calibration = _calibration();
      final features = MorphometricCalculator.extract(
        const [],
        calibration,
        0,
      );

      expect(features.bodyLengthCm, 0);
      expect(features.withersHeightCm, 0);
    });

    test('computes chest width as fraction of body length', () {
      final calibration = _calibration();
      final landmarks = [
        const Landmark(
          type: LandmarkType.withers,
          x: 100,
          y: 50,
          confidence: 0.9,
        ),
        const Landmark(
          type: LandmarkType.tailBase,
          x: 400,
          y: 60,
          confidence: 0.9,
        ),
      ];

      final features = MorphometricCalculator.extract(
        landmarks,
        calibration,
        0,
      );

      expect(features.bodyLengthCm, closeTo(30.0, 0.5));
      expect(features.chestWidthCm, greaterThan(5.0));
    });
  });
}