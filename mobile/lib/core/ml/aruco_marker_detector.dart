import 'dart:math' as math;
import 'dart:typed_data';

import 'package:goatvision/core/ml/marker_detector.dart';
import 'package:goatvision/core/utils/app_logger.dart';
import 'package:opencv_dart/opencv.dart' as cv;

/// Detector real de marcadores fiduciales con OpenCV ArUco vía FFI
/// (`dartcv4`, módulo `aruco` habilitado por hook en pubspec).
///
/// Familia: tag36h11 (`DICT_APRILTAG_36h11`) — el mismo patrón del PoC
/// (docs/research/fiducial-markers.md) y el que OpenCV sirve de serie.
///
/// Contrato idéntico a `MockMarkerDetector`:
/// `(anchoPx, altoPx, confianza)`; `(0, 0, 0)` cuando no hay marcador.
class ArucoMarkerDetector implements MarkerDetectorService {
  ArucoMarkerDetector({this.realMarkerWidthCm = 30.0});

  final double realMarkerWidthCm;

  // Lazy: no tocar el FFI hasta el primer frame (el native asset se
  // construye por hook; en tests de widget que no usan el detector real
  // no hay coste).
  cv.ArucoDetector? _detector;

  cv.ArucoDetector get _det {
    _detector ??= cv.ArucoDetector.create(
      cv.ArucoDictionary.predefined(
        cv.PredefinedDictionaryType.DICT_APRILTAG_36h11,
      ),
      // CORNER_REFINE_SUBPIX = 1 (constante OpenCV; dartcv4 2.2.2 no la
      // exporta con nombre). Refino sub-pixel demostrado superior en el PoC.
      cv.ArucoDetectorParameters.empty()
        ..cornerRefinementMethod = 1,
    );
    return _detector!;
  }

  @override
  Future<(double, double, double)> detectMarker(
    Uint8List imageBytes,
    int width,
    int height,
  ) async {
    final gray = _buildGray(imageBytes, width, height);
    if (gray == null) return (0.0, 0.0, 0.0);

    try {
      final (corners, ids, _) = _det.detectMarkers(gray);
      final quad = _pickQuad(corners, ids);
      if (quad == null) return (0.0, 0.0, 0.0);

      final (wPx, hPx) = _quadSides(quad);
      final confidence = _confidence(quad);
      return (wPx, hPx, confidence);
    } catch (e) {
      AppLogger.instance.error('ArUco detectMarker failed', error: e);
      return (0.0, 0.0, 0.0);
    } finally {
      gray.dispose();
    }
  }

  /// Convierte los bytes del frame a un Mat CV_8UC1 propio.
  ///
  /// - 1 byte/px: ya es gris.
  /// - 4 bytes/px: ventana BGRA (convención de la cámara Android del
  ///   plugin `camera` con `ImageFormatGroup.bgra8888`).
  cv.Mat? _buildGray(Uint8List bytes, int width, int height) {
    if (width <= 0 || height <= 0 || bytes.isEmpty) return null;
    if (bytes.length == width * height) {
      return cv.Mat.fromList(width, height, cv.MatType.CV_8UC1, bytes);
    }
    if (bytes.length == width * height * 4) {
      final rgba = cv.Mat.fromList(width, height, cv.MatType.CV_8UC4, bytes);
      try {
        return cv.cvtColor(rgba, cv.COLOR_BGRA2GRAY);
      } finally {
        rgba.dispose();
      }
    }
    return null;
  }

  /// Primera detección válida (id ≥ 0 y quad de 4 esquinas).
  List<cv.Point2f>? _pickQuad(cv.VecVecPoint2f corners, cv.VecI32 ids) {
    for (int i = 0; i < corners.length; i++) {
      final id = ids[i];
      if (id < 0) continue;
      final quad = corners[i];
      if (quad.length == 4) return List<cv.Point2f>.from(quad);
    }
    return null;
  }

  /// (ancho, alto) del marcador en px medidos a partir del quad
  /// (orden canónico ArUco: TL,TR,BR,BL).
  (double, double) _quadSides(List<cv.Point2f> p) {
    final sideTop = _dist(p[0], p[1]);
    final sideRight = _dist(p[1], p[2]);
    final sideBottom = _dist(p[2], p[3]);
    final sideLeft = _dist(p[3], p[0]);
    final wPx = (sideTop + sideBottom) / 2.0;
    final hPx = (sideRight + sideLeft) / 2.0;
    return (wPx, hPx);
  }

  /// Confianza 0–1 con la misma razon que `MarkerCalibrationProvider`:
  /// penaliza la desviación del quad respecto de un cuadrado (perspectiva).
  double _confidence(List<cv.Point2f> p) {
    final (wPx, hPx) = _quadSides(p);
    if (wPx <= 0 || hPx <= 0) return 0;
    final aspect = hPx / wPx;
    var penalty = ((aspect - 1.0).abs() * 2.5).clamp(0.0, 0.5).toDouble();
    if (wPx < 20) penalty += 0.2; // demasiado pequeño para medir con rigor
    return (0.9 - penalty).clamp(0.0, 1.0).toDouble();
  }

  double _dist(cv.Point2f a, cv.Point2f b) =>
      math.sqrt((a.x - b.x) * (a.x - b.x) + (a.y - b.y) * (a.y - b.y));

  void dispose() {
    _detector?.dispose();
    _detector = null;
  }
}
