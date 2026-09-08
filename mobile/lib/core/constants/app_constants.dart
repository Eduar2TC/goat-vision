class AppConstants {
  AppConstants._();

  static const String appName = 'GoatVision';
  static const String appVersion = '1.0.0';
  static const String modelVersion = 'goat-weight-v1.0';
  static const String datasetVersion = 'goat-dataset-2026-09';

  static const double minConfidence = 0.6;
  static const double minDetectorConfidence = 0.7;
  static const double minLandmarkConfidence = 0.5;
  static const double minQualityScore = 0.5;

  static const double defaultMarkerRealWidthCm = 30.0;

  static const int maxImageWidth = 1280;
  static const int maxImageHeight = 960;

  static const double cameraFrameProcessIntervalMs = 200;
  static const int maxInferenceTimeMs = 500;

  static const double minGoatBodyLengthCm = 30.0;
  static const double maxGoatBodyLengthCm = 120.0;
  static const double minGoatWithersHeightCm = 30.0;
  static const double maxGoatWithersHeightCm = 90.0;

  static const int dbVersion = 1;
  static const String dbName = 'goatvision.sqlite';

  static const String goatDetectorModel = 'goat_detector.tflite';
  static const String goatSegmenterModel = 'goat_segmenter.tflite';
  static const String goatLandmarksModel = 'goat_landmarks.tflite';
  static const String goatWeightModel = 'goat_weight.tflite';
}
