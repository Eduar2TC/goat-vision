import 'dart:math';
import 'package:goatvision/domain/entities/calibration.dart';
import 'package:goatvision/domain/entities/landmark.dart';
import 'package:goatvision/domain/entities/morphometric_features.dart';

class MorphometricCalculator {
  MorphometricCalculator._();

  static double _distance(Point<double> a, Point<double> b) {
    return sqrt(pow(b.dx - a.dx, 2) + pow(b.dy - a.dy, 2));
  }

  static Landmark? _get(List<Landmark> landmarks, LandmarkType type) {
    for (final l in landmarks) {
      if (l.type == type) return l;
    }
    return null;
  }

  static double _toCm(double pixelDistance, Calibration calibration) {
    return calibration.pixelsToCm(pixelDistance);
  }

  static MorphometricFeatures extract(
    List<Landmark> landmarks,
    Calibration calibration,
    double bodyAreaPixels,
  ) {
    final withers = _get(landmarks, LandmarkType.withers);
    final rump = _get(landmarks, LandmarkType.rump);
    final hoof = _get(landmarks, LandmarkType.hoof);
    final head = _get(landmarks, LandmarkType.head);
    final chest = _get(landmarks, LandmarkType.chest);
    final tail = _get(landmarks, LandmarkType.tailBase);
    final frontLeg = _get(landmarks, LandmarkType.frontLeg);
    final hindLeg = _get(landmarks, LandmarkType.hindLeg);

    double bodyLengthCm = 0;
    if (withers != null && tail != null) {
      bodyLengthCm = _toCm(_distance(_p(withers), _p(tail)), calibration);
    } else if (head != null && rump != null) {
      bodyLengthCm = _toCm(_distance(_p(head), _p(rump)), calibration);
    }

    double withersHeightCm = 0;
    if (withers != null && hoof != null) {
      withersHeightCm = _toCm(_distance(_p(withers), _p(hoof)), calibration);
    } else if (withers != null && frontLeg != null) {
      withersHeightCm = _toCm(_distance(_p(withers), _p(frontLeg)), calibration);
    }

    double rumpHeightCm = 0;
    if (rump != null && hoof != null) {
      rumpHeightCm = _toCm(_distance(_p(rump), _p(hoof)), calibration);
    } else if (rump != null && hindLeg != null) {
      rumpHeightCm = _toCm(_distance(_p(rump), _p(hindLeg)), calibration);
    }

    double chestDepthCm = 0;
    if (withers != null && chest != null) {
      chestDepthCm = _toCm(_distance(_p(withers), _p(chest)), calibration);
    }

    double rumpLengthCm = 0;
    if (withers != null && rump != null) {
      rumpLengthCm = _toCm(_distance(_p(withers), _p(rump)), calibration);
    }

    double chestWidthCm = 0;
    double rumpWidthCm = 0;

    if (bodyLengthCm > 0 && withersHeightCm > 0) {
      chestWidthCm = bodyLengthCm * 0.20;
      rumpWidthCm = bodyLengthCm * 0.12;
    }

    double pawHeightCm = 0;
    if (withersHeightCm > 0) {
      pawHeightCm = withersHeightCm * 0.22;
    }

    final bodyAreaCm2 = bodyAreaPixels > 0
        ? bodyAreaPixels * calibration.cmPerPixel * calibration.cmPerPixel
        : bodyLengthCm * withersHeightCm * 0.6;

    final aspectRatio = withersHeightCm > 0 && bodyLengthCm > 0
        ? bodyLengthCm / withersHeightCm
        : 1.0;

    return MorphometricFeatures(
      bodyLengthCm: bodyLengthCm,
      withersHeightCm: withersHeightCm,
      rumpHeightCm: rumpHeightCm,
      chestDepthCm: chestDepthCm,
      chestWidthCm: chestWidthCm,
      rumpWidthCm: rumpWidthCm,
      rumpLengthCm: rumpLengthCm,
      pawHeightCm: pawHeightCm,
      bodyAreaCm2: bodyAreaCm2,
      bodyAspectRatio: aspectRatio,
    );
  }

  static Point<double> _p(Landmark l) => Point(l.x, l.y);
}