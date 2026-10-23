# Diseño — Plugin Android nativo de detección de marcadores (OpenCV ArUco)

> Fecha: 2026-10-21 · Rama: `poc/apriltag-ffi`
> Implementa el "Camino Android nativo" de la decisión en
> [docs/research/fiducial-markers.md](../research/fiducial-markers.md) (§Decisión, punto 2)
> y cubre el plan B descrito en
> [docs/research/aruco-apriltag-libraries.md](../research/aruco-apriltag-libraries.md).

## Contexto y decisión que esto implementa

La decisión de [docs/research/fiducial-markers.md](../research/fiducial-markers.md) fijó
un único formato de marcador imprimible (**tag36h11**, 30×30 cm) y dos caminos de
detección: FFI (`dartcv4`, ya integrado en `ArucoMarkerDetector`) y un plugin Android
nativo con OpenCV. Este documento diseña el segundo: es el plan B de producción si el
hook nativo de dartcv4 no estabiliza en CI Android, y a la vez el camino con las
**mejores esquinas sub-pixel** y mayor tolerancia a oclusión según el PoC
(error de esquina 0.30 px vs 0.72 px de AprilTag FFI; `occl_40`: 50% vs 0% detección).

Estado actual que este diseño respeta:

- Contrato común en [mobile/lib/core/ml/marker_detector.dart](../../mobile/lib/core/ml/marker_detector.dart):
  `detectMarker(bytes, w, h) → (wPx, hPx, confianza)`, `(0, 0, 0)` sin lanzar cuando
  no hay marcador.
- [ArucoMarkerDetector](../../mobile/lib/core/ml/aruco_marker_detector.dart) (FFI, dartcv4)
  ya reemplazó al mock en `RunMode.real` y está verificado contra el ground-truth del
  PoC (escena `clean_t1`, `side_px = 58.21`, < 3% de error).
- [capture_screen.dart](../../mobile/lib/features/capture/presentation/capture_screen.dart)
  consume `markerDetectorProvider` y trata confianza 0 como "sin marcador".
- Pendiente en la pantalla: los frames aún van con bytes vacíos (`Uint8List(0)`), así
  que el detector real siempre devuelve `(0,0,0)`; este diseño incluye el wiring real.

## Objetivos (v1)

1. Detectar tag36h11 en el dispositivo con OpenCV ArUco
   (`org.opencv.objdetect.ArucoDetector` del AAR oficial) **offline**, vía un
   plugin Flutter Android propio del monorepo.
2. Respetar el contrato de `MarkerDetectorService`: el provider conmuta mock → FFI →
   nativo sin tocar `CaptureScreen` ni las entidades.
3. Exponer el resultado enriquecido (id del marcador, 4 esquinas) como interfaz
   extendida, sin romper el contrato mínimo.
4. Consumir frames **sin abrir una segunda sesión de cámara**: el plugin `camera`
   sigue siendo el único propietario del `CameraDevice`.

## No objetivos (v1)

- **Modo residente de fondo** (EventChannel con frames del propio CameraX): exige
  acceso al `ImageProxy` nativo de `camera_android_camerax`, que no es API estable
  para plugins externos (ver "Frames de cámara" abajo). V1 no necesita streaming:
  la calibración es un flujo a demanda que se detiene en la primera detección
  con confianza suficiente.
- **Pose (`solvePnP`)**: queda para V2/V3; `cmPerPixel` solo necesita las 4 esquinas.
- **iOS/escritorio**: siguen con el detector FFI o el mock existentes.
- **AAR custom de OpenCV solo con `objdetect`**: tarea posterior si el peso del APK
  aprieta (hito H4).

## Estructura del paquete

```
mobile/packages/marker_detector/          # plugin federado del monorepo
├── pubspec.yaml                          # plugin: platforms [android]
├── lib/
│   ├── marker_detector.dart              # barrel: NativeMarkerDetector + Result
│   ├── marker_detection_result.dart      # resultado enriquecido (id, esquinas)
│   └── platform/marker_detector_api.dart # interfaz Pigeon (código generado)
├── pigeons/marker_detector.dart          # fuente Pigeon (el gen va commiteado)
├── android/
│   ├── build.gradle.kts                  # implementation "org.opencv:opencv:4.14.0"
│   └── src/main/kotlin/.../              # MarkerDetectorPlugin.kt, ArucoAdapter.kt
└── test/                                 # contrato Dart con API fake (host)
```

- El plugin es **dueño exclusivo de OpenCV y del canal**: la app nunca enlaza
  `org.opencv:opencv` directamente (una sola copia del objeto de OpenCV por proceso
  y un único punto de versión).
