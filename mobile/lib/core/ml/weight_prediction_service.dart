import 'dart:math';
import 'package:goatvision/core/ml/ml_interfaces.dart';
import 'package:goatvision/core/ml/mock_ml_services.dart';
import 'package:goatvision/domain/entities/morphometric_features.dart';
import 'package:goatvision/domain/entities/prediction.dart';
import 'package:goatvision/domain/entities/calibration.dart';
import 'package:goatvision/domain/entities/landmark.dart';
import 'package:goatvision/core/utils/range_validator.dart';
import 'package:flutter/foundation.dart';

class WeightPredictionResult {
  final Prediction prediction;
  final bool valid;
  final List<String> errors;

  const WeightPredictionResult({
    required this.prediction,
    required this.valid,
    required this.errors,
  });
}

class WeightPredictionService {
  final WeightPredictorService _predictor;

  WeightPredictionService(this._predictor);

  Future<WeightPredictionResult> run(MorphometricFeatures features) async {
    final errors = <String>[];
    final valid = _predictor.validateFeatures(features, errors: errors);

    final featureMap = features.toMap();
    final rangeErrors = RangeValidator.validateAll(featureMap);
    errors.addAll(rangeErrors.values);
    final allValid = valid && rangeErrors.isEmpty;

    if (!allValid) {
      return WeightPredictionResult(
        prediction: Prediction(
          estimatedWeightKg: 0,
          lowerBoundKg: 0,
          upperBoundKg: 0,
          confidence: 0,
          modelVersion: 'invalid',
        ),
        valid: false,
        errors: errors,
      );
    }

    final prediction = await _predictor.predict(features);
    return WeightPredictionResult(
      prediction: prediction,
      valid: true,
      errors: errors,
    );
  }
}

class ConfidenceCalculator {
  static double fromCalibration(Calibration calibration) {
    return calibration.confidence.clamp(0.0, 1.0);
  }

  static double baseConfidence({
    required double calibrationConfidence,
    required double landmarkConfidence,
    required double detectionConfidence,
    required int availableFeatures,
    required int totalFeatures,
  }) {
    final ratio = totalFeatures == 0
        ? 1.0
        : (availableFeatures / totalFeatures).clamp(0.0, 1.0);
    final weighted = calibrationConfidence * 0.3 +
        landmarkConfidence * 0.3 +
        detectionConfidence * 0.3 +
        ratio * 0.1;
    return weighted.clamp(0.0, 1.0);
  }
}