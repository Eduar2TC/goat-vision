class MorphometricFeatures {
  final double bodyLengthCm;
  final double withersHeightCm;
  final double rumpHeightCm;
  final double chestDepthCm;
  final double chestWidthCm;
  final double rumpWidthCm;
  final double rumpLengthCm;
  final double pawHeightCm;
  final double bodyAreaCm2;
  final double bodyAspectRatio;

  const MorphometricFeatures({
    required this.bodyLengthCm,
    required this.withersHeightCm,
    required this.rumpHeightCm,
    required this.chestDepthCm,
    required this.chestWidthCm,
    required this.rumpWidthCm,
    required this.rumpLengthCm,
    required this.pawHeightCm,
    required this.bodyAreaCm2,
    required this.bodyAspectRatio,
  });

  Map<String, double> toMap() => {
        'body_length': bodyLengthCm,
        'withers_height': withersHeightCm,
        'rump_height': rumpHeightCm,
        'chest_depth': chestDepthCm,
        'chest_width': chestWidthCm,
        'rump_width': rumpWidthCm,
        'rump_length': rumpLengthCm,
        'paw_height': pawHeightCm,
      };

  List<double> toFeatureVector() => [
        bodyLengthCm,
        withersHeightCm,
        rumpHeightCm,
        chestDepthCm,
        chestWidthCm,
        rumpWidthCm,
        rumpLengthCm,
        pawHeightCm,
      ];

  MorphometricFeatures copyWith({
    double? bodyLengthCm,
    double? withersHeightCm,
    double? rumpHeightCm,
    double? chestDepthCm,
    double? chestWidthCm,
    double? rumpWidthCm,
    double? rumpLengthCm,
    double? pawHeightCm,
    double? bodyAreaCm2,
    double? bodyAspectRatio,
  }) {
    return MorphometricFeatures(
      bodyLengthCm: bodyLengthCm ?? this.bodyLengthCm,
      withersHeightCm: withersHeightCm ?? this.withersHeightCm,
      rumpHeightCm: rumpHeightCm ?? this.rumpHeightCm,
      chestDepthCm: chestDepthCm ?? this.chestDepthCm,
      chestWidthCm: chestWidthCm ?? this.chestWidthCm,
      rumpWidthCm: rumpWidthCm ?? this.rumpWidthCm,
      rumpLengthCm: rumpLengthCm ?? this.rumpLengthCm,
      pawHeightCm: pawHeightCm ?? this.pawHeightCm,
      bodyAreaCm2: bodyAreaCm2 ?? this.bodyAreaCm2,
      bodyAspectRatio: bodyAspectRatio ?? this.bodyAspectRatio,
    );
  }
}
