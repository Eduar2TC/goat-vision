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
        'body_length_cm': bodyLengthCm,
        'withers_height_cm': withersHeightCm,
        'rump_height_cm': rumpHeightCm,
        'chest_depth_cm': chestDepthCm,
        'chest_width_cm': chestWidthCm,
        'rump_width_cm': rumpWidthCm,
        'rump_length_cm': rumpLengthCm,
        'paw_height_cm': pawHeightCm,
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
