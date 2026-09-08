import 'dart:async';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:goatvision/core/ml/analysis_pipeline.dart';
import 'package:goatvision/core/ml/mock_ml_services.dart';
import 'package:goatvision/core/ml/reference_weight_predictor.dart';
import 'package:goatvision/core/ml/weight_prediction_service.dart';

final runModeProvider = StateProvider<RunMode>((ref) => RunMode.mock);

final analysisPipelineProvider = Provider<AnalysisPipeline>((ref) {
  final mode = ref.watch(runModeProvider);
  if (mode == RunMode.real) {
    // FASE 4-8: construir AnalysisPipeline con los modelos TFLite reales
    // (goat_detector/segmenter/landmarks/weight) cuando existan.
    throw UnimplementedError(
      'RunMode.real requiere integrar los modelos TFLite '
      '(ver docs/ml/pipeline.md fase 4-8). Mientras tanto usa RunMode.mock.',
    );
  }
  // CV simulado, pero la etapa de peso usa la fórmula de referencia real.
  return AnalysisPipeline.reference();
});

final weightPredictionServiceProvider =
    Provider<WeightPredictionService>((ref) {
  final mode = ref.watch(runModeProvider);
  final WeightPredictorService predictor;
  if (mode == RunMode.real) {
    // FASE 7-8: WeightPredictorService con el modelo exportado
    // (goat_weight.tflite) entrenado con datos propios. Mientras no exista
    // se usa el predictor de referencia (literatura), nunca en RunMode.real.
    throw UnimplementedError(
      'RunMode.real requiere goat_weight.tflite exportado '
      '(ver ml/export y docs/ml/training.md). Usa RunMode.mock.',
    );
  }
  // Predictor de referencia (ecuaciones publicadas de Paredes-Chocce et al.
  // 2025). Es un modelo REAL basado en literatura, no un mock: da predicciones
  // utilizables en producto hasta que se entrene e integre el TFLite propio.
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
  });
}

final analysisSessionProvider =
    StateProvider<AnalysisSessionState?>((ref) => null);