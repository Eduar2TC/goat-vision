import 'package:goatvision/domain/entities/morphometric_features.dart';
import 'package:goatvision/domain/entities/prediction.dart';
import 'package:goatvision/domain/entities/model_info.dart';

abstract class WeightPredictor {
  Future<Prediction> predict(MorphometricFeatures features);
  Future<ModelInfo> getModelInfo();
  Future<void> load();
  Future<void> unload();
  bool validateFeatures(MorphometricFeatures features, {List<String>? errors});
}

abstract class GoatDetector {
  Future<Object?> detect();

  Future<void> load();
  Future<void> unload();
}

abstract class GoatSegmenter {
  Future<Object?> segment();

  Future<void> load();
  Future<void> unload();
}

abstract class LandmarkDetector {
  Future<Object?> detectLandmarks();

  Future<void> load();
  Future<void> unload();
}

abstract class CalibrationProvider {
  Future<Object> calibrate();

  Future<void> load();
  Future<void> unload();
}