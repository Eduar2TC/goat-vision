import 'dart:async';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:goatvision/core/ml/analysis_pipeline.dart';
import 'package:goatvision/core/ml/aruco_marker_detector.dart';
import 'package:goatvision/core/ml/marker_detector.dart';
import 'package:goatvision/core/ml/ml_interfaces.dart';
import 'package:goatvision/core/ml/mock_ml_services.dart';
import 'package:goatvision/core/ml/reference_weight_predictor.dart';
import 'package:goatvision/core/ml/weight_prediction_service.dart';
import 'package:goatvision/domain/entities/calibration.dart';

export 'package:goatvision/core/ml/analysis_pipeline.dart'
    show AnalysisPipeline, RunMode;

final runModeProvider = StateProvider<RunMode>((ref) => RunMode.mock);

final markerDetectorProvider = Provider<MarkerDetectorService>((ref) {
  final mode = ref.watch(runModeProvider);
  return switch (mode) {
    // Detección real vía FFI OpenCV ArUco (tag36h11).
    RunMode.real => ArucoMarkerDetector(),
    RunMode.mock => const MockMarkerDetector(),
  };
});

final analysisPipelineProvider = Provider<AnalysisPipeline>((ref) {
  final mode = ref.watch(runModeProvider);
  if (mode == RunMode.real) {
    throw UnimplementedError(
      'RunMode.real requiere integrar los modelos TFLite '
      '(ver docs/ml/pipeline.md fase 4-8). Mientras tanto usa RunMode.mock.',
    );
  }
  return AnalysisPipeline.reference();
});

final weightPredictionServiceProvider =
    Provider<WeightPredictionService>((ref) {
  final mode = ref.watch(runModeProvider);
  final WeightPredictorService predictor;
  if (mode == RunMode.real) {
    throw UnimplementedError(
      'RunMode.real requiere goat_weight.tflite exportado '
      '(ver ml/export y docs/ml/training.md). Usa RunMode.mock.',
    );
  }
  predictor = ReferenceWeightPredictor();
  return WeightPredictionService(predictor);
});

class AnalysisSessionState {
  final String animalId;
  final double estimatedWeightKg;
  final double lowerWeightKg;
  final double upperWeightKg;
  final double confidence;
  final String modelVersion;
  final String datasetVersion;
  final Map<String, double> morphometrics;
  final DateTime timestamp;
  final String? imagePath;
  final Calibration calibration;

  const AnalysisSessionState({
    required this.animalId,
    required this.estimatedWeightKg,
    required this.lowerWeightKg,
    required this.upperWeightKg,
    required this.confidence,
    required this.modelVersion,
    required this.datasetVersion,
    required this.morphometrics,
    required this.timestamp,
    this.imagePath,
    required this.calibration,
  });
}

final analysisSessionProvider =
    StateProvider<AnalysisSessionState?>((ref) => null);
