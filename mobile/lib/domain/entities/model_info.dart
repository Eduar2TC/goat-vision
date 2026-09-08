class ModelInfo {
  final String modelVersion;
  final String datasetVersion;
  final DateTime trainingDate;
  final String algorithm;
  final List<String> features;
  final Map<String, double> metrics;
  final Map<String, double>? featureImportance;
  final String? modelPath;

  const ModelInfo({
    required this.modelVersion,
    required this.datasetVersion,
    required this.trainingDate,
    required this.algorithm,
    required this.features,
    required this.metrics,
    this.featureImportance,
    this.modelPath,
  });

  double? get mae => metrics['mae'];
  double? get rmse => metrics['rmse'];
  double? get mape => metrics['mape'];
  double? get r2 => metrics['r2'];

  @override
  String toString() =>
      'ModelInfo(version: $modelVersion, algorithm: $algorithm)';
}