- `NativeMarkerDetector` implementa `MarkerDetectorService`, con lo que
  [providers.dart](../../mobile/lib/data/providers/providers.dart) añade el tercer
  brazo sin cambios en consumidores.

### Flujo de datos (v1)

```
[camera plugin] CameraImage (BGRA8888, ResolutionPreset.high)
 → Dart: suscripción a startImageStream con throttle (~200 ms) solo en captura
 → MethodChannel `goatvision/marker_detector.detect(bytes, w, h, rotation)`
 → Android: HandlerThread dedicado
     Mat(BGRA) → cvtColor a gris → rotación (0/90/180/270) → ArucoDetector
     (DICT_APRILTAG_36h11 + CORNER_REFINE_SUBPIX)
 → respuesta: MarkerDetection?id / esquinas / (wPx,hPx,confianza) → Dart
```

Se elige **detección a demanda enviando bytes por el canal** porque:

- El patrón de uso son 1-3 mediciones por segundo durante la calibración, y el
  loop se corta en la primera detección con confianza suficiente: el coste de
  serializar un frame BGRA (~1.5 MB a 720p) es asumible a esa cadencia.
- La detección en sí son 2-8 ms (PoC); el round-trip del canal domina y se
  queda en decenas de ms, muy por debajo de la cadencia de la UI.
- Evita el segundo consumidor nativo de la misma cámara y todo el problema de
  sesiones concurrentes de CameraX.

Alternativa descartada en v1: modo residente con su propio flujo ImageAnalysis;
requiere reimplementar la cámara fuera del plugin `camera` o un cambio upstream en
`camera_android_camerax`. Documentado como evolución (H4).

### Frames de cámara

- La única API pública del plugin `camera` para frames es
  `CameraController.startImageStream` (`CameraImage`), con
  `ImageFormatGroup.bgra8888` — el formato que ya asume
  [aruco_marker_detector.dart](../../mobile/lib/core/ml/aruco_marker_detector.dart)
  en la conversión a gris.
- El hook nativo `ImageAnalysis.Analyzer` de `camera_android_camerax` existe en su
  implementación pero no es una interfaz de cliente estable para plugins externos,
  por eso v1 no lo usa.
- **Rotación**: el `CameraImage` del streaming no expone `rotationDegrees`; los
  frames llegan en la orientación del sensor (típicamente 90° en cámara trasera).
  El canal incluye `rotation` (grados horarios) como parámetro y el lado Android
  aplica `cv.rotate`; la pantalla lo pasa desde el sensorOrientation de la cámara
  trasera elegida. Riesgo de prueba temprana en dispositivo real (H2).

### API por canal (Pigeon)

Contrato tipado generado con Pigeon (alternativa viable: MethodChannel a mano con
StandardMessageCodec; Pigeon solo evita inconsistencias de firma):

```pigeon
class MarkerDetection {
  /// id ArUco del marcador (tag36h11)
  int id;
  /// 8 doubles: x,y de TL,TR,BR,BL (orden canónico ArUco)
  List<double> corners;
  double widthPx;
  double heightPx;
  double confidence;
}

@HostApi()
abstract class MarkerDetectorApi {
  /// null = sin marcador. Nunca lanza por "no está": los errores de plataforma
  /// sí se propagan como PlatformException y el adaptador Dart los degrada.
  @async
  MarkerDetection? detect(Uint8List imageBytes, int width, int height,
                          int rotationDegrees);
  /// Libera el ArucoDetector nativo (invocado en dispose de la pantalla).
  void dispose();
}
```

Semántica compartida con el FFI (paridad deliberada):

- Dict `DICT_APRILTAG_36h11` y `CORNER_REFINE_SUBPIX` (método de refino 1).
- `widthPx`/`heightPx` = medias de lados opuestos del quad (TL,TR,BR,BL), igual
  que `_quadSides` del FFI.
- Confianza = misma fórmula del FFI: `0.9 − penalización(aspect ≠ 1, lado < 20 px)`,
  clampada a [0, 1]. Así el umbral de `CalibrationOverlay` y la calidad de
  `Calibration.confidence` no cambian de camino.

### Capas nativas

| Clase | Rol |
|---|---|
| `MarkerDetectorPlugin.kt` | registra el canal; cachea un `ArucoDetector` por engine; destruye en `onDetachedFromEngine` |
| `ArucoAdapter.kt` | todo lo que toca OpenCV (init lazy, Mat desde `byte[]`, cvtColor, rotación, confidence) — testeable con `androidTest` aislado |
| `NativeMarkerDetector` (Dart) | `implements MarkerDetectorService`; mapea `null → (0,0,0)` y `PlatformException → (0,0,0) + AppLogger.error` |
| `MockMarkerDetector` | permanece para `RunMode.mock` y tests widget (no FFI, no canal) |

