class Calibration {
  final double markerWidthPixels;
  final double markerHeightPixels;
  final double realWidthCm;
  final double cmPerPixel;
  final double confidence;
  final DateTime timestamp;

  /// Método con el que se obtuvo la calibración. Valores válidos: los
  /// `name` de [CalibrationProviderService] ('marker', 'manual',
  /// 'arcore', 'depth'). Se persiste tal cual en la tabla de capturas.
  final String method;

  const Calibration({
    required this.markerWidthPixels,
    required this.markerHeightPixels,
    required this.realWidthCm,
    required this.cmPerPixel,
    required this.confidence,
    required this.timestamp,
    required this.method,
  });

  double pixelsToCm(double pixels) => pixels * cmPerPixel;
  double cmToPixels(double cm) => cm / cmPerPixel;
}
