class Prediction {
  final double estimatedWeightKg;
  final double lowerBoundKg;
  final double upperBoundKg;
  final double confidence;
  final String modelVersion;

  const Prediction({
    required this.estimatedWeightKg,
    required this.lowerBoundKg,
    required this.upperBoundKg,
    required this.confidence,
    required this.modelVersion,
  });

  String get formattedWeight {
    if (estimatedWeightKg >= 100) {
      return estimatedWeightKg.toStringAsFixed(0);
    }
    return estimatedWeightKg.toStringAsFixed(1);
  }

  String get formattedRange =>
      '${lowerBoundKg.toStringAsFixed(1)}–${upperBoundKg.toStringAsFixed(1)} kg';

  String get formattedConfidence =>
      '${(confidence * 100).toStringAsFixed(0)} %';

  String get displayWeight => '≈ $formattedWeight kg';
}
