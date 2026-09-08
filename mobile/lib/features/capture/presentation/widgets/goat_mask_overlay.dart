import 'package:flutter/material.dart';

class GoatMaskOverlay extends CustomPainter {
  final List<List<bool>>? mask;
  final int maskWidth;
  final int maskHeight;

  const GoatMaskOverlay({
    this.mask,
    required this.maskWidth,
    required this.maskHeight,
  });

  @override
  void paint(Canvas canvas, Size size) {
    if (mask == null) return;
    if (maskWidth <= 0 || maskHeight <= 0) return;

    final scaleX = size.width / maskWidth;
    final scaleY = size.height / maskHeight;

    final paint = Paint()
      ..color = const Color(0x552E7D32)
      ..style = PaintingStyle.fill;

    final borderPaint = Paint()
      ..color = const Color(0xCC2E7D32)
      ..style = PaintingStyle.stroke
      ..strokeWidth = 2;

    final stepX = scaleX > 2 ? 2 : 1;
    final stepY = scaleY > 2 ? 2 : 1;

    for (int y = 0; y < maskHeight; y += stepY) {
      for (int x = 0; x < maskWidth; x += stepX) {
        if (mask[y][x]) {
          canvas.drawRect(
            Rect.fromLTWH(
              x * scaleX,
              y * scaleY,
              scaleX * stepX,
              scaleY * stepY,
            ),
            paint,
          );
        }
      }
    }
  }

  @override
  bool shouldRepaint(covariant GoatMaskOverlay oldDelegate) =>
      oldDelegate.mask != mask;
}