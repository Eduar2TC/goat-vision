import 'dart:typed_data';
import 'dart:math';
import 'package:goatvision/core/ml/marker_detector.dart';
import 'package:goatvision/core/ml/ml_interfaces.dart';
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
    // Caja de cabra con proporciones de perfil plausibles: la altura se
    // ancla al ANCHO de la imagen (no a su alto) para que las medidas en cm
    // sean coherentes en cualquier aspecto de encuadre. El marcador mock
    // (MockMarkerDetector) cubre 7% del ancho ≈ 30 cm reales, así que la
    // caja (44–50% del ancho) representa un cuerpo de ~80–95 cm.
    final goatWidth = width * (0.44 + _random.nextDouble() * 0.06);
    final goatHeight = min(goatWidth * 0.80, height * 0.90);
    final x = width * (0.15 + _random.nextDouble() * 0.05);
    final y = (height - goatHeight) * (0.15 + _random.nextDouble() * 0.05);

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
        features: <String>[],
        metrics: <String, double>{},
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
  Future<ModelInfo> getModelInfo() async => ModelInfo(
        modelVersion: 'mock-goat-segmenter-v1.0',
        datasetVersion: 'mock-dataset',
        trainingDate: DateTime(2026, 9, 1),
        algorithm: 'mock',
        features: <String>[],
        metrics: <String, double>{},
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

    // Anatomía de perfil con proporciones físicas plausibles (cabra de
    // ~40 kg: cuerpo ~85 cm, cruz ~70 cm). Las fracciones se miden sobre la
    // caja de detección; al anclar la altura de la caja al ancho de la
    // imagen (ver MockGoatDetector) las medidas resultantes en cm quedan
    // dentro del rango del estudio de referencia en cualquier resolución.
    Landmark lm(LandmarkType t, double dx, double dy) {
      final jx = _random.nextDouble() * w * 0.005;
      final jy = _random.nextDouble() * h * 0.005;
      return Landmark(
        type: t,
        x: cx + w * dx + jx,
        y: cy + h * dy + jy,
        confidence: 0.75 + _random.nextDouble() * 0.2,
      );
    }

    final landmarks = <Landmark>[
      lm(LandmarkType.head, -0.42, -0.30),
      lm(LandmarkType.neck, -0.22, -0.28),
      lm(LandmarkType.withers, 0.0, -0.10),
      lm(LandmarkType.back, 0.18, -0.08),
      lm(LandmarkType.rump, 0.25, -0.06),
      lm(LandmarkType.chest, -0.05, 0.09),
      lm(LandmarkType.frontLeg, -0.08, 0.22),
      lm(LandmarkType.hindLeg, 0.30, 0.25),
      lm(LandmarkType.hoof, 0.10, 0.33),
      lm(LandmarkType.tailBase, 0.44, -0.10),
    ];

    return LandmarkDetectionResult(
      landmarks: landmarks,
      overallConfidence: 0.82 + _random.nextDouble() * 0.1,
    );
  }

  @override
  Future<ModelInfo> getModelInfo() async => ModelInfo(
        modelVersion: 'mock-goat-landmarks-v1.0',
        datasetVersion: 'mock-dataset',
        trainingDate: DateTime(2026, 9, 1),
        algorithm: 'mock',
        features: <String>[],
        metrics: <String, double>{},
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
        bodyLength * 0.45 + (withersHeight > 0 ? withersHeight * 0.3 : 0.0);
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
      {List<String>? errors,}) {
    return features.bodyLengthCm > 0 && features.withersHeightCm > 0;
  }

  @override
  Future<ModelInfo> getModelInfo() async => ModelInfo(
        modelVersion: 'mock-goat-weight-v1.0',
        datasetVersion: 'mock-dataset',
        trainingDate: DateTime(2026, 9, 1),
        algorithm: 'mock',
        features: <String>[
          'body_length',
          'withers_height',
          'rump_height',
          'chest_depth',
          'chest_width',
          'rump_width',
          'rump_length',
          'paw_height',
        ],
        metrics: <String, double>{},
      );
}

class MockMarkerDetector implements MarkerDetectorService {
  const MockMarkerDetector();

  @override
  Future<(double, double, double)> detectMarker(
    Uint8List imageBytes,
    int width,
    int height,
  ) async {
    // Marcador físico de 30x30 cm: cuadrado en píxeles y pequeño respecto
    // a la cabra (≈7% del ancho de la imagen), para que la escala cm/px
    // derivada de él produzca medidas de cabra plausibles. Ver
    // MockGoatDetector para la coherencia de escena.
    final markerSize = width * 0.07;
    return (markerSize, markerSize, 0.92);
  }
}

class MockQualityAnalyzer {
  const MockQualityAnalyzer();

  Future<bool> evaluate() async => true;
}