### Trazado (hilo y ciclo de vida nativo)

- Un `HandlerThread` dedicado ("goatvision-marker"): OpenCV nunca corre en el hilo
  principal ni en el de la platform channel. Las peticiones del canal se despachan
  a ese thread y se responden con los `Result` de Pigeon.
- Un único `ArucoDetector` por engine (dict36h11 + subpixel): se crea en el primer
  `detect`, se destruye con `dispose()` o al desmontar el engine; el adaptador
  Dart puede llamarse de nuevo y el plugin lo re-crea perezosamente.
- No hay backpressure nativo: los awaits de Dart son serializados (un frame por
  vez) y el throttle en Dart (≈5 fps) evita cola si la UI desincroniza el flujo.

### Gradle / dependencia de OpenCV

En `packages/marker_detector/android/build.gradle.kts`:

```kotlin
dependencies {
    implementation("org.opencv:opencv:4.14.0")
}
```

- **Pin rama 4.x (4.14.0)**, no 5.0.0.1: el AAR 5.x pesa más (~153 MB vs ~123 MB en
  Maven Central — cifras del índice; el peso real en APK se verifica en H1) y el
  PoC ya detectó `SOLVEPNP_IPPE_SQUARE` roto en OpenCV 5.0. En 4.x ArUco está en
  `org.opencv.objdetect` (`ArucoDetector`, `Dictionary`) con el mismo dict36h11.
- `minSdk 24` de la app está por encima del requisito del AAR. ABIs de serie del
  AAR (armeabi-v7a, arm64-v8a, x86, x86_64) — suficiente; el recorte por ABI va
  vía App Bundle, no toca Gradle del plugin.
- CI: la dependencia es un binario precompilado (no compila fuente), así que el
  cache de Gradle basta — desaparece el problema del build hook de OpenCV desde
  fuentes que exige dartcv4 (~10-20 min).
- Motivo para aislado del plugin: si algún día hay que migrar o recortar versiones
  o añadir `OpenCVLoader` con init local, todo pasa por `ArucoAdapter.kt`.

### Integración en la app

[mobile/lib/data/providers/providers.dart](../../mobile/lib/data/providers/providers.dart):

```dart
final markerDetectorProvider = Provider<MarkerDetectorService>((ref) {
  final mode = ref.watch(runModeProvider);
  return switch (mode) {
    RunMode.mock => const MockMarkerDetector(),
    // v1: en Android la real es la vía nativa (plugin); iOS/escritorio siguen FFI
    RunMode.real when Platform.isAndroid => NativeMarkerDetector(),
    RunMode.real => ArucoMarkerDetector(),
  };
});
```

[mobile/lib/features/capture/presentation/capture_screen.dart](../../mobile/lib/features/capture/presentation/capture_screen.dart):

- Sustituye el flujo único actual (`_runMockAnalysis` con `Uint8List(0)`) por un
  `_startCalibrationLoop()`: `startImageStream` con `ImageFormatGroup.bgra8888`,
  throttle a ~200 ms, y el **primer resultado con confianza ≥ 0.5 y lado ≥ 25 px
  congela el loop** (se corta el stream) y fuerza `_qualityReady = true`; si no,
  sigue con `(0,0,0)` y la instrucción de encuadre marcada.
- El `dispose` de la pantalla corta el stream y llama a `NativeMarkerDetector.dispose()`
  (vía el canal al plugin) para liberar OpenCV nativo.
- La foto de alta resolución (`takePicture`) no cambia, ni el objeto `Calibration`
  (`method: 'marker'`, `cmPerPixel = 30 / wPx`), ni el flujo de análisis. La esquina
  de marcador de mayor confianza se pasa al overlay `CalibrationOverlay` para
  pintar el quad exacto (mejora directa del overlay que hoy NO pinta esquinas).

### Plan de pruebas

1. **Dart host (sin plataforma)**: `NativeMarkerDetector` con una `MarkerDetectorApi`
   fake — no lanza, devuelve `(0,0,0)` con `null` y con `PlatformException`, y mapea
   el resultado enriquecido. Paridad contractual con
   [marker_detector_test.dart](../../mobile/test/unit/marker_detector_test.dart).
2. **Instrumented (androidTest)**: fixtures del PoC (escena `clean_t1` con marcador
   real a 35°, y marcador 300 px con margen blanco de 120) como imágenes en
   `assets` del test; ground-truth `side_px = 58.21` (±5%) y detección única
   `id ≥ 0`. Con la misma fixture rotada 0/90/180/270 se valida el parámetro de
   **rotación** antes de tocar hardware.
