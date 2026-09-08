import 'dart:typed_data';
import 'package:goatvision/core/ml/ml_interfaces.dart';
import 'package:goatvision/core/ml/mock_ml_services.dart';
import 'package:goatvision/core/ml/reference_weight_predictor.dart';
import 'package:goatvision/core/utils/app_logger.dart';
import 'package:goatvision/core/vision/morphometric_calculator.dart';
import 'package:goatvision/domain/entities/calibration.dart';
import 'package:goatvision/domain/entities/detection.dart';
import 'package:goatvision/domain/entities/landmark.dart';
import 'package:goatvision/domain/entities/morphometric_features.dart';
import 'package:goatvision/domain/entities/model_info.dart';
import 'package:goatvision/domain/entities/prediction.dart';
import 'package:goatvision/domain/entities/quality_assessment.dart';

class AnalysisStageResult {
  final String stageName;
  final bool success;
  final String detail;
  const AnalysisStageResult({
    required this.stageName,
    required this.success,
    required this.detail,
  });

  const AnalysisStageResult.success(this.stageName, String detail)
      : success = true,
        detail = detail;

  const AnalysisStageResult.failure(this.stageName, String detail)
      : success = false,
        detail = detail;
}

enum RunMode { mock, real }

class AnalysisPipeline {
  final GoatDetectorService detector;
  final GoatSegmenterService segmenter;
  final LandmarkDetectorService landmarkDetector;
  final WeightPredictorService weightPredictor;
  final RunMode mode;

  const AnalysisPipeline({
    required this.detector,
    required this.segmenter,
    required this.landmarkDetector,
    required this.weightPredictor,
    required this.mode,
  });

  factory AnalysisPipeline.mock() => AnalysisPipeline(
        detector: MockGoatDetector(),
        segmenter: MockGoatSegmenter(),
        landmarkDetector: MockLandmarkDetector(),
        weightPredictor: MockWeightPredictor(),
        mode: RunMode.mock,
      );

  /// Dev-mode pipeline whose weight stage uses the published reference
  /// formula instead of a toy value; CV stages stay simulated.
  factory AnalysisPipeline.reference() => AnalysisPipeline(
        detector: MockGoatDetector(),
        segmenter: MockGoatSegmenter(),
        landmarkDetector: MockLandmarkDetector(),
        weightPredictor: ReferenceWeightPredictor(),
        mode: RunMode.mock,
      );

  Future<void> loadAll() async {
    await detector.load();
    await segmenter.load();
    await landmarkDetector.load();
    await weightPredictor.load();
  }

  Future<void> unloadAll() async {
    await detector.unload();
    await segmenter.unload();
    await landmarkDetector.unload();
    await weightPredictor.unload();
  }

  Future<List<AnalysisStageResult>> analyze({
    required Uint8List imageBytes,
    required int width,
    required int height,
    required List<Landmark> landmarks,
    required Calibration calibration,
    required MorphometricFeatures features,
  }) async {
    // Cada etapa ejecuta trabajo REAL.  El progreso mostrado por la UI
    // refleja etapas realmente ejecutadas (spec §41: no progreso falso).
    final stages = <AnalysisStageResult>[];

    List<Detection> detections = const [];
    try {
      detections = await detector.detect(imageBytes, width, height);
      if (detections.isEmpty) {
        stages.add(const AnalysisStageResult.failure('deteccion',
            'No se detectó ninguna cabra'));
      } else {
        stages.add(AnalysisStageResult.success('deteccion',
            'Cabra detectada (${(detections.first.confidence * 100).toStringAsFixed(0)}%)'));
      }
    } catch (e) {
      AppLogger.instance.error('Detection stage failed', error: e);
      stages.add(const AnalysisStageResult.failure('deteccion',
          'Error en la detección'));
    }

    try {
      final det = detections.isEmpty ? null : detections.first;
      if (det == null) {
        stages.add(const AnalysisStageResult.failure('silueta',
            'No se puede analizar la silueta sin detección'));
      } else {
        final mask = await segmenter.segment(imageBytes, width, height, det);
        final area = mask.fold<int>(
          0,
          (sum, row) => sum + row.where((v) => v > 0).length,
        );
        stages.add(AnalysisStageResult.success('silueta',
            'Silueta analizada (${area} px)'));
      }
    } catch (e) {
      AppLogger.instance.error('Segmentation stage failed', error: e);
      stages.add(const AnalysisStageResult.failure('silueta',
          'Error al analizar la silueta'));
    }

    try {
      final det = detections.isEmpty ? null : detections.first;
      if (det == null) {
        stages.add(const AnalysisStageResult.failure('landmarks',
            'No se pueden detectar landmarks sin detección'));
      } else {
        final lm = await landmarkDetector.detectLandmarks(
          imageBytes,
          width,
          height,
          det,
        );
        stages.add(AnalysisStageResult.success('landmarks',
            '${lm.landmarks.length} landmarks detectados'));
      }
    } catch (e) {
      AppLogger.instance.error('Landmark stage failed', error: e);
      stages.add(const AnalysisStageResult.failure('landmarks',
          'Error al detectar landmarks'));
    }

    try {
      final valid = weightPredictor.validateFeatures(features);
      if (!valid) {
        stages.add(const AnalysisStageResult.failure('medidas',
            'Medidas fuera de rango válido'));
      } else {
        stages.add(const AnalysisStageResult.success('medidas',
            'Medidas calculadas correctamente'));
      }
    } catch (e) {
      AppLogger.instance.error('Morphometric stage failed', error: e);
      stages.add(const AnalysisStageResult.failure('medidas',
          'Error al calcular medidas'));
    }

    try {
      final prediction = await weightPredictor.predict(features);
      stages.add(AnalysisStageResult.success('peso',
          'Peso estimado: ${prediction.estimatedWeightKg.toStringAsFixed(1)} kg'));
    } catch (e) {
      AppLogger.instance.error('Weight stage failed', error: e);
      stages.add(const AnalysisStageResult.failure('peso',
          'No se pudo estimar el peso'));
    }

    return stages;
  }
}