class LandmarkType {
  final String value;
  const LandmarkType._(this.value);

  static const head = LandmarkType._('HEAD');
  static const neck = LandmarkType._('NECK');
  static const withers = LandmarkType._('WITHERS');
  static const back = LandmarkType._('BACK');
  static const rump = LandmarkType._('RUMP');
  static const chest = LandmarkType._('CHEST');
  static const frontLeg = LandmarkType._('FRONT_LEG');
  static const hindLeg = LandmarkType._('HIND_LEG');
  static const hoof = LandmarkType._('HOOF');
  static const tailBase = LandmarkType._('TAIL_BASE');

  static const all = [
    head,
    neck,
    withers,
    back,
    rump,
    chest,
    frontLeg,
    hindLeg,
    hoof,
    tailBase,
  ];

  @override
  String toString() => value;
}

enum ViewType { side, rear, front, unknown }

class Landmark {
  final LandmarkType type;
  final double x;
  final double y;
  final double confidence;

  const Landmark({
    required this.type,
    required this.x,
    required this.y,
    required this.confidence,
  });

  Landmark copyWith({
    LandmarkType? type,
    double? x,
    double? y,
    double? confidence,
  }) {
    return Landmark(
      type: type ?? this.type,
      x: x ?? this.x,
      y: y ?? this.y,
      confidence: confidence ?? this.confidence,
    );
  }
}
