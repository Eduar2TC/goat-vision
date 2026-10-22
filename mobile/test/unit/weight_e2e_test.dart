import 'dart:math';
import 'dart:typed_data';

import 'package:flutter_test/flutter_test.dart';
import 'package:goatvision/core/ml/mock_ml_services.dart';
import 'package:goatvision/core/ml/reference_weight_predictor.dart';
import 'package:goatvision/core/ml/weight_prediction_service.dart';
import 'package:goatvision/core/vision/morphometric_calculator.dart';
import 'package:goatvision/domain/entities/calibration.dart';
import 'package:goatvision/domain/entities/morphometric_features.dart';

/// E2E del cálculo de peso (modo dev con CV mock): replica el flujo real
/// de CaptureScreen._capture → session.morphometrics → AnalysisScreen
/// usando los mismos servicios y la misma conversión de claves `*_cm`.
///
/// Barrido de resoluciones/aspectos y de semillas del detector: si cualquier
/// combinación deja de producir una predicción válida, el test falla — el
/// usuario ya no obtendría peso en pantalla.
///
/// Cobertura garantizada contra:
///  * medidas fuera del rango del estudio (Paredes-Chocce 2025),
///  * dependencia de las medidas con el tamaño/orientación del encuadre,
///  * ruptura de la alineación de claves *_cm entre toMap() y sus lectores.
const _resoluciones = <(int, int, String)>[
  (640, 360, 'landscape qvga-wide'),
  (640, 480, 'landscape 4:3'),
  (854, 480, 'landscape nhd'),
  (1024, 768, 'landscape xga 4:3'),
  (1280, 720, 'landscape hd'),
  (1440, 1080, 'landscape 4:3 qhd'),
  (1920, 1080, 'landscape fhd'),
  (2560, 1080, 'landscape ultrawide 21:9'),
  (480, 800, 'portrait pequeño'),
  (720, 1280, 'portrait hd'),
  (1080, 1920, 'portrait fhd'),
];

const _semillas = [1, 7, 42, 99, 2026];

Future<WeightPredictionResult> _runFullFlow({
  required int w,
  required int h,
  required int seed,
}) async {
  // Los mismos servicios y orden que usa CaptureScreen.
  final detector = MockGoatDetector(random: Random(seed));
  final segmenter = MockGoatSegmenter();
  final lmDetector = MockLandmarkDetector(random: Random(seed + 7));
  const markerDetector = MockMarkerDetector();

  final det = (await detector.detect(Uint8List(0), w, h)).first;
  final mask = await segmenter.segment(Uint8List(0), w, h, det);
  final bodyAreaPixels = mask.fold<double>(
    0,
    (sum, row) => sum + row.where((v) => v > 0).length,
  );

  final lm = await lmDetector.detectLandmarks(Uint8List(0), w, h, det);
  final marker = await markerDetector.detectMarker(Uint8List(0), w, h);  final calibration = Calibration(
      markerWidthPixels: marker.$1,
      markerHeightPixels: marker.$2,
      realWidthCm: 30,
      cmPerPixel: 30.0 / marker.$1,
      confidence: 0.9,
      timestamp: DateTime.now(),
      method: 'marker',
    );

  final features = MorphometricCalculator.extract(
    lm.landmarks,
    calibration,
    bodyAreaPixels,
  );

  // La sesión guarda features.toMap(); el análisis reconstruye las features
  // con claves *_cm (mismo mapeo que AnalysisScreen._featuresFromSession).
  final sessionMap = features.toMap();
  final viaSession = MorphometricFeatures(
    bodyLengthCm: sessionMap['body_length_cm'] ?? 0,
    withersHeightCm: sessionMap['withers_height_cm'] ?? 0,
    rumpHeightCm: sessionMap['rump_height_cm'] ?? 0,
    chestDepthCm: sessionMap['chest_depth_cm'] ?? 0,
    chestWidthCm: sessionMap['chest_width_cm'] ?? 0,
    rumpWidthCm: sessionMap['rump_width_cm'] ?? 0,
    rumpLengthCm: sessionMap['rump_length_cm'] ?? 0,
    pawHeightCm: sessionMap['paw_height_cm'] ?? 0,
    bodyAreaCm2: sessionMap['body_area_cm2'] ?? 0,
    bodyAspectRatio: sessionMap['body_aspect_ratio'] ?? 1,
  );

  // Medidas plausibles: positivas y anatómicamente acotadas, sin depender
  // del tamaño ni del aspecto del encuadre.
  final medidas = <String, double>{
    'body_length_cm': viaSession.bodyLengthCm,
    'withers_height_cm': viaSession.withersHeightCm,
    'rump_height_cm': viaSession.rumpHeightCm,
    'chest_depth_cm': viaSession.chestDepthCm,
    'chest_width_cm': viaSession.chestWidthCm,
    'rump_width_cm': viaSession.rumpWidthCm,
    'rump_length_cm': viaSession.rumpLengthCm,
    'paw_height_cm': viaSession.pawHeightCm,
  };
  medidas.forEach((k, v) {
    expect(v, greaterThan(0), reason: '$k debe ser positivo');
    expect(v, lessThan(200), reason: '$k anatómicamente implausible');
  });

  // Predicción con el modelo de referencia (mismo proveedor que la app).
  final service = WeightPredictionService(ReferenceWeightPredictor());
  return service.run(viaSession);
}

void main() {
  group('barrido de resoluciones/aspectos', () {
    for (final (w, h, label) in _resoluciones) {
      test('produce peso válido a ${w}x${h} ($label)', () async {
        final result = await _runFullFlow(w: w, h: h, seed: 42);

        expect(result.valid, isTrue,
            reason: 'medidas fuera de rango: ${result.errors}');
        // Rango corporal de una cabra criolla (no una elefanta ni un ratón):
        // en cm se valida el estudio, el peso debe caer en banda plausible.
        expect(result.prediction.estimatedWeightKg, inInclusiveRange(15, 120),
            reason: 'peso implausible a ${w}x${h}');
        expect(result.prediction.lowerBoundKg,
            lessThan(result.prediction.estimatedWeightKg));
        expect(result.prediction.upperBoundKg,
            greaterThan(result.prediction.estimatedWeightKg));
        expect(result.prediction.modelVersion, contains('ref-'),
            reason: 'el modelo de referencia no fue utilizado a ${w}x${h}');
      });
    }
  });

  group('variación de semillas del detector', () {
    for (final seed in _semillas) {
      test('produce peso válido con seed=$seed a 1280x720', () async {
        final result = await _runFullFlow(w: 1280, h: 720, seed: seed);
        expect(result.valid, isTrue,
            reason: 'medidas fuera de rango con seed=$seed: ${result.errors}');
        expect(result.prediction.estimatedWeightKg, inInclusiveRange(15, 120),
            reason: 'peso implausible con seed=$seed');
      });
    }
  });
}
