# Integración móvil de los modelos TFLite

Guía para convertir `RunMode.real` en una pipeline de CV real sin mocks.
La app YA define los contratos; falta implementar servicios que lean los
`.tflite` y el cableado en `providers.dart`.

## Contratos existentes (no cambiar)

Interfaces en `mobile/lib/core/ml/ml_interfaces.dart`:
- `GoatDetectorService.detect(bytes, w, h) → List<Detection>`
- `GoatSegmenterService.segment(bytes, w, h, det) → List<List<int>>` (mask)
- `LandmarkDetectorService.detectLandmarks(...) → LandmarkDetectionResult`
- `WeightPredictorService.predict(MorphometricFeatures) → Prediction`

El pipeline orquesta esas etapas y reporta progreso por fase real
(`AnalysisPipeline.analyze`). `AnalysisStageResult` distingue éxito/fallo
por etapa; la UI muestra el estado honesto (spec §41).

## Contrato de assets

Colocar en `mobile/assets/models/` (declarado en `pubspec.yaml`):

| Asset                        | Interfaz               | Salida                          |
|------------------------------|------------------------|---------------------------------|
| `goat_detector.tflite`       | GoatDetectorService    | bbox (x, y, w, h, conf)         |
| `goat_segmenter.tflite`      | GoatSegmenterService   | máscara binarizada             |
| `goat_landmarks.tflite`      | LandmarkDetectorService| keypoints + confianza global   |
| `goat_weight.tflite`         | WeightPredictorService | [mean, lower, upper] (80%)      |

`goat_weight_config.json` ya describe shape `[1,8] → [1,3]`, INT8.
El peso DA intervalo de incertidumbre y PICP medido con datos propios
(reemplaza a `ReferenceWeightPredictor` como *default* de producto).

## Pasos de implementación

1. **Loader**: `TfliteModelLoader` sobre `Interpreter.fromAsset` de
   `tflite_flutter` (dependencia ya presente). Si falta un asset, lanzar
   `MissingTfliteAssetsException` con la lista de faltantes (no silenciar).
2. **Servicios** en `mobile/lib/core/ml/tflite/`: implementan las interfaces
   ejecutando el `Interpreter` (pre-procesado: normalización al rango del
   modelo; post-procesado: NMS para detección, argmax/umbral para máscara).
3. **Calibración real** para `cmPerPixel`: `MarkerDetector` real
   (ArUco/AprilTag del marcador de 30 cm) en lugar de `MockMarkerDetector`.
4. **Providers**: en `RunMode.real`, devolver
   `AnalysisPipeline(detector: …, segmenter: …, landmarkDetector: …,
   weightPredictor: …, mode: RunMode.real)` con los servicios TFLite y
   `WeightPredictorService` del `.tflite` exportado por `ml/export/export_model.py`.
5. **Test de no-falsos**: `RunMode.real` NUNCA debe caer en servicios mock;
   falls-a-error claro con lista de assets. Los tests de la suite deben
   verificar que mocks y reales son clases distintas.

## Tareas pendientes en el pipeline ML

- Entrenar y exportar los 4 `.tflite` desde `ml/export/export_model.py`
  (requiere dataset real + máquina con toolchain PyTorch/TensorFlow).
- Medir `PICP` sobre el conjunto de validación por animal y registrar el
  intervalo acordado en `goat_weight_config.json`.

## Honestidad

Hasta que existan los `.tflite` y los PICP medidos, `RunMode.real` lanza
`UnimplementedError` a propósito y la UI muestra la insignia
"Modo desarrollador · CV simulada": nunca presentar una CV simulada como
producción.