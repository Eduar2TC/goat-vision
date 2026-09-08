# GoatVision — Aplicación móvil

App Android (Flutter) para estimar el peso vivo de cabras mediante visión
artificial, 100% offline. Documentación general en el [README raíz](../README.md).

## Arquitectura

```
lib/
├── app/            # MaterialApp, routing (go_router)
├── core/           # cámara, ml (interfaces + mocks), calibración, almacenamiento, tema
│   ├── ml/         # reference_weight_predictor, mock_ml_services, analysis_pipeline
│   ├── storage/    # app_storage, dataset_log_format, dataset_log_service
│   └── theme/      # theme_mode_provider
├── data/           # providers (Riverpod), DB Drift/SQLite, repositorios
├── domain/         # entidades, casos de uso, interfaces de repositorios
└── features/       # onboarding, capture, analysis, results, animals, history, settings
    └── history/
        ├── domain/        # history_filter (lógica pura testeable)
        └── presentation/  # history_screen
```

- **Estado:** Riverpod
- **Navegación:** go_router
- **Persistencia:** Drift/SQLite
- **ML:** TFLite (offline). Los modelos `.tflite` aún no están integrados:
  - La CV (detección/segmentación/landmarks) corre con mocks de desarrollo en
    `lib/core/ml/mock_ml_services.dart`.
  - El peso real usa la fórmula de referencia de Paredes-Chocce et al. (2025)
    en `reference_weight_predictor.dart` (r²=0.644, RSE 6.305 kg); un modelo
    TFLite propio la sustituirá cuando se integre.

## Flujo de captura

```
capture → analysis → result → Guardar
```

La imagen se persiste en el momento de la captura; al pulsar **Guardar** en la
pantalla de resultados se persisten medición + medidas biométricas + captura.

## Funcionalidades

- **Escaneo rápido:** "Escanear cabra" en el dashboard captura sin animal
  previo; al guardar se auto-registra una cabra "sin registrar · fecha".
- **Cabras:** alta/edición (`AddAnimalScreen`, ruta `/animals/edit`) y
  **borrado en cascada** desde el detalle (mediciones, medidas, capturas e
  imágenes en transacción, con confirmación).
- **Historial:** lista de mediciones con **búsqueda por nombre o peso**;
  cada entrada navega al detalle de la cabra.
- **Ajustes:** unidad kg/lb y tema claro/oscuro/sistema persistidos en
  `AppStorage`; estado de modelos real/pendiente; **informe científico**
  (ecuación, R²/RSE, rangos, DOI copiable y advertencias honestas).
- **Recolección de dataset (dev):** campo "Peso real en báscula" en
  resultados → log JSONL → exportación CSV (8 features + real_weight_kg).

## Generación de código

Drift y dependencias generan `*.g.dart` / `*.freezed.dart` (en `.gitignore`,
no versionados). Re-generar en una máquina con el SDK de Flutter:

```bash
flutter pub get
dart run build_runner build --delete-conflicting-outputs
```

## Tests

```bash
flutter analyze
flutter test
```

Tests incluidos:
- `test/unit/` — calibration, ml_services, morphometric_calculator,
  range_validator, reference_weight_predictor, weight_prediction,
  unit_converter, history_filter, dataset_log_format
- `test/data/` — drift_animal_repository (cascada con DB en memoria)
- `test/widget/` — result_screen, settings_screen

> `RunMode.real` lanza `UnimplementedError` a propósito hasta que se integren
> los modelos `.tflite` (ver `lib/data/providers/providers.dart`). Los mocks
> nunca se activan en producción por accidente.