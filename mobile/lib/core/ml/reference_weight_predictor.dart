import 'dart:math';
import 'package:goatvision/core/ml/ml_interfaces.dart';
import 'package:goatvision/domain/entities/model_info.dart';
import 'package:goatvision/domain/entities/morphometric_features.dart';
import 'package:goatvision/domain/entities/prediction.dart';

/// Reference body-weight model based on published zoometric equations.
///
/// Used as the out-of-the-box fallback when no locally-trained model is
/// embedded. It is NOT a calibrated GoatVision model: the coefficients and
/// residual standard error come from a peer-reviewed study, so the interval
/// reflects the study's uncertainty, not our pipeline's PICP.
///
/// Reference: Paredes-Chocce et al. (2025). Predicting body weight using body
/// measurements in Peruvian creole goats. Biodiversitas 26(7):3193-3198.
/// DOI: 10.13057/biodiv/d260710. n = 356.
///
/// BW (kg) = -45.642 + 0.71*TG + 0.21*RH + 0.99*RW, RSE = 6.305 kg.
/// Thoracic girth (TG) is not measured on a lateral view, so it is estimated
/// as the Ramanujan ellipse perimeter of the chest cross-section from chest
/// depth (D) and chest width (CW).
class ReferenceWeightPredictor implements WeightPredictorService {
  static const String modelVersion = 'ref-paredes-chocce-2025';
  static const String datasetVersion = 'biodiv-d260710';
  static const double r2Adjusted = 0.644;
  static const double rseKg = 6.305;
  static const int nSamples = 356;
  static const double _p80Z = 1.2816;

  static const Map<String, List<double>> _studyRanges = {
    // Chest depth is not published; this range is the ellipse-girth fit that
    // reproduces the published thoracic-girth span [65, 103] cm.
    'chestDepthCm': [22.0, 45.0],
    'chestWidthCm': [12.0, 27.0],
    'rumpHeightCm': [51.0, 89.2],
    'rumpWidthCm': [8.7, 27.0],
  };

  /// Perimeter of the chest cross-section via the Ramanujan ellipse estimate.
  /// Semi-axes: a = depth/2 (vertical), b = width/2 (horizontal).
  double estimateThoracicGirth({
    required double chestDepthCm,
    required double chestWidthCm,
  }) {
    final a = chestDepthCm / 2.0;
    final b = chestWidthCm / 2.0;
    return pi * (3.0 * (a + b) - sqrt((3.0 * a + b) * (a + 3.0 * b)));
  }

  @override
  Future<void> load() async {}

  @override
  Future<void> unload() async {}

  @override
  Future<Prediction> predict(MorphometricFeatures features) async {
    final tg = estimateThoracicGirth(
      chestDepthCm: features.chestDepthCm,
      chestWidthCm: features.chestWidthCm,
    );
    final estimated = -45.642 +
        0.71 * tg +
        0.21 * features.rumpHeightCm +
        0.99 * features.rumpWidthCm;
    final halfInterval = _p80Z * rseKg;
    return Prediction(
      estimatedWeightKg: estimated,
      lowerBoundKg: estimated - halfInterval,
      upperBoundKg: estimated + halfInterval,
      confidence: r2Adjusted,
      modelVersion: modelVersion,
    );
  }

  @override
  bool validateFeatures(MorphometricFeatures features, {List<String>? errors}) {
    final values = {
      'chestDepthCm': features.chestDepthCm,
      'chestWidthCm': features.chestWidthCm,
      'rumpHeightCm': features.rumpHeightCm,
      'rumpWidthCm': features.rumpWidthCm,
    };
    var valid = true;
    values.forEach((name, value) {
      if (value <= 0) {
        valid = false;
        errors?.add('$name must be positive (got $value)');
        return;
      }
      final range = _studyRanges[name]!;
      if (value < range[0] || value > range[1]) {
        valid = false;
        errors?.add('$name out of reference range '
            '[${range[0]}, ${range[1]}] cm (got $value)');
      }
    });
    return valid;
  }

  @override
  Future<ModelInfo> getModelInfo() async {
    return ModelInfo(
      modelVersion: modelVersion,
      datasetVersion: datasetVersion,
      trainingDate: DateTime(2025, 7),
      algorithm: 'Multiple linear regression (stepwise) — Paredes-Chocce '
          'et al. (2025), Biodiversitas 26(7), DOI 10.13057/biodiv/d260710',
      features: const [
        'chest_depth_cm',
        'chest_width_cm',
        'rump_height_cm',
        'rump_width_cm',
      ],
      metrics: const {
        'r2': r2Adjusted,
        'rse': rseKg,
        'n_samples': nSamples.toDouble(),
      },
    );
  }
}