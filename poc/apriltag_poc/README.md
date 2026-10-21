# PoC: AprilTag (FFI Dart) vs ArUco de OpenCV — corners y pose

Benchmark sintético sobre la familia compartida **tag36h11** (OpenCV la lee
con `DICT_APRILTAG_36H11`, así que ambos detectores corren sobre las
MISMAS imágenes con GT exacto de esquinas y pose).

## Resultado

Ver `results/apriltag_results.json` y `results/aruco_results.json`;
la tabla comparativa se imprime con:

```bash
~/.venvs/fiducial-poc/bin/python tools/aruco_baseline.py banner
```

Resumen (56 escenas, 800×600 px, fx=fy=750, tag 10 cm):

- **Robustez de detección**: empate en 13/14 condiciones (100% ambas);
  AprilTag falla en `occl_40` (0/4), OpenCV ArUco solo falla 2 de 4 →
  ArUco es algo más robusto a oclusión parcial del centro.
- **Precisión de esquinas**: ArUco con refino sub-pixel es consistentemente
  mejor (0.30–0.88 px vs 0.70–0.77 px de AprilTag, que no usa refino
  sub-pixel equivalente); el error de AprilTag es casi constante (~0.7 px)
  incluso a 25 px de lado.
- **Pose**: traducción muy similar (3–26 mm en ambos, mejor AprilTag en
  varias condiciones); rotación comparable (≤13°, picos en tilt).
- **Latencia**: cross-language (JIT Dart vs C++ nativo), solo orientativa:
  AprilTag 5–15 ms típicos (hasta ~170 ms con ruido fuerte), ArUco 2–8 ms
  típicos (hasta ~40 ms con ruido).

⚠️ El error absoluto de esquinas está dominado por una convención de
half-pixel compartida por ambos (GT es la proyección geométrica exacta);
lo relevante es la comparación relativa.

## Cómo reproducir

```bash
# 1. imágenes sintéticas (56 escenas + ground_truth.json)
~/.venvs/fiducial-poc/bin/python tools/generate_scenes.py

# 2. AprilTag vía FFI (compila el nativo con hooks de Dart: cmake + ninja)
dart run bin/run_apriltag.dart

# 3. baseline OpenCV ArUco + tabla
~/.venvs/fiducial-poc/bin/python tools/aruco_baseline.py
~/.venvs/fiducial-poc/bin/python tools/aruco_baseline.py banner
```

Requisitos: Dart ≥3.10 (Linux host, cmake+ninja presentes), Python con
`opencv-python-headless>=4.10` (venv `~/.venvs/fiducial-poc`).

## Estructura

```
tools/generate_scenes.py   escenas sintéticas con GT (R,t,esquinas px)
tools/aruco_baseline.py    baseline OpenCV + tabla comparativa
bin/run_apriltag.dart      harness FFI (corners + estimateTagPose)
bin/smoke.dart             sanity check del FFI
images/                    escenas + ground_truth.json
results/                   resultados JSON de ambos detectores
third_party/apriltag_pkg/  paquete apriltag 0.0.2 vendido + 2 parches
```

## Parches al paquete apriltag (third_party/apriltag_pkg)

1. `hook/build.dart`: `findCodeAssets` del native-asset no encuentra nada —
   CMake instala `libapriltag.so` como *symlink* (`so.3` → `so.3.4.5`) y la
   búsqueda salta symlinks (`followLinks:false`, `entity is! File`). Se
   cambia a matching regex del archivo real versionado.
   Reportar upstream: https://github.com/rainyl/apriltag.dart
2. `lib/src/core/pose.dart`: `estimateTagPose` / `estimatePoseForTagHomography`
   devolvían un `MatD` que envuelve memoria del heap de C y **el wrapper la
   libera con `matd_destroy` antes de devolver** → use-after-free (pose R/t
   basura; una vez hasta segfault). Fix: `copy()` antes de `pose.dispose()`.

## Convenciones medidas

- GT: esquinas = proyección de (±s/2, ±s/2, 0) con K[R|t], orden TL→TR→BR→BL.
- AprilTag: error rot medido contra `R_gt·diag(-1,-1,1)` (frame del tag
  y-up); t no se ve afectado. Residuo <1° en condición clean.
- ArUco: usar el orden canónico de esquinas de ArUco sin permutar
  (la simetría 4-fold del cuadrado hace indistinguibles por reproyección
  las rotaciones de 90°/180°).
- `SOLVEPNP_IPPE_SQUARE` en cv2 5.0 devuelve poses erróneas (reproj ~6812 px,
  t≈0) → se usa `SOLVEPNP_ITERATIVE`.
