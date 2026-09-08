import 'dart:typed_data';
import 'package:goatvision/domain/entities/detection.dart';
import 'package:goatvision/domain/entities/landmark.dart';
import 'package:goatvision/domain/entities/model_info.dart';
import 'package:goatvision/domain/entities/morphometric_features.dart';
import 'package:goatvision/domain/entities/prediction.dart';

abstract interface class GoatDetectorService {
  Future<void> load();
  Future<void> unload();
  Future<List<Detection>> detect(Uint8List imageBytes, int width, int height);
  Future<ModelInfo> getModelInfo();
}

abstract interface class GoatSegmenterService {
  Future<void> load();
  Future<void> unload();
  Future<List<List<int>>> segment(
    Uint8List imageBytes,
    int width,
    int height,
    Detection detection,
  );
  Future<ModelInfo> getModelInfo();
}

abstract interface class LandmarkDetectorService {
  Future<void> load();
  Future<void> unload();
  Future<LandmarkDetectionResult> detectLandmarks(
    Uint8List imageBytes,
    int width,
    int height,
    Detection detection,
  );
  Future<ModelInfo> getModelInfo();
}

abstract interface class WeightPredictorService {
  Future<void> load();
  Future<void> unload();
  Future<Prediction> predict(MorphometricFeatures features);
  bool validateFeatures(MorphometricFeatures features,
      {List<String>? errors});
  Future<ModelInfo> getModelInfo();
}

abstract interface class ModelManager {
  Future<void> loadModels();
  Future<void> unloadModels();
  Future<ModelInfo> getModelVersion();
  Future<bool> validateModel();
  Future<Object> runInference(Object input);
  bool get isLoaded;
}