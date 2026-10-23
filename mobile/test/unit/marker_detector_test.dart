import 'dart:math' as math;
import 'dart:typed_data';

import 'dart:io';

import 'package:flutter_test/flutter_test.dart';
import 'package:goatvision/core/ml/aruco_marker_detector.dart';
import 'package:opencv_dart/opencv.dart' as cv;

void main() {
  test(
    'ArucoMarkerDetector: bytes vacíos → (0, 0, 0) sin construir el detector FFI',
    () async {
      final detector = ArucoMarkerDetector();
      final r = await detector.detectMarker(Uint8List(0), 100, 100);
      expect(r, (0.0, 0.0, 0.0));
      detector.dispose();
    },
  );

  test(
    'ArucoMarkerDetector: bytes sin 1 ni 4 bytes por pixel → (0, 0, 0)',
    () async {
      final detector = ArucoMarkerDetector();
      final r = await detector.detectMarker(Uint8List(7), 2, 2); // 4 != 4 ni 16
      expect(r, (0.0, 0.0, 0.0));
      detector.dispose();
    },
  );

  test(
    'ArucoMarkerDetector FFI: detecta tag36h11 real en escena del PoC (GT side_px 58.21)',
    () async {
      // Fixture: escena limpia generada con AprilTag 3.4.5 (el mismo marcador
      // que imprime la app). GT en poc/apriltag_poc/images/ground_truth.json:
      // id=0, side_px=58.21, tag de 10 cm con K=750 fpx.
      final bytes = File('test/fixtures/tag36h11_clean_t1.png').readAsBytesSync();
      final mat = cv.imdecode(bytes, cv.IMREAD_GRAYSCALE);
      expect(mat.rows, greaterThan(0), reason: 'el fixture debe decodificar');
      final gray = Uint8List.fromList(mat.data);

      final detector = ArucoMarkerDetector();
      final (w, h, conf) = await detector.detectMarker(gray, mat.rows, mat.cols);
      detector.dispose();

      expect(w, greaterThan(0), reason: 'debe existir marcador en la escena');
      expect(conf, greaterThanOrEqualTo(0.5));
      expect(h / w, closeTo(1.0, 0.05));
      // Tolerancia del 5%: la base es el lado medio proyectado, la medición
      // del quad con tilt pequeño difiere algo (GT tilt residual del PoC).
      expect(w, closeTo(58.21, 58.21 * 0.05 + 1.5));
    },
  );


  test(
    'ArucoMarkerDetector FFI: escena sin marcador → (0, 0, 0)',
    () async {
      // Uniforme al 128 + algo de ruido determinista: nada que detectar.
      final rnd = math.Random(42);
      final bytes = Uint8List(400 * 400);
      for (var i = 0; i < bytes.length; i++) {
        bytes[i] = 128 + (rnd.nextDouble() < 0.02 ? (rnd.nextBool() ? 5 : -5) : 0);
      }

      final detector = ArucoMarkerDetector();
      final r = await detector.detectMarker(bytes, 400, 400);
      detector.dispose();

      expect(r, (0.0, 0.0, 0.0));
    },
  );
}
