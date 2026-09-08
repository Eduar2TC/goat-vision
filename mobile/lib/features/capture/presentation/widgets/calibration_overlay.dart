import 'package:flutter/material.dart';

class CalibrationOverlay extends CustomPainter {
  final bool markerDetected;
  final double? markerWidthPixels;
  final double? markerHeightPixels;

  const CalibrationOverlay({
    required this.markerDetected,
    this.markerWidthPixels,
    this.markerHeightPixels,
  });

  @override
  void paint(Canvas canvas, Size size) {
    if (!markerDetected || markerWidthPixels == null || markerHeightPixels == null) {
      _drawHint(canvas, size);
      return;
    }

    final w = markerWidthPixels! * size.width;
    final h = markerHeightPixels! * size.height;
    final x = size.width * 0.75 - w / 2;
    final y = size.height * 0.25 - h / 2;

    final rect = Rect.fromLTWH(x, y, w, h);
    final paint = Paint()
      ..color = Colors.greenAccent.withValues(alpha: 0.2)
      ..style = PaintingStyle.fill;
    canvas.drawRect(rect, paint);

    final border = Paint()
      ..color = Colors.greenAccent
      ..style = PaintingStyle.stroke
      ..strokeWidth = 2;
    canvas.drawRect(rect, border);

    final label = TextPainter(
      text: const TextSpan(
        text: 'MARCADOR',
        style: TextStyle(
          color: Colors.greenAccent,
          fontSize: 11,
          fontWeight: FontWeight.bold,
        ),
      ),
      textDirection: TextDirection.ltr,
    )..layout();
    label.paint(canvas, Offset(rect.left, rect.top - 16));
  }

  void _drawHint(Canvas canvas, Size size) {
    final x = size.width * 0.75 - 40;
    final y = size.height * 0.25 - 40;

    final paint = Paint()
      ..color = Colors.white.withValues(alpha: 0.15)
      ..style = PaintingStyle.fill;
    canvas.drawRRect(
      RRect.fromRectAndRadius(
        Rect.fromLTWH(x, y, 80, 80),
        const Radius.circular(8),
      ),
      paint,
    );

    final border = Paint()
      ..color = Colors.white.withValues(alpha: 0.6)
      ..style = PaintingStyle.stroke
      ..strokeWidth = 2;
    canvas.drawRRect(
      RRect.fromRectAndRadius(
        Rect.fromLTWH(x, y, 80, 80),
        const Radius.circular(8),
      ),
      border,
    );

    final label = TextPainter(
      text: const TextSpan(
        text: 'Coloca el marcador aquí',
        style: TextStyle(color: Colors.white, fontSize: 10),
      ),
      textDirection: TextDirection.ltr,
    )..layout();
    label.paint(
      canvas,
      Offset(x - 20, y + 84),
    );
  }

  @override
  bool shouldRepaint(covariant CalibrationOverlay oldDelegate) =>
      oldDelegate.markerDetected != markerDetected ||
      oldDelegate.markerWidthPixels != markerWidthPixels;
}