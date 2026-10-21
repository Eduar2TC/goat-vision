# Marcadores fiduciales: comparativa y decisión (GoatVision)

> Fecha: 2026-10-19 · Rama PoC: `poc/apriltag-ffi`
> PoC reproducible: [poc/apriltag_poc/](../../poc/apriltag_poc/README.md)

## Contexto

La calibración por marcador físico (30 cm) ya está soportada en el pipeline
de la app (campo `Calibration.method = 'marker'`) y necesita detectar el
marcador en la escena
para calcular `cmPerPixel` y (futuro) pose. Hoy la app usa un mock
(`MockMarkerDetector`). Esta nota decide qué biblioteca usar en Android
para los hitos de calibración.

## Familia de marcador: tag36h11

- Es la familia clásica de AprilTag y **OpenCV la lee con
  `DICT_APRILTAG_36H11`**, lo que permite comparar bibliotecas sobre las
  mismas imágenes y mantener un formato de marcador imprimible único.
- Alternativa clásica ArUco 4x4/5x5/6x6: más "OpenCV nativo" pero sin
  equivalente directo en bibliotecas FFI de Dart.

## Comparativa de paquetes Dart (FFI)

| Paquete | Estado | Mecanismo | Observaciones |
|---|---|---|---|
| **`apriltag` 0.0.2** (rainyl) | Existe en pub.dev, poco usado, en desarrollo activo (fixes de pose y async en 2026) | **native assets** (hook CMake+Ninja, C vendido 3.4.5) | 2 bugs encontrados en el PoC (ver abajo). API directa: `Detection` con esquinas, `estimateTagPose` con intrínsecas |
| `libapriltag` sistema (Ubuntu 22.04: 3.2.0 / 24.04: 3.3.0) | Estable, mantenido por Ubuntu | binding a mano sobre `DynamicLibrary.open` | Requiere escribir bindings FFI propios; el hook del paquete `apriltag` no enlaza contra la librería del sistema |
| ArUco nativo (OpenCV Android) | Estable | JNI/plugin | Peso de OpenCV móvil grande; ningún wrapper Dart FFI publicado |
| `dartfiducial`/otros | No existen wrappers Dart publicados | — | (resultado de búsqueda, no prueba absoluta) |

### Bugs encontrados en `apriltag` 0.0.2 (PoC, fuentes parcheadas)

1. **Native asset no se registra**: el hook corre CMake OK, pero CMake instala
   `libapriltag.so` como *symlink* y `findCodeAssets` del
   `native_toolchain_cmake` recorre con `followLinks:false` + `entity is! File`
   → nunca lo ve; el asset id queda vacío y el FFI busca el símbolo en el
   proceso. Parcheado en el paquete vendido (`regExp` + archivo versionado).
2. **Use-after-free en pose**: `estimateTagPose`/`estimatePoseForTagHomography`
   devuelven un `MatD` que envuelve memoria del heap de C y el wrapper llama
   `matd_destroy` antes de devolver → pose basura (e+107) y segfault en un
   caso. Parcheado con `copy()` antes de `pose.dispose()`.

Ambos son fácilmente reportables upstream; mientras tanto el paquete va
**vendorizado** en el PoC (`third_party/apriltag_pkg`) con los 2 parches
documentados en los archivos.

## Resultados del PoC (56 escenas sintéticas, tag 10 cm, tag36h11)

Comparativa AprilTag (FFI Dart, `estimateTagPose`) vs OpenCV ArUco
(`DICT_APRILTAG_36H11`, refino sub-pixel, `solvePnP`), sobre exactamente las
mismas 56 escenas degradadas (ruido σ20/35, blur 5/9, tilt 20°/35°, distancia
hasta lado=25 px, oclusión 25/40%, JPEG q20/q10, combinada). Detalle en
[poc/apriltag_poc/README.md](../../poc/apriltag_poc/README.md).

| Condición | det AT | det ArUco | corner AT | corner ArUco | t AT | t ArUco | rot AT | rot ArUco |
|---|---|---|---|---|---|---|---|---|
| clean | 100% | 100% | 0.72 px | **0.30 px** | 3 mm | 5 mm | 4.5° | 5.2° |
| noise_35 | 100% | 100% | 0.77 | 0.88 | 5 mm | 19 mm | 8.1° | 17.0° |
| blur_9 | 100% | 100% | 0.74 | 0.61 | 11 mm | 22 mm | 3.3° | 12.8° |
| occl_25 | 100% | 100% | 0.71 | 0.44 | 5 mm | 12 mm | 1.4° | 11.2° |
| occl_40 | **0%** | **50%** | — | 0.58 | — | 3 mm | — | 4.2° |
| dist_far (lado≈25 px) | 100% | 100% | 0.73 | 0.42 | 26 mm | 12 mm | 5.3° | 13.8° |
| jpeg_20 | 100% | 100% | 0.72 | 0.47 | 7 mm | 9 mm | 2.1° | 4.7° |
| combined | 100% | 100% | 0.71 | 0.53 | 6 mm | 18 mm | 1.4° | 5.1° |

(tabla completa: `tools/aruco_baseline.py banner` en el PoC)

Lecturas honestas:

- **Ambos fallan igual de raramente en detección** en casi todas las
  condiciones; el fallo real con uno solo marcador es oclusión central fuerte.
- **Esquinas: ArUco sub-pixel es constantemente mejor** (la mitad de error);
  AprilTag no hace refino subpixel equivalente.
- **Pose: traducción mejor en AprilTag en varias condiciones** hasta ~3 m de
  distancia; rotación comparable en general. `SOLVEPNP_IPPE_SQUARE` de
  cv2 5.0 está roto (reproj ~6812 px); en 4.x puede comportarse distinto.
- Latencia solo orientativa (Dart JIT vs C++): AprilTag 5–15 ms; ArUco 2–8 ms.

## Decisión

**Para calibración por marcador (hitos corto plazo de la app):**

1. **Mantener el marcador tag36h11 actual** como tipo de marcador único e
   imprimible, para compatibilidad con los dos caminos.
2. **Camino Android nativo: ArUco (OpenCV) residente nativo o plugin** cuando
   se integre detección real: mejor esquinas sub-pixel y mejor tolerancia a
   oclusión; el pipeline Android ya puede convivir con OpenCV vía plugin.
   Para `cmPerPixel` basta medir 4 esquinas.
3. **Camino Dart FFI (apriltag 0.0.2)**: viable para PoC/experimentación
   (script CLI, datasets) PERO no es producción-ready todavía: native
   assets en Flutter móvil por hooks CMake requiere validar en Android
   (ABI/cmake toolchain); los 2 bugs están solo corregidos en el vendor
   local, no upstream.
   Recomendación: reportar los 2 bugs upstream e integrar el FFI cuando el
   paquete madure, o si finalmente no se adopta OpenCV nativo.
4. Para pose (V2/V3), si el uso es pose aproximada de cámara, ambos son
   suficientes; para máximo rigor recalcular la pose con solver propio
   sobre esquinas sub-pixel (OpenCV `solvePnP`/`SOLVEPNP_ITERATIVE` o
   equivalente), evitando `IPPE_SQUARE` en cv2 5.x hasta confirmarse el bug.

## Próximos pasos propuestos

- Reportar upstream: bug native-asset symlink (rainyl) y use-after-free de
  pose wrapper, ambos con parches propuestos en el PoC.
- Decidir el plugin Android nativo de detección de marcadores (OpenCV
  Android API) o el FFI, en función del presupuesto de dependencias.
- Integrar la métrica de robustez de esquinas (umbrales) en la calidad de calibración (`Calibration.confidence`).
