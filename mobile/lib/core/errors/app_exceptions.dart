import 'package:flutter/material.dart';
import 'package:goatvision/core/constants/app_colors.dart';

class AppExceptions implements Exception {
  final String message;
  final String? technicalMessage;
  final dynamic originalError;

  const AppExceptions({
    required this.message,
    this.technicalMessage,
    this.originalError,
  });

  @override
  String toString() => 'AppException: $message';
}

class CameraPermissionDenied extends AppExceptions {
  const CameraPermissionDenied()
      : super(
          message: 'Permiso de cámara denegado. Habilita el permiso en la configuración del dispositivo.',
          technicalMessage: 'Camera permission denied by user',
        );
}

class CameraInitializationError extends AppExceptions {
  const CameraInitializationError([String? detail])
      : super(
          message: 'Error al inicializar la cámara. Intenta de nuevo.',
          technicalMessage: 'Camera initialization failed: $detail',
        );
}

class ModelLoadError extends AppExceptions {
  const ModelLoadError(String modelName)
      : super(
          message: 'Error al cargar el modelo $modelName.',
          technicalMessage: 'Failed to load model: $modelName',
        );
}

class ModelInferenceError extends AppExceptions {
  const ModelInferenceError([String? detail])
      : super(
          message: 'Error durante la inferencia del modelo.',
          technicalMessage: 'Model inference error: $detail',
        );
}

class GoatNotDetected extends AppExceptions {
  const GoatNotDetected()
      : super(
          message: 'No se detectó ninguna cabra en la imagen.',
          technicalMessage: 'No goat detected in frame',
        );
}

class MultipleGoatsDetected extends AppExceptions {
  const MultipleGoatsDetected()
      : super(
          message: 'Se detectaron varias cabras. Deja solamente una dentro del área de captura.',
          technicalMessage: 'Multiple goats detected in frame',
        );
}

class GoatPartiallyVisible extends AppExceptions {
  const GoatPartiallyVisible()
      : super(
          message: 'El cuerpo completo debe estar visible.',
          technicalMessage: 'Goat partially outside frame',
        );
}

class LowImageQuality extends AppExceptions {
  const LowImageQuality([String? reason])
      : super(
          message: reason ?? 'Calidad de imagen insuficiente. Busca un lugar con mejor iluminación.',
          technicalMessage: 'Low image quality: $reason',
        );
}

class MarkerNotDetected extends AppExceptions {
  const MarkerNotDetected()
      : super(
          message: 'Coloca el marcador junto a la cabra.',
          technicalMessage: 'Calibration marker not detected',
        );
}

class InvalidPose extends AppExceptions {
  const InvalidPose()
      : super(
          message: 'Coloca la cabra de perfil para una mejor estimación.',
          technicalMessage: 'Goat pose is not valid for estimation',
        );
}

class CalibrationError extends AppExceptions {
  const CalibrationError([String? detail])
      : super(
          message: 'Error en la calibración. Verifica que el marcador esté visible y bien colocado.',
          technicalMessage: 'Calibration error: $detail',
        );
}

class InsufficientConfidence extends AppExceptions {
  const InsufficientConfidence()
      : super(
          message: 'Confianza insuficiente. Intenta tomar otra fotografía más clara.',
          technicalMessage: 'Confidence below threshold',
        );
}

class PredictionError extends AppExceptions {
  const PredictionError([String? detail])
      : super(
          message: 'No se puede realizar una estimación confiable con esta captura.',
          technicalMessage: 'Prediction error: $detail',
        );
}

class StorageError extends AppExceptions {
  const StorageError([String? detail])
      : super(
          message: 'Error al guardar los datos.',
          technicalMessage: 'Storage error: $detail',
        );
}
