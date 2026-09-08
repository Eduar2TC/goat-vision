enum QualityIssue {
  goatNotDetected,
  goatPartiallyVisible,
  multipleGoats,
  lowLighting,
  lowSharpness,
  incorrectDistance,
  markerNotDetected,
  markerNotValid,
  invalidPose,
  occlusion,
  lowConfidence,
}

class QualityAssessment {
  final bool goatDetected;
  final bool bodyComplete;
  final bool goodLighting;
  final bool sufficientSharpness;
  final bool appropriateDistance;
  final bool validPose;
  final bool markerVisible;
  final bool markerValid;
  final bool notOccluded;
  final double detectorConfidence;
  final double overallScore;
  final List<QualityIssue> issues;

  const QualityAssessment({
    required this.goatDetected,
    required this.bodyComplete,
    required this.goodLighting,
    required this.sufficientSharpness,
    required this.appropriateDistance,
    required this.validPose,
    required this.markerVisible,
    required this.markerValid,
    required this.notOccluded,
    required this.detectorConfidence,
    required this.overallScore,
    required this.issues,
  });

  bool get isCaptureReady =>
      goatDetected &&
      bodyComplete &&
      goodLighting &&
      appropriateDistance &&
      validPose &&
      markerVisible &&
      markerValid &&
      detectorConfidence >= 0.7;

  List<String> get userInstructions {
    final instructions = <String>[];
    for (final issue in issues) {
      switch (issue) {
        case QualityIssue.goatNotDetected:
          instructions.add('No se detectó ninguna cabra. Coloca una cabra en el área de captura.');
          break;
        case QualityIssue.multipleGoats:
          instructions.add('Se detectaron varias cabras. Deja solamente una.');
          break;
        case QualityIssue.goatPartiallyVisible:
          instructions.add('El cuerpo completo debe estar visible.');
          break;
        case QualityIssue.lowLighting:
          instructions.add('Busca un lugar con mejor iluminación.');
          break;
        case QualityIssue.lowSharpness:
          instructions.add('Mantén el teléfono firme para obtener una imagen nítida.');
          break;
        case QualityIssue.incorrectDistance:
          instructions.add('Ajusta la distancia a la cabra.');
          break;
        case QualityIssue.markerNotDetected:
          instructions.add('Coloca el marcador junto a la cabra.');
          break;
        case QualityIssue.markerNotValid:
          instructions.add('Verifica que el marcador esté bien colocado y visible.');
          break;
        case QualityIssue.invalidPose:
          instructions.add('Coloca la cabra de perfil.');
          break;
        case QualityIssue.occlusion:
          instructions.add('Asegúrate de que no haya objetos obstruyendo la cabra.');
          break;
        case QualityIssue.lowConfidence:
          instructions.add('Intenta tomar otra fotografía.');
          break;
      }
    }
    return instructions;
  }
}
