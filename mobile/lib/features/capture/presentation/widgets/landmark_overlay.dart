import 'package:flutter/material.dart';
import 'package:goatvision/domain/entities/landmark.dart';

class LandmarkOverlay extends CustomPainter {
  final List<Landmark> landmarks;

  const LandmarkOverlay({required this.landmarks});

  @override
  void paint(Canvas canvas, Size size) {
    for (final lm in landmarks) {
      final x = lm.x * size.width;
      final y = lm.y * size.height;

      final circle = Paint()
        ..color = const Color(0xFFFF9800)
        ..style = PaintingStyle.fill;
      canvas.drawCircle(Offset(x, y), 4, circle);

      final ring = Paint()
        ..color = const Color(0xFFFF5722)
        ..style = PaintingStyle.stroke
        ..strokeWidth = 2;
      canvas.drawCircle(Offset(x, y), 7, ring);
    }
  }

  @override
  bool shouldRepaint(covariant LandmarkOverlay oldDelegate) =>
      oldDelegate.landmarks != landmarks;
}