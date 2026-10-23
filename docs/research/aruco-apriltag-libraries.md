# Librerías Flutter de detección ArUco/AprilTag offline — estado y elección

> Fecha: 2026-10-20 · Rama: `poc/apriltag-ffi`
> Investigación previa con benchmark experimental: [fiducial-markers.md](fiducial-markers.md)
> y PoC reproducible: [poc/apriltag_poc/README.md](../../poc/apriltag_poc/README.md)

## Contexto

El pipeline de calibración por marcador (30 cm, tag36h11, `Calibration.method = 'marker'`)
necesita un detector **offline en el dispositivo** para sustituir `MockMarkerDetector`.
Este informe recoge el panorama de librerías a octubre 2026 (búsqueda web nueva
sobre los mismos criterios del benchmark del PoC) y el estado de la integración
que ya está en curso en la app.

## Panorama (pub.dev, octubre 2026)

| Opción | Última versión | Mecanismo | Estado / riesgo |
|---|---:|---|---|
| **`dartcv4` 2.3.1** (rainyl) | 2.3.1 | FFI + native assets (hook CMake que compila OpenCV 4.13 desde fuente) | Activo; 2.3.1 arregla dependencias transitivas de módulos CMake y detecta selección de módulos en conflicto |
| **`opencv_dart` 2.2.2** | 2.2.2 | wrapper Flutter sobre `dartcv4` | Activo; en 2.x es solo un wrapper de conveniencia — el motor y los hooks son de `dartcv4` |
| `apriltag` (rainyl) | 0.0.2 | native assets, C vendido 3.4.5 | Joven (2 versiones); aún requiere vendor de nuestros 2 parches del PoC (symlink native asset + use-after-free en `estimateTagPose`) |
| `flutter_aruco_detector` | 0.0.2 (~3 años) | plugin Android/iOS | Abandonado: repo 404, ~33 descargas en total |
| `augen` | 1.5.0 | arcore/ar | ArUco solo "planeado", no implementado |
| `org.opencv:opencv` (Maven Central) | 5.0.0.1 | plugin Android nativo vía MethodChannel | Ruta estable oficial; `org.opencv.aruco` documentado en javadoc; requiere escribir el plugin |
| `opencv-mobile` (nihui) | — | prebuilt Android mínimo | **Sin objdetect/aruco**: para ArUco habría que compilar una OpenCV custom → pierde su valor |

Verificación por cambio de versión relevante:

- **2.2.0 elimina el binario prebuilt** (4.12.0 fue la última versión con binario
  estático precompilado): desde 2.2.x el hook **compila OpenCV desde fuente**
  con CMake. Implicación: primera build lenta (~10-20 min host) y CI necesita
  caché de la build nativa.
- **2.2.1+4**: fix "Aruco was not built correctly after changing include_modules".
- **2.2.2**: fixes de rutas contrib y de "ensuring aruco builds with required deps".
- **2.3.1**: resuelve **dependencias transitivas CMake de módulos** y reporta
  selecciones de módulos en conflicto — esto coincide exactamente con el
  fallo `Building native assets failed` que teníamos con 2.2.2 +
  `include_modules: [imgcodecs, imgproc, aruco]`.
