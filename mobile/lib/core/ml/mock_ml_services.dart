import 'dart:typed_data';
import 'dart:math';
import 'package:goatvision/core/ml/ml_interfaces.dart';
import 'package:goatvision/domain/entities/calibration.dart';
import 'package:goatvision/domain/entities/detection.dart';
import 'package:goatvision/domain/entities/landmark.dart';
import 'package:goatvision/domain/entities/model_info.dart';
import 'package:goatvision/domain/entities/morphometric_features.dart';
import 'package:goatvision/domain/entities/prediction.dart';

class MockGoatDetector implements GoatDetectorService {
  final Random _random;

  MockGoatDetector({Random? random}) : _random = random ?? Random(42);

  @override
  Future<void> load() async {}

  @override
  Future<void> unload() async {}

  @override
  Future<List<Detection>> detect(
    Uint8List imageBytes,
    int width,
    int height,
  ) async {
    final goatWidth = width * (0.35 + _random.nextDouble() * 0.15);
    final goatHeight = height * (0.45 + _random.nextDouble() * 0.15);
    final x = width * (0.15 + _random.nextDouble() * 0.05);
    final y = height * (0.15 + _random.nextDouble() * 0.05);

    return [
      Detection(
        x: x,
        y: y,
        width: goatWidth,
        height: goatHeight,
        confidence: 0.82 + _random.nextDouble() * 0.15,
      ),
    ];
  }

  @override
  Future<ModelInfo> getModelInfo() async => ModelInfo(
        modelVersion: 'mock-goat-detector-v1.0',
        datasetVersion: 'mock-dataset',
        trainingDate: DateTime(2026, 9, 1),
        algorithm: 'mock',
        features: [],
        metrics: {},
      );
}

class MockGoatSegmenter implements GoatSegmenterService {
  @override
  Future<void> load() async {}

  @override
  Future<void> unload() async {}

  @override
  Future<List<List<int>>> segment(
    Uint8List imageBytes,
    int width,
    int height,
    Detection detection,
  ) async {
    final mask = List.generate(
      height,
      (_) => List.filled(width, 0),
      growable: false,
    );

    final cx = detection.centerX;
    final cy = detection.centerY;
    final rx = detection.width * 0.42;
    final ry = detection.height * 0.48;

    for (int dy = 0; dy < height; dy++) {
      for (int dx = 0; dx < width; dx++) {
        final nx = (dx - cx) / rx;
        final ny = (dy - cy) / ry;
        if (nx * nx + ny * ny <= 1.0) mask[dy][dx] = 255;
      }
    }
    return mask;
  }

  @override
  Future<ModelInfo> getModelInfo() async => const ModelInfo(
        modelVersion: 'mock-goat-segmenter-v1.0',
        datasetVersion: 'mock-dataset',
        trainingDate: DateTime(2026, 9, 1),
        algorithm: 'mock',
        features: [],
        metrics: {},
      );
}

class MockLandmarkDetector implements LandmarkDetectorService {
  final Random _random;

  MockLandmarkDetector({Random? random}) : _random = random ?? Random(7);

  @override
  Future<void> load() async {}

  @override
  Future<void> unload() async {}

  @override
  Future<LandmarkDetectionResult> detectLandmarks(
    Uint8List imageBytes,
    int width,
    int height,
    Detection detection,
  ) async {
    final cx = detection.centerX;
    final cy = detection.centerY;
    final w = detection.width;
    final h = detection.height;

    Landmark _lm(LandmarkType t, double dx, double dy) {
      final jx = _random.nextDouble() * w * 0.02;
      final jy = _random.nextDouble() * h * 0.02;
      return Landmark(
        type: t,
        x: cx + w * dx + jx,
        y: cy + h * dy + jy,
        confidence: 0.75 + _random.nextDouble() * 0.2,
      );
    }

    final landmarks = [
      _lm(LandmarkType.head, -0.42, 0.05),
      _lm(LandmarkType.neck, -0.22, -0.05),
      _lm(LandmarkType.withers, 0.0, -0.42),
      _lm(LandmarkType.back, 0.18, -0.32),
      _lm(LandmarkType.rump, 0.42, -0.28),
      _lm(LandmarkType.chest, -0.05, 0.1),
      _lm(LandmarkType.frontLeg, -0.08, 0.45),
      _lm(LandmarkType.hindLeg, 0.35, 0.45),
      _lm(LandmarkType.hoof, 0.32, 0.48),
      _lm(LandmarkType.tailBase, 0.44, -0.2),
    ];

    return LandmarkDetectionResult(
      landmarks: landmarks,
      overallConfidence: 0.82 + _random.nextDouble() * 0.1,
    );
  }

  @override
  Future<ModelInfo> getModelInfo() async => const ModelInfo(
        modelVersion: 'mock-goat-landmarks-v1.0',
        datasetVersion: 'mock-dataset',
        trainingDate: DateTime(2026, 9, 1),
        algorithm: 'mock',
        features: [],
        metrics: {},
      );
}

class MockWeightPredictor implements WeightPredictorService {
  @override
  Future<void> load() async {}

  @override
  Future<void> unload() async {}

  @override
  Future<Prediction> predict(MorphometricFeatures features) async {
    final bodyLength = features.bodyLengthCm;
    final withersHeight = features.withersHeightCm;

    final weight =
        bodyLength * 0.45 + withersHeight > 0 ? withersHeight * 0.3 : 0.0;
    final base = weight.abs().clamp(8.0, 100.0).toDouble();

    final uncertainty = base * (0.06 + withersHeight / 1000);
    return Prediction(
      estimatedWeightKg: base,
      lowerBoundKg: (base - uncertainty).clamp(1.0, 500.0).toDouble(),
      upperBoundKg: (base + uncertainty).clamp(1.0, 500.0).toDouble(),
      confidence: 0.87,
      modelVersion: 'mock-goat-weight-v1.0',
    );
  }

  @override
  bool validateFeatures(MorphometricFeatures features,
      {List<String>? errors}) {
    return features.bodyLengthCm > 0 && features.withersHeightCm > 0;
  }

  @override
  Future<ModelInfo> getModelInfo() async => const ModelInfo(
        modelVersion: 'mock-goat-weight-v1.0',
        datasetVersion: 'mock-dataset',
        trainingDate: DateTime(2026, 9, 1),
        algorithm: 'mock',
        features: [
          'body_length',
          'withers_height',
          'rump_height',
          'chest_depth',
          'chest_width',
          'rump_width',
          'rump_length',
          'paw_height',
        ],
        metrics: {},
      );
}

class MockMarkerDetector {
  const MockMarkerDetector();

  Future<(double, double, double)> detectMarker(
    Uint8List imageBytes,
    int width,
    int height,
  ) async {
    final markerWidth = width * 0.18;
    final markerHeight = width * 0.18;
    return (markerWidth, markerHeight, 0.92);
  }
}

class MockQualityAnalyzer {
  const MockQualityAnalyzer();

  Future<bool> evaluate() async => true;
}