3. **Paridad FFI vs nativo**: las mismas fixtures corriendo por
   `ArucoDetector.create(ArumoMarkerDetector)` (FFI en host) y por el plugin
   (instrumented): diferencia de esquinas < 1 px y de confianza < 0.05 — es la
   garantía de que la calibración (`method: 'marker'`) es agnóstica del camino.
4. **Manual en dispositivo**: marcador impreso de 30 cm, loop de calibración con
   marcador estático y en movimiento, y `adb logcat` limpio (sin excepciones
   JNI/UnsatisfiedLink). La UI debe pasar de "Marca el marcador de 30 cm" a "Lista
   para capturar".
5. **CI**: los tests Dart del host entran en la suite actual; los androidTest de
   instrumented quedan marcados como job opcional-emulador (mismo patrón que hoy
   en [.github/workflows/ci.yml](../../.github/workflows/ci.yml)).

### Hitos de ejecución

| Hito | Contenido | Éxito |
|---|---|---|
| H1 | Plugin (Dart+Pigeon+Kotlin) con OpenCV vía AAR; `detect` con fixture `clean_t1` en instrumented | androidTest pasa con GT ±5% |
| H2 | Wiring real de frames en `CaptureScreen` (throttle, stream, dispose) | calibración real en dispositivo con marcador impreso |
| H3 | `Calibration.confidence` ponderado con robustez de esquinas (métrica propuesta en fiducial-markers) | calidad de calibración reflejada en entidad |
| H4 (opcional) | AAR recortado a `objdetect` / re-evaluar hook de dartcv4 / modo residente | decisión peso vs latencia documentada |

## Riesgos abiertos

- **Rotación de frames** del `startImageStream`: `CameraImage` no expone
  `rotationDegrees`; se valida temprano en H2 con el test de rotaciones. Si
  hubieran valores erráticos por fabricante, se limita la captura a retrato
  (la pantalla de captura ya es retrato).
- **Peso del APK**: el AAR completo de OpenCV añade ~10-20 MB de nativos por ABI;
  con App Bundle se entrega por ABI. El recorte custom a `objdetect` queda H4 y
  necesitaría compilar OpenCV desde fuentes (wiki oficial de OpenCV, igual que
  el hook de dartcv4, con su propio cache de CI).
- **Segunda sesión de cámara**: v1 no abre `CameraDevice` propio (solo analiza los
  frames que entrega el plugin `camera`), así que el riesgo de sesiones
  concurrentes no aplica. Sí aplicaría en modo residente (H4), que implicaría
  reemplazar el plugin `camera` en la pantalla de captura.
- **Convivencia dartcv4 ↔ plugin**: cada uno carga su OpenCV en distinto mecanismo
  (native assets vs AAR); no comparten símbolos pero el AAR usa soname
  `libopencv_java4.so` y dartcv4 `libopencv.so` — sin colisión en la práctica;
  se verifica en H1. Si se adopta el plugin como camino de producción Android, se
  puede retirar el módulo `aruco` del hook de dartcv4 y encoger el build nativo.
- **Toolchain**: el plugin usa el mismo Gradle/Kotlin (2.2.20, AGP 8.2.2) ya
  presente en la app; sin riesgo adicional especial.

## Referencias

- Decisión previa y benchmark: [docs/research/fiducial-markers.md](../research/fiducial-markers.md)
- Panorama de librerías (AAR vs FFI, versiones 2026): [docs/research/aruco-apriltag-libraries.md](../research/aruco-apriltag-libraries.md)
- PoC reproducible (fixtures, imágenes y parches vendidos): [poc/apriltag_poc/README.md](../../../poc/apriltag_poc/README.md)
- Fuentes técnicas: [ArucoDetector Javadoc](https://docs.opencv.org/4.13.0/javadoc/org/opencv/objdetect/ArucoDetector.html),
  [Tutorial ArUco 4.13](https://docs.opencv.org/4.13.0/d5/dae/tutorial_aruco_detection.html),
  [AAR en Maven Central](https://repo.maven.apache.org/maven2/org/opencv/opencv/),
  [OpenCV Android en Maven](https://opencv.org/enhanced-opencv-for-android-support-arm-performance-gains/),
  [startImageStream (camera)](https://pub.dev/documentation/camera/latest/camera/CameraController/startImageStream.html),
  [camera_android_camerax](https://github.com/flutter/packages/tree/main/packages/camera/camera_android_camerax),
  [Rotación CameraX](https://developer.android.com/media/camera/camerax/orientation-rotation),
  [Backpressure CameraX](https://developer.android.com/media/camera/camerax/analyze),
  [Platform channels](https://docs.flutter.dev/platform-integration/platform-channels),
  [Pigeon](https://pub.dev/packages/pigeon).