- Issue [#423](https://github.com/rainyl/opencv_dart/issues/423): header OpenCV
  faltante tras cambiar módulos → era problema de cache/config de CMake, cerrado con fix.
  Los fallos del hook son configurables/corregibles, no ficción inevitable.

Api doc: OpenCV 4.13 (la que usa dartcv4) mantiene `ArucoDetector` +
`DICT_APRILTAG_36h11` en el módulo `objdetect` (impl `aruco` contrib) — es
 decir, la familia de marcador del PoC sigue soportada de serie sin cambiar
de librería.

## Recomendación de integración por orden

1. **`opencv_dart` + `dartcv4` (FFI, módulos imgcodecs+imgproc+aruco)** — elegido.
   API directa y offline, detector real multiplataforma sin escribir plugin Android,
   y los bugs de build de aruco tienen fixes redistribibles (2.3.1). Benchmark
   experimental del PoC: las mismas esquinas sub-pixel del ArUco de OpenCV
   (error 0.30 px vs 0.72 px de AprilTag) y mejor tolerancia a oclusión, con
   detección empatada.
2. **Plugin Android con AAR oficial** (`org.opencv:opencv` Maven) — plan B
   de producción si el hook de dartcv4 acaba siendo inestable desde fuente en
   CI Android. Requiere el plugin propio y gestión de frames de cámara manual.
   Se mantiene abierto el modelo nativo residente descrito en
   fiducial-markers.md.
3. **`apriltag` 0.0.2 FFI** — solo PoC/CLI; reportar upstream los 2 bugs y
   esperar madurez del paquete (pendiente, ver parches vendored del PoC).

## Estado de la sustitución del mock (en curso, rama `poc/apriltag-ffi`)

- `mobile/pubspec.yaml`: `sdk: ^3.10.0`, `flutter: >=3.38.1`,
  `opencv_dart: ^2.2.2` y (nuevo) **`dartcv4: ^2.3.1`** directo con el fix
  de deps transitivas; `hooks.user_defines.dartcv4.include_modules:
  [imgcodecs, imgproc, aruco]` (los defaults ya se re-listan porque
  `include_modules` **reemplaza** la lista por defecto).
- `mobile/lib/core/ml/marker_detector.dart`: interfaz compartida
  `MarkerDetectorService` con el contrato del mock
  (`(anchoPx, altoPx, confianza)`, `(0,0,0)` si no hay marcador).
- `mobile/lib/core/ml/aruco_marker_detector.dart`: `ArucoMarkerDetector`
  real vía FFI — lazy (no construye el FFI hasta el primer frame),
  `DICT_APRILTAG_36h11`, `CORNER_REFINE_SUBPIX` (constante 1, dartcv4 no la
  exporta con nombre), conversión BGRA→gris con `cvtColor`, `gray.dispose()`
  en `finally`, try/catch que degrada a `(0,0,0)` sin lanzar (contrato del mock).
- `mobile/lib/data/providers/providers.dart`: `markerDetectorProvider`
  conmutado por `RunMode` — `real → ArucoMarkerDetector`, `mock → MockMarkerDetector`.
- `mobile/lib/features/capture/presentation/capture_screen.dart`: ya consume
  el provider y trata confianza 0 como "sin marcador".
- `mobile/test/unit/marker_detector_test.dart`: 2 tests del contrato de
  degradación (bytes vacíos / bytes que no son 1 ni 4 bytes por píxel).

## Hallazgo de la depuración: bug de `generateImageMarker` con dict AprilTag (dartcv4 2.3.1 / OpenCV 4.13)

La verificación end-to-end del detector reveló que `ArucoDictionary.generateImageMarker`
con `DICT_APRILTAG_36h11` en este build produce un **patrón desplazado/traslado** respecto
al marcador idéntico de cv2 5.0: comparación pixel a pixel id5 → 17.794 px distintos de
90.000 y la grilla de celdas visiblemente corrida. Consecuencias medidas:

- El marcador autogenerado por dartcv4 no se auto-detecta ni en dartcv4 ni en cv2 5.0
  (rejected=3/4). El dict es auto-consistente (`getDistanceToId = 0`), pero el
  *layout* del marcador no coincide con el que identifica la detección.
- La **detección de marcadores tag36h11 reales** (generados con AprilTag 3.4.5, como
  las escenas del PoC) sí funciona vía FFI: escena `clean_t1` → medición cuadrada
  `(57.5, 58.7, conf 0.85)` con GT `side_px=58.21` (< 3% de error), y control
  `DICT_4X4_50` autogenerado con margen → `n=1 ids=[1]`.
- En builds modernos de OpenCV (4.13/5.0) el marcador **standalone** que llena toda
  la imagen tampoco se identifica: necesita **margen blanco alrededor** (las escenas
  del PoC lo tienen de serie). En fotos reales de cámara casi siempre hay margen;
  para bancos de test, componer con `copyMakeBorder` blanca.

Implicación práctica: el marcador imprimible del producto **no debe generarse** con
`generateImageMarker` de dartcv4 (usar AprilTag 3.4.5 / cv2, el camino del PoC), pero
el detector FFI es válido para el patrón real. Bug reportable upstream (dartcv4 u
OpenCV 4.13); reproducibles en `mobile/test/unit/marker_detector_test.dart`.

## Riesgos abiertos

- **Build nativo**: OpenCV se compila desde fuente (sin binarios prebuilt
  desde dartcv4 2.2.0): la primera compilación es lenta (~10-20 min en host)
  y en CI hay que cachear el build hook (`.dart_tool`, `_deps`).
  Pendiente re-verificar con 2.3.1 (fix de dependencias transitivas).
- **API**: `dartcv4` está marcado WIP en el repo; se pinnean versiones exactas
  y se verifica con los tests del contrato del detector y `flutter analyze`.
- `MockMarkerDetector` se mantiene para `RunMode.mock` y para los tests de
  widget existentes que no ejercitan el FFI.

Fuentes principales investigadas: [dartcv4](https://pub.dev/packages/dartcv4),
[changelog dartcv4](https://pub.dev/packages/dartcv4/changelog),
[opencv_dart](https://pub.dev/packages/opencv_dart),
[changelog opencv_dart](https://pub.dev/packages/opencv_dart/changelog),
[issue #423](https://github.com/rainyl/opencv_dart/issues/423),
[issue #405](https://github.com/rainyl/opencv_dart/issues/405),
[OpenCV ArUco 4.13](https://docs.opencv.org/4.13.0/d5/dae/tutorial_aruco_detection.html),
[apriltag en pub.dev](https://pub.dev/packages/apriltag),
[repo apriltag.dart](https://github.com/rainyl/apriltag.dart),
[flutter_aruco_detector](https://pub.dev/packages/flutter_aruco_detector),
[augen](https://pub.dev/packages/augen),
[OpenCV Android](https://opencv.org/opencv4android-usage-models/),
[Maven opencv](https://central.sonatype.com/artifact/org.opencv/opencv),
[javadoc org.opencv.aruco](https://docs.opencv.org/4.13.0/javadoc/org/opencv/aruco/Aruco.html),
[opencv-mobile](https://github.com/nihui/opencv-mobile).
