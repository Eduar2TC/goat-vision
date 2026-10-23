import 'dart:convert';
import 'dart:io';
import 'dart:math' as math;
import 'dart:typed_data';

import 'package:apriltag/apriltag.dart';
import 'package:image/image.dart' as img;

/// PoC GoatVision — benchmark de corners/pose de AprilTag (FFI Dart) sobre
/// las escenas sintéticas generadas por tools/generate_scenes.py.
///
/// Corre: `dart run bin/run_apriltag.dart`
/// Escribe: results/apriltag_results.json  (un registro por escena + resumen)
Future<void> main() async {
  final root = Directory.current.path;
  final imagesDir = Directory('$root/images');
  final gtRaw = jsonDecode(File('${imagesDir.path}/ground_truth.json').readAsStringSync())
      as List<dynamic>;
  final groundTruth = gtRaw.cast<Map<String, dynamic>>();

  // La familia debe permanecer viva mientras el detector la usa:
  // apriltag_detector_add_family_bits NO copia la familia, y el finalizer de
  // la envoltura Dart puede liberarla si no queda referencia.
  final family = AprilTagFamily.tag36h11();
  final detector = AprilTagDetector.create(nThreads: 1)
    ..addFamily(family, bits: 1);

  final results = <Map<String, dynamic>>[];
  for (final gt in groundTruth) {
    final file = File('${imagesDir.path}/${gt['file'] as String}');
    final decoded = img.decodeImage(file.readAsBytesSync());
    if (decoded == null) {
      stderr.writeln('no se pudo decodificar ${gt['file']}');
      continue;
    }
    final w = decoded.width, h = decoded.height;
    final gray = Uint8List(w * h);
    for (int i = 0; i < gray.length; i++) {
      gray[i] = img.getLuminance(decoded.getPixel(i % w, i ~/ w)).toInt();
    }

    final sw = Stopwatch()..start();
    final dets = detector.detect(ImageU8.fromBuffer(gray, w, h));
    sw.stop();

    results.add(_evaluate(gt, dets, sw.elapsedMicroseconds / 1000.0));
  }

  final out = {'per_image': results, 'summary': _summarize(results)};
  File('$root/results/apriltag_results.json')
      .writeAsStringSync(const JsonEncoder.withIndent('  ').convert(out));
  print(jsonEncode(_summarize(results)));
  detector.dispose();
}

Map<String, dynamic> _evaluate(
  Map<String, dynamic> gt,
  ZArray dets,
  double elapsedMs,
) {
  Map<String, dynamic> best = {
    'name': gt['name'],
    'condition': gt['condition'],
    'detected': false,
    'elapsed_ms': elapsedMs,
  };
  final gtCorners = [
    for (final c in (gt['gt_corners_px'] as List))
      [(c as List)[0] as double, c[1] as double],
  ];
  final gtT = (gt['tvec'] as List).cast<double>();
  final K = [for (final r in (gt['K'] as List)) (r as List).cast<double>()];
  final fx = K[0][0], fy = K[1][1], cx = K[0][2], cy = K[1][2];
  final tagSize = gt['tag_side_m'] as double;

  for (int i = 0; i < dets.size; i++) {
    final det = dets.get(i);
    if (det.id != (gt['id'] as int)) continue;
    final corners = [
      for (final p in det.corners) [p.$1, p.$2],
    ];
    // correspondencia óptima por fuerza bruta (24 permutaciones de 4 esquinas)
    double bestCornerErr = double.infinity;
    for (final perm in _perms) {
      double s = 0;
      for (int j = 0; j < 4; j++) {
        final dx = corners[j][0] - gtCorners[perm[j]][0];
        final dy = corners[j][1] - gtCorners[perm[j]][1];
        s += math.sqrt(dx * dx + dy * dy);
      }
      if (s < bestCornerErr) bestCornerErr = s;
    }
    final meanCornerErr = bestCornerErr / 4.0;

    // pose: método propio del paquete (iteración ortogonal sobre homografía)
    final info = AprilTagDetectionInfo(
      det,
      tagSize: tagSize,
      fx: fx,
      fy: fy,
      cx: cx,
      cy: cy,
    );
    final (_, pose) = estimateTagPose(info);
    final candidate = {
      'name': gt['name'],
      'condition': gt['condition'],
      'detected': true,
      'elapsed_ms': elapsedMs,
      'hamming': det.hamming,
      'decision_margin': det.decisionMargin,
      'corner_err_px': meanCornerErr,
      'pose_t_err_m': _norm([
        pose.t.get(0, 0) - gtT[0],
        pose.t.get(1, 0) - gtT[1],
        pose.t.get(2, 0) - gtT[2],
      ]),
      'pose_rot_err_deg': _rotErrDeg(pose.R, (gt['rvec'] as List).cast<double>()),
    };
    if (best['detected'] != true ||
        (candidate['corner_err_px'] as double) <
            (best['corner_err_px'] as double)) {
      best = candidate;
    }
  }
  return best;
}

