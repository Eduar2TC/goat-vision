import 'package:goatvision/domain/entities/calibration.dart';
import 'package:goatvision/domain/entities/detection.dart';
import 'package:goatvision/domain/entities/morphometric_features.dart';
import 'package:goatvision/domain/entities/prediction.dart';
import 'package:goatvision/domain/entities/quality_assessment.dart';

class CaptureImage {
  final String path;
  final int width;
  final int height;
  final DateTime timestamp;

  const CaptureImage({
    required this.path,
    required this.width,
    required this.height,
    required this.timestamp,
  });
}

abstract class AnalyzeGoatUseCase {
  Future<void> execute(CaptureImage image);
}

abstract class DetectGoatUseCase {
  Future<Detection?> execute(CaptureImage image);
}

abstract class SegmentGoatUseCase {
  Future<Object?> execute(CaptureImage image);
}

abstract class DetectLandmarksUseCase {
  Future<Object?> execute(CaptureImage image);
}

abstract class CalibrateImageUseCase {
  Future<Calibration> execute(CaptureImage image);
}

abstract class ExtractMorphometricsUseCase {
  Future<MorphometricFeatures> execute(CaptureImage image);
}

abstract class PredictWeightUseCase {
  Future<Prediction> execute(MorphometricFeatures features);
}

abstract class EvaluateCaptureQualityUseCase {
  Future<QualityAssessment> execute(CaptureImage image);
}