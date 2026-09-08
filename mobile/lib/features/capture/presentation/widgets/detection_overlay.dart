import 'package:flutter/material.dart';

class DetectionOverlay extends CustomPainter {
  final List<Rect> boundingBoxes;
  final List<double> confidences;

  DetectionOverlay({
    required this.boundingBoxes,
    required this.confidences,
  });

  @override
  void paint(Canvas canvas, Size size) {
    for (int i = 0; i < boundingBoxes.length; i++) {
      final rect = _denormalize(boundingBoxes[i], size);
      final paint = Paint()
        ..color = const Color(0x33FFC107)
        ..style = PaintingStyle.fill;
      canvas.drawRect(rect, paint);

      final border = Paint()
        ..color = const Color(0xFFFFC107)
        ..style = PaintingStyle.stroke
        ..strokeWidth = 3;
      canvas.drawRect(rect, border);

      if (i < confidences.length) {
        final conf = confidences[i];
        final tp = TextPainter(
          text: TextSpan(
            text: 'Cabra ${(conf * 100).toStringAsFixed(0)}%',
            style: const TextStyle(
              color: Color(0xFFFFC107),
              fontSize: 12,
              fontWeight: FontWeight.bold,
              shadows: [Shadow(blurRadius: 3, color: Colors.black)],
            ),
          ),
          textDirection: TextDirection.ltr,
        )..layout();
        tp.paint(canvas, Offset(rect.left, rect.top - 18));
      }
    }
  }

  Rect _denormalize(Rect r, Size size) {
    return Rect.fromLTWH(
      r.left * size.width,
      r.top * size.height,
      r.width * size.width,
      r.height * size.height,
    );
  }

  @override
  bool shouldRepaint(covariant DetectionOverlay oldDelegate) =>
      oldDelegate.boundingBoxes != boundingBoxes ||
      oldDelegate.confidences != confidences;
}