import 'dart:typed_data';

import 'package:flutter_test/flutter_test.dart';
import 'package:goatvision/core/ml/mock_ml_services.dart';
import 'package:goatvision/domain/entities/detection.dart';
import 'package:goatvision/domain/entities/landmark.dart';

void main() {
  group('MockGoatSegmenter', () {
    test('produces a mask within the bounding box', () async {
      final segmenter = MockGoatSegmenter();
      final detection = Detection(
        x: 10,
        y: 20,
        width: 100,
        height: 80,
        confidence: 0.9,
      );

      final mask = await segmenter.segment(
        Uint8List(0),
        320,
        240,
        detection,
      );

      expect(mask.length, 240);
      expect(mask[0].length, 320);
    });
  });

  group('MockLandmarkDetector', () {
    test('detects all 10 anatomical landmarks', () async {
      final detector = MockLandmarkDetector();
      final detection = Detection(
        x: 10,
        y: 20,
        width: 100,
        height: 80,
        confidence: 0.9,
      );

      final result = await detector.detectLandmarks(
        Uint8List(0),
        320,
        240,
        detection,
      );

      expect(result.landmarks.length, LandmarkType.all.length);
      expect(result.overallConfidence, greaterThan(0.5));
    });

    test('retrieves landmark by type', () async {
      final detector = MockLandmarkDetector();
      final detection = Detection(
        x: 10,
        y: 20,
        width: 100,
        height: 80,
        confidence: 0.9,
      );

      final result = await detector.detectLandmarks(
        Uint8List(0),
        320,
        240,
        detection,
      );

      expect(result.getLandmark(LandmarkType.withers), isNotNull);
      expect(result.getLandmark(LandmarkType.head), isNotNull);
    });
  });
}