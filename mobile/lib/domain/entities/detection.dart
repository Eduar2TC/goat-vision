import 'package:goatvision/domain/entities/landmark.dart';

class Detection {
  final double x;
  final double y;
  final double width;
  final double height;
  final double confidence;

  const Detection({
    required this.x,
    required this.y,
    required this.width,
    required this.height,
    required this.confidence,
  });

  double get centerX => x + width / 2;
  double get centerY => y + height / 2;
  double get area => width * height;
  double get aspectRatio => width / height;
}

class SegmentationResult {
  final List<List<int>> mask;
  final int width;
  final int height;
  final double confidence;
  final List<List<int>> contour;

  const SegmentationResult({
    required this.mask,
    required this.width,
    required this.height,
    required this.confidence,
    required this.contour,
  });

  double get bodyArea {
    int count = 0;
    for (final row in mask) {
      for (final pixel in row) {
        if (pixel > 0) count++;
      }
    }
    return count.toDouble();
  }
}

class LandmarkDetectionResult {
  final List<Landmark> landmarks;
  final double overallConfidence;

  const LandmarkDetectionResult({
    required this.landmarks,
    required this.overallConfidence,
  });

  Landmark? getLandmark(LandmarkType type) {
    try {
      return landmarks.firstWhere((l) => l.type == type);
    } catch (_) {
      return null;
    }
  }
}
