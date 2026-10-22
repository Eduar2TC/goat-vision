import 'package:goatvision/core/errors/app_exceptions.dart';
import 'package:goatvision/domain/entities/calibration.dart';

abstract interface class CalibrationProviderService {
  String get name;
  Future<Calibration> calibrate({
    required double markerWidthPixels,
    required double markerHeightPixels,
    required double realWidthCm,
  });
  bool validate(Calibration calibration);
}

class MarkerCalibrationProvider implements CalibrationProviderService {
  @override
  String get name => 'marker';

  @override
  Future<Calibration> calibrate({
    required double markerWidthPixels,
    required double markerHeightPixels,
    required double realWidthCm,
  }) async {
    if (markerWidthPixels <= 0) {
      throw const CalibrationError('markerWidthPixels must be positive');
    }
    if (realWidthCm <= 0) {
      throw const CalibrationError('realWidthCm must be positive');
    }

    final cmPerPixel = realWidthCm / markerWidthPixels;
    final aspectRatio = markerWidthPixels > 0
        ? markerHeightPixels / markerWidthPixels
        : 1.0;

    const idealAspectRatio = 1.0;
    // Penalty proportional to deviation from square, max 0.5 penalty
    final perspectivePenalty =
        ((aspectRatio - idealAspectRatio).abs() * 2.5).clamp(0.0, 0.5).toDouble();

    var confidence = 0.9 - perspectivePenalty;
    confidence = confidence.clamp(0.4, 1.0).toDouble();

    return Calibration(
      markerWidthPixels: markerWidthPixels,
      markerHeightPixels: markerHeightPixels,
      realWidthCm: realWidthCm,
      cmPerPixel: cmPerPixel,
      confidence: confidence,
      timestamp: DateTime.now(),
      // Método real usado: el nombre del propio proveedor ('marker').
      method: name,
    );
  }

  @override
  bool validate(Calibration calibration) {
    if (calibration.cmPerPixel <= 0) return false;
    if (calibration.confidence < 0.4) return false;

    final aspectRatio = calibration.markerHeightPixels > 0
        ? calibration.markerWidthPixels / calibration.markerHeightPixels
        : 0;
    if (aspectRatio == 0 || (aspectRatio - 1.0).abs() > 0.35) {
      return false;
    }
    return true;
  }
}

class ManualCalibrationProvider implements CalibrationProviderService {
  @override
  String get name => 'manual';

  @override
  Future<Calibration> calibrate({
    required double markerWidthPixels,
    required double markerHeightPixels,
    required double realWidthCm,
  }) async {
    if (markerWidthPixels <= 0 || realWidthCm <= 0) {
      throw const CalibrationError('invalid manual calibration values');
    }
    return Calibration(
      markerWidthPixels: markerWidthPixels,
      markerHeightPixels: markerHeightPixels,
      realWidthCm: realWidthCm,
      cmPerPixel: realWidthCm / markerWidthPixels,
      confidence: 0.8,
      timestamp: DateTime.now(),
      // Método real usado: el nombre del propio proveedor ('manual').
      method: name,
    );
  }

  @override
  bool validate(Calibration calibration) => calibration.cmPerPixel > 0;
}

class ArCoreCalibrationProvider implements CalibrationProviderService {
  @override
  String get name => 'arcore';

  @override
  Future<Calibration> calibrate({
    required double markerWidthPixels,
    required double markerHeightPixels,
    required double realWidthCm,
  }) {
    throw const CalibrationError('ARCore calibration not yet implemented');
  }

  @override
  bool validate(Calibration calibration) => false;
}

class DepthCalibrationProvider implements CalibrationProviderService {
  @override
  String get name => 'depth';

  @override
  Future<Calibration> calibrate({
    required double markerWidthPixels,
    required double markerHeightPixels,
    required double realWidthCm,
  }) {
    throw const CalibrationError('Depth calibration not yet implemented');
  }

  @override
  bool validate(Calibration calibration) => false;
}

class CalibrationRegistry {
  final Map<String, CalibrationProviderService> _providers;

  CalibrationRegistry(this._providers);

  CalibrationProviderService get(String name) {
    final provider = _providers[name];
    if (provider == null) {
      throw CalibrationError('Unknown calibration provider: $name');
    }
    return provider;
  }

  List<String> get availableProviders => _providers.keys.toList();

  factory CalibrationRegistry.defaultRegistry() {
    return CalibrationRegistry({
      'marker': MarkerCalibrationProvider(),
      'manual': ManualCalibrationProvider(),
    });
  }
}
