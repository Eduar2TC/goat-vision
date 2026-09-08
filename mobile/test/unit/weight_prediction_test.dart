import 'dart:typed_data';

import 'package:flutter_test/flutter_test.dart';
import 'package:goatvision/core/ml/mock_ml_services.dart';
import 'package:goatvision/core/ml/weight_prediction_service.dart';
import 'package:goatvision/core/vision/morphometric_calculator.dart';
import 'package:goatvision/domain/entities/calibration.dart';
import 'package:goatvision/domain/entities/detection.dart';
import 'package:goatvision/domain/entities/landmark.dart';
import 'package:goatvision/domain/entities/morphometric_features.dart';

void main() {
  group('MockWeightPredictor', () {
    test('returns positive weight with range', () async {
      final predictor = MockWeightPredictor();
      final features = _features();

      final prediction = await predictor.predict(features);

      expect(prediction.estimatedWeightKg, greaterThan(0));
      expect(prediction.lowerBoundKg, lessThan(prediction.estimatedWeightKg));
      expect(prediction.upperBoundKg, greaterThan(prediction.estimatedWeightKg));
      expect(prediction.confidence, greaterThan(0));
      expect(prediction.modelVersion, contains('mock'));
    });

    test('formatted display avoids false precision', () async {
      final predictor = MockWeightPredictor();
      final prediction = await predictor.predict(_features());
      expect(prediction.formattedWeight, isNot(contains('.')));
    });
  });

  group('WeightPredictionService', () {
    test('validates features before prediction', () async {
      final service = WeightPredictionService(MockWeightPredictor());

      final invalidFeatures = MorphometricFeatures(
        bodyLengthCm: 0,
        withersHeightCm: 0,
        rumpHeightCm: 0,
        chestDepthCm: 0,
        chestWidthCm: 0,
        rumpWidthCm: 0,
        rumpLengthCm: 0,
        pawHeightCm: 0,
        bodyAreaCm2: 0,
        bodyAspectRatio: 1,
      );

      final result = await service.run(invalidFeatures);
      expect(result.valid, isFalse);
      expect(result.errors, isNotEmpty);
    });

    test('produces valid result for good features', () async {
      final service = WeightPredictionService(MockWeightPredictor());
      final result = await service.run(_features());
      expect(result.valid, isTrue);
      expect(result.prediction.estimatedWeightKg, greaterThan(0));
    });
  });

  group('MockDetector', () {
    test('detects a goat with valid bounding box', () async {
      final detector = MockGoatDetector();
      final detections = await detector.detect(
        Uint8List.fromList([]),
        320,
        240,
      );

      expect(detections, isNotEmpty);
      final det = detections.first;
      expect(det.x, greaterThanOrEqualTo(0));
      expect(det.y, greaterThanOrEqualTo(0));
      expect(det.width, greaterThan(0));
      expect(det.width + det.x, lessThanOrEqualTo(320));
      expect(det.confidence, greaterThan(0.5));
    });
  });

  group('ConfidenceCalculator', () {
    test('combines confidence sources', () {
      final confidence = MockConfidenceCalculator.synthetic(0.9, 0.8, 0.85);
      expect(confidence, greaterThan(0.7));
      expect(confidence, lessThanOrEqualTo(1.0));
    });
  });
}

MorphometricFeatures _features() {
  final calibration = Calibration(
    markerWidthPixels: 100,
    markerHeightPixels: 100,
    realWidthCm: 10,
    cmPerPixel: 0.1,
    confidence: 0.9,
    timestamp: DateTime.now(),
  );

  final features = MorphometricCalculator.extract(
    [
      const Landmark(type: LandmarkType.withers, x: 100, y: 50, confidence: 0.9),
      const Landmark(type: LandmarkType.tailBase, x: 400, y: 60, confidence: 0.9),
      const Landmark(type: LandmarkType.hoof, x: 100, y: 300, confidence: 0.9),
    ],
    calibration,
    0,
  );
  return features;
}

class MockConfidenceCalculator {
  static double synthetic(double det, double seg, double lm) {
    return (det * 0.4 + seg * 0.3 + lm * 0.3).clamp(0.0, 1.0);
  }
}