import 'dart:typed_data';
import 'package:goatvision/domain/entities/calibration.dart';
import 'package:goatvision/domain/entities/morphometric_features.dart';
import 'package:goatvision/domain/entities/quality_assessment.dart';

double defaultClampDouble(double value, [double min = 0, double max = 1]) {
  return value.clamp(min, max).toDouble();
}

abstract interface class CameraFrameProcessor {
  Stream<Object> processFrames(Stream<Uint8List> frames);
  void dispose();
}

abstract interface class ImageProcessor {
  Uint8List resize(Uint8List imageBytes, int srcWidth, int srcHeight, int dstWidth, int dstHeight);
  Uint8List normalize(Uint8List imageBytes);
  double computeSharpness(Uint8List imageBytes, int width, int height);
  double estimateBrightness(Uint8List imageBytes, int width, int height);
}

abstract interface class MorphometricExtractor {
  Future<MorphometricFeatures> extract(
    Object segmentation,
    Object landmarks,
    Calibration calibration,
  );
}

abstract interface class QualityAnalyzer {
  Future<QualityAssessment> analyze({required Object detectionResult});
}