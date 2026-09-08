class Calibration {
  final double markerWidthPixels;
  final double markerHeightPixels;
  final double realWidthCm;
  final double cmPerPixel;
  final double confidence;
  final DateTime timestamp;

  const Calibration({
    required this.markerWidthPixels,
    required this.markerHeightPixels,
    required this.realWidthCm,
    required this.cmPerPixel,
    required this.confidence,
    required this.timestamp,
  });

  double pixelsToCm(double pixels) => pixels * cmPerPixel;
  double cmToPixels(double cm) => cm / cmPerPixel;
}
