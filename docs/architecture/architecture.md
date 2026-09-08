# Arquitectura — GoatVision Mobile

## Clean Architecture + Feature-first

```
lib/
├── core/          # Infraestructura transversal
│   ├── camera/
│   ├── ml/        # interfaces ML, mock ML, pipeline de análisis
│   ├── calibration/
│   ├── storage/   # AppStorage, ImageStorageService
│   ├── permissions/
│   ├── errors/    # excepciones tipadas
│   ├── utils/     # logger, range validator, coord transformer
│   ├── constants/
│   └── theme/
├── domain/        # Entidades + casos de uso + interfaces (sin Flutter)
│   ├── entities/
│   ├── usecases/
│   └── repositories/
├── data/          # Implementaciones (Drift) + adaptadores + providers
│   ├── database/  # tablas Drift
│   ├── repositories/
│   └── providers/ # Riverpod providers
├── features/      # módulos por funcionalidad
│   ├── onboarding/
│   ├── dashboard/
│   ├── animals/
│   ├── animal_detail/
│   ├── capture/
│   ├── analysis/
│   ├── results/
│   ├── history/
│   └── settings/
└── app/           # router + widget raíz
```

## Reglas de dependencia

- `features` → `domain` + `data` (vía providers) + `core`
- `data` → `domain` + `db`
- `domain` → nada (solo Dart puro; sin Flutter)
- `core` → `domain`; nunca importa `features`

## Pipeline de análisis

```
Image
 → Resize / Normalize
 → Detection      (bounding box + confianza)
 → Segmentation   (máscara corporal)
 → Landmarks      (10 puntos anatómicos)
 → Calibration    (píxel → cm)
 → Morphometrics  (medidas biométricas)
 → Feature validation
 → Weight model   (regresión → peso + rango + confianza)
 ```

Cada etapa implementa una interfaz en `core/ml/ml_interfaces.dart` y tiene
una clase/servicio independiente. Los modelos son reemplazables sin tocar
lógica de negocio.

## Interfaces clave

| Interfaz                    | Uso                                   |
|-----------------------------|---------------------------------------|
| `GoatDetectorService`       | Detecta cabras (bbox + confianza)     |
| `GoatSegmenterService`      | Segmenta el cuerpo (máscara)          |
| `LandmarkDetectorService`   | Landmarks anatómicos                  |
| `WeightPredictorService`    | Regresión peso → Prediction           |
| `ModelManager`              | Carga/descarga/inferencia de modelos  |
| `CalibrationProviderService`| Calibración píxel→cm (marcador/manual)|

## Estado (Riverpod)

- `databaseProvider` — conexión Drift
- `animalRepositoryProvider`
- `measurementRepositoryProvider`
- `captureRepositoryProvider`
- `analysisPipelineProvider`
- `weightPredictionServiceProvider`
- `runModeProvider` — mock / real
- `analysisSessionProvider` — resultado de la sesión actual

## Navegación (go_router)

```
/            → dashboard (redirect)
/onboarding
/dashboard
/animals
/animals/add
/animals/:id
/capture?animalId=
/analysis
/result
/history
/settings
```

## Producción de modelos

El entrenamiento ocurre en `mobile/../ml` (Python).
La app **nunca entrena**; solo carga `.tflite` cuantizados y ejecuta inferencia local.