import 'dart:math';

class CoordinateTransformer {
  CoordinateTransformer._();

  static double normalizeX(double x, double imageWidth) {
    if (imageWidth <= 0) return 0;
    return x / imageWidth;
  }

  static double normalizeY(double y, double imageHeight) {
    if (imageHeight <= 0) return 0;
    return y / imageHeight;
  }

  static double denormalizeX(double nx, double imageWidth) => nx * imageWidth;
  static double denormalizeY(double ny, double imageHeight) => ny * imageHeight;

  static Offset normalizeOffset(double x, double y, double w, double h) =>
      Offset(normalizeX(x, w), normalizeY(y, h));

  static Rect denormalizeRect(
      double nx, double ny, double nw, double nh, double w, double h) {
    return Rect.fromLTWH(
      denormalizeX(nx, w),
      denormalizeY(ny, h),
      nw * w,
      nh * h,
    );
  }

  static Rect normalizeRect(
      double x, double y, double width, double height, double imgW, double imgH) {
    return Rect.fromLTWH(
      normalizeX(x, imgW),
      normalizeY(y, imgH),
      width / imgW,
      height / imgH,
    );
  }
}

class Offset {
  final double dx;
  final double dy;
  const Offset(this.dx, this.dy);
}

class Rect {
  final double left;
  final double top;
  final double width;
  final double height;
  const Rect.fromLTWH(this.left, this.top, this.width, this.height);
}