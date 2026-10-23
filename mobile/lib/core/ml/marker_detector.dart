import 'dart:typed_data';

/// Servicio de detección de marcador fiducial en un frame.
///
/// Contrato compartido: recibe los bytes del frame (RGBA/BGRA 4 bytes/px
/// según lo entregue la cámara, o un canal único) con su dimensiones y
/// devuelve `(anchoPx, altoPx, confianza)` del marcador detectado.
/// El marcador físico es de 30x30 cm; la escala se deriva en
/// [MarkerCalibrationProvider] con la esquina ya proyectada.
///
/// Si no hay marcador detectable, devuelve `(0, 0, 0)` — sin lanzar:
/// al consumidor le toca tratar confianza 0 como "sin marcador".
abstract interface class MarkerDetectorService {
  Future<(double, double, double)> detectMarker(
    Uint8List imageBytes,
    int width,
    int height,
  );
}
