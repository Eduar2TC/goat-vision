import 'package:flutter_test/flutter_test.dart';
import 'package:goatvision/core/ml/reference_weight_predictor.dart';
import 'package:goatvision/domain/entities/morphometric_features.dart';

void main() {
  group('ReferenceWeightPredictor', () {
    test('ellipse girth reproduces the study mean (~84.97 cm)', () {
      final tg = ReferenceWeightPredictor()
          .estimateThoracicGirth(chestDepthCm: 34.0, chestWidthCm: 18.98);
      expect(tg, closeTo(84.97, 0.5));
    });

    test('predicts ~paper mean body weight for study means', () async {
      const features = MorphometricFeatures(
        bodyLengthCm: 0,
        withersHeightCm: 0,
        rumpHeightCm: 72.61,
        chestDepthCm: 34.0,
        chestWidthCm: 18.98,
        rumpWidthCm: 17.17,
        rumpLengthCm: 0,
        pawHeightCm: 0,
        bodyAreaCm2: 0,
        bodyAspectRatio: 1,
      );

      final prediction = await ReferenceWeightPredictor().predict(features);

      // Paper BW mean is 48.06 kg; formula gives ~46.9 (within published RSE).
      expect(prediction.estimatedWeightKg, closeTo(46.9, 1.5));
      expect(prediction.confidence, 0.644);
      expect(prediction.modelVersion, 'ref-paredes-chocce-2025');
    });

    test('interval is symmetric and positive around the estimate', () async {
      const features = MorphometricFeatures(
        bodyLengthCm: 0,
        withersHeightCm: 0,
        rumpHeightCm: 68.0,
        chestDepthCm: 31.0,
        chestWidthCm: 17.0,
        rumpWidthCm: 15.0,
        rumpLengthCm: 0,
        pawHeightCm: 0,
        bodyAreaCm2: 0,
        bodyAspectRatio: 1,
      );

      final prediction = await ReferenceWeightPredictor().predict(features);

      final half =
          (prediction.upperBoundKg - prediction.lowerBoundKg) / 2.0;
      expect(half, closeTo(1.2816 * 6.305, 0.001));
      expect(prediction.lowerBoundKg, greaterThan(0));
    });

    test('validateFeatures rejects non-positive and out-of-range inputs', () {
      final predictor = ReferenceWeightPredictor();

      expect(
        predictor.validateFeatures(
          _features(chestDepthCm: 0),
        ),
        isFalse,
      );
      expect(
        predictor.validateFeatures(
          _features(chestWidthCm: 30),
        ),
        isFalse,
      );
    });

    test('validateFeatures accepts study-range inputs', () {
      expect(
        ReferenceWeightPredictor().validateFeatures(
          _features(chestDepthCm: 34.0, chestWidthCm: 18.98),
        ),
        isTrue,
      );
    });
  });
}

MorphometricFeatures _features({
  double chestDepthCm = 24.0,
  double chestWidthCm = 15.0,
}) {
  return MorphometricFeatures(
    bodyLengthCm: 0,
    withersHeightCm: 0,
    rumpHeightCm: 60.0,
    chestDepthCm: chestDepthCm,
    chestWidthCm: chestWidthCm,
    rumpWidthCm: 12.0,
    rumpLengthCm: 0,
    pawHeightCm: 0,
    bodyAreaCm2: 0,
    bodyAspectRatio: 1,
  );
}