double _norm(List<double> v) =>
    math.sqrt(v.map((x) => x * x).reduce((a, b) => a + b));

/// error angular entre R (MatD 3x3) y un GT dado como rvec de Rodrigues.
///
/// Convención: el frame del tag de AprilTag es (x, y-up, z) mientras que el
/// GT usa ejes de imagen (x, y-down, z); la conversión es un flip de 180° en
/// ambos ejes de imagen, D = diag(-1, -1, 1), verificado empíricamente
/// (<1° residuo en condición clean). t no se ve afectado (posición del
/// centro del tag en cámara).
double _rotErrDeg(MatD R, List<double> rvec) {
  final Rg = _rotationFromRvec(rvec);
  const colSigns = [-1.0, -1.0, 1.0];
  // tr((R·D)·Rgᵀ) = Σ_ij vecinos_col[j]·R[i][j]·Rg[i][j]
  double tr = 0;
  for (int i = 0; i < 3; i++) {
    for (int j = 0; j < 3; j++) {
      tr += colSigns[j] * R.get(i, j) * Rg[i][j];
    }
  }
  final c = ((tr - 1) / 2).clamp(-1.0, 1.0);
  return math.acos(c) * 180.0 / math.pi;
}

/// Matriz de rotación R = I + sin(θ)·[k]× + (1-cos(θ))·[k]×²
List<List<double>> _rotationFromRvec(List<double> rvec) {
  final th = _norm(rvec);
  if (th < 1e-12) {
    return [
      [1, 0, 0],
      [0, 1, 0],
      [0, 0, 1],
    ];
  }
  final k = rvec.map((x) => x / th).toList();
  final Kx = [
    [0.0, -k[2], k[1]],
    [k[2], 0.0, -k[0]],
    [-k[1], k[0], 0.0],
  ];
  final s = math.sin(th);
  final c = 1 - math.cos(th);
  return [
    for (int i = 0; i < 3; i++)
      [
        for (int j = 0; j < 3; j++)
          (i == j ? 1.0 : 0.0) + s * Kx[i][j] + c * _square(Kx)[i][j],
      ],
  ];
}

List<List<double>> _square(List<List<double>> A) {
  return [
    for (int i = 0; i < 3; i++)
      [
        for (int j = 0; j < 3; j++)
          _dot(A[i], [A[0][j], A[1][j], A[2][j]]),
      ],
  ];
}

double _dot(List<double> a, List<double> b) {
  double s = 0;
  for (int i = 0; i < 3; i++) {
    s += a[i] * b[i];
  }
  return s;
}

const _perms = [
  [0, 1, 2, 3], [0, 1, 3, 2], [0, 2, 1, 3], [0, 2, 3, 1], [0, 3, 1, 2],
  [0, 3, 2, 1],
  [1, 0, 2, 3], [1, 0, 3, 2], [1, 2, 0, 3], [1, 2, 3, 0], [1, 3, 0, 2],
  [1, 3, 2, 0],
  [2, 0, 1, 3], [2, 0, 3, 1], [2, 1, 0, 3], [2, 1, 3, 0], [2, 3, 0, 1],
  [2, 3, 1, 0],
  [3, 0, 1, 2], [3, 0, 2, 1], [3, 1, 0, 2], [3, 1, 2, 0], [3, 2, 0, 1],
  [3, 2, 1, 0],
];

Map<String, dynamic> _summarize(List<Map<String, dynamic>> results) {
  final byCond = <String, List<Map<String, dynamic>>>{};
  for (final r in results) {
    byCond.putIfAbsent(r['condition'] as String, () => []).add(r);
  }
  return {
    'total_images': results.length,
    'overall_detection_rate':
        results.where((r) => r['detected'] == true).length / results.length,
    'conditions': {
      for (final e in byCond.entries)
        e.key: {
          'det_rate': e.value.where((r) => r['detected'] == true).length /
              e.value.length,
          'mean_corner_err_px': _meanOf(e.value, 'corner_err_px'),
          'mean_pose_t_err_m': _meanOf(e.value, 'pose_t_err_m'),
          'mean_pose_rot_err_deg': _meanOf(e.value, 'pose_rot_err_deg'),
          'mean_elapsed_ms': _meanOf(e.value, 'elapsed_ms'),
        },
    },
  };
}

double? _meanOf(List<Map<String, dynamic>> rows, String key) {
  final vals = rows
      .where((r) => r[key] is num)
      .map((r) => (r[key] as num).toDouble())
      .toList();
  if (vals.isEmpty) return null;
  return vals.reduce((a, b) => a + b) / vals.length;
}
