# GoatVision

Aplicación móvil Android para estimar el peso vivo de cabras mediante
Computer Vision, de forma **no invasiva y completamente offline**.

> **Los resultados son ESTIMACIONES basadas en visión artificial.**
> No sustituyen a una báscula. La app muestra peso estimado + rango de
> incertidumbre + nivel de confianza.

## Flujo principal

```
CÁMARA → DETECCIÓN → SEGMENTACIÓN → LANDMARKS → CALIBRACIÓN
→ MEDIDAS BIOMÉTRICAS → MODELO DE REGRESIÓN → PESO ESTIMADO
→ RANGO DE INCERTIDUMBRE → CONFIANZA → HISTORIAL
```

## Estructura del repositorio

```
goatvision/
├── mobile/                 # Aplicación Flutter (Dart)
│   ├── lib/
│   │   ├── core/           # cámara, ml, calibración, almacenamiento, tema
│   │   ├── domain/         # entidades, casos de uso, interfaces
│   │   ├── data/           # repositorios Drift/SQLite, adaptadores
│   │   ├── features/       # onboarding, capture, analysis, results, etc.
│   │   └── app/            # routing, widget raíz
│   ├── assets/models/      # modelos .tflite (los mocks no requieren archivos)
│   └── test/               # tests unitarios y de widgets
├── ml/                     # Pipeline de ML (Python)
│   ├── dataset/            # splits por animal (70/15/15), metadata
│   ├── preprocessing/      # vector de características + aumentación
│   ├── training/           # comparación de regresores
│   ├── ensemble/           # ensamble + intervalo de incertidumbre calibrado
│   ├── evaluation/         # métricas, validación por animal y por subgrupo
│   ├── export/             # exportación móvil
│   ├── experiments/        # reproducibilidad
│   ├── models/
│   └── tests/              # tests unitarios del pipeline
└── docs/                   # arquitectura, pipeline, dataset, research
```

## Stack

| Capa        | Tecnología                                   |
|-------------|----------------------------------------------|
| App         | Flutter · Dart · Material 3                  |
| Estado      | Riverpod                                     |
| Navegación  | go_router                                    |
| Cámara      | camera                                       |
| BD          | Drift · SQLite                               |
| Imágenes    | image                                        |
| ML          | TFLite / ONNX (local, offline)               |
| Entrenamiento | Python · PyTorch · scikit-learn · OpenCV   |

## Implementación actual

El MVP corre en **modo mock**: toda la UI, el pipeline de análisis, la
calibración y la predicción funcionan con servicios simulados, de modo que
es posible desarrollar y probar la experiencia completa antes de entrenar
los modelos reales.

Los modelos simulados están claramente separados en
`lib/core/ml/mock_ml_services.dart` y **nunca deben activarse en producción**
sin reemplazarlos por los modelos `.tflite` reales.

### Predictor de peso de referencia (literatura)

La estimación de peso **no usa un modelo juguete**: desde la captura y el
análisis se utiliza `ReferenceWeightPredictor`
(`lib/core/ml/reference_weight_predictor.dart`), que implementa las
ecuaciones publicadas de **Paredes-Chocce et al. (2025)**
(Biodiversitas 26(7), DOI 10.13057/biodiv/d260710, n = 356):

```
BW (kg) = -45.642 + 0.71·TG + 0.21·RH + 0.99·RW      (R²aj = 0.644, RSE = 6.305 kg)
```

como el perímetro torácico (TG) no se mide en vista lateral, se **estima**
con la aproximación de Ramanujan para la elipse del tórax a partir de
`chest_depth` y `chest_width` (ver `docs/research/research-notes.md`).

⚠️ Es un predictor **honesto y etiquetado**: la confianza refleja el R²
publicado (0.64) y el intervalo el RSE del estudio, **no** una cobertura
medida por GoatVision. Cuando se entrene y exporte `goat_weight.tflite`
con datos propios, sustituye a este fallback.

El modo se controla con `runModeProvider` (`lib/data/providers/providers.dart`).
`RunMode.real` lanza `UnimplementedError` hasta completar la integración de los
modelos TFLite: los mocks nunca se activan accidentalmente en producción.

Flujo de captura: `capture → analysis → result → Guardar`. La imagen se persiste
en el momento de la captura y se guarda junto a la medición y las medidas
biométricas desde la pantalla de resultados (`result_screen.dart`).

### Integración en máquina real

El desarrollo continuó en un host sin toolchain Flutter/Dart y sin
pandas/sklearn/OpenCV, por lo que quedan pasos que requieren una máquina con
acceso a paquetes:

```bash
# 1. Backend ML: instalar dependencias y generar el dataset sintético E2E
cd ml
pip install -r requirements.txt
python -m dataset.split_dataset --animals 300 --output dataset

# 2. Entrenar, ensamblar, evaluar y exportar el modelo TFLite
python -m training.train_regression --csv dataset/features.csv --experiment experiment-001
python -m ensemble.ensemble --csv dataset/features.csv --output experiments/experiment-001/ensemble
python -m evaluation.cross_validate_by_animal --csv dataset/features.csv
python -m export.export_model --model experiments/experiment-001/model_best.joblib --version goat-weight-v1.0

# 3. App móvil: generar código Drift, analizar y correr tests
cd ../mobile
flutter pub get
dart run build_runner build --delete-conflicting-outputs   # *.g.dart / *.freezed.dart
flutter analyze
flutter test

# 4. Pasar RunMode.real e integrar los .tflite
#    (providers.dart lanza UnimplementedError a propósito hasta completarlo)
```

Mientras tanto: **15 tests ML** pasan localmente (7 con numpy puro; 8 se
saltan sin pandas/sklearn/OpenCV), el split del dataset se verificó E2E y las
columnas de características son idénticas entre `ml/` y `mobile/lib`.

## Cómo ejecutar la app

```bash
cd mobile
flutter pub get
flutter run
```

## Pipeline de entrenamiento

```bash
cd ml
pip install -r requirements.txt

# 1. Generar metadata y splits (por animal)
python -m dataset.split_dataset --animals 300 --output dataset

# 2. Entrenar y comparar modelos
python -m training.train_regression --csv dataset/features.csv --experiment experiment-001

# 2b. Ensamble + intervalo de incertidumbre (cobertura medida por animal)
python -m ensemble.ensemble --csv dataset/features.csv --output experiments/experiment-001/ensemble

# 3. Validación cruzada por animal
python -m evaluation.cross_validate_by_animal --csv dataset/features.csv

# 3b. Desglose de error por subgrupo (raza, sexo, edad, peso, ...)
python -m evaluation.stratify --csv dataset/features.csv --predictions-json predictions.json

# 4. Exportar modelo
python -m export.export_model --model experiments/experiment-001/model_best.joblib --version goat-weight-v1.0
```

## Tests ML

Los tests que solo dependen de numpy corren en cualquier entorno; los que
necesitan pandas/sklearn/OpenCV se saltan si no están instalados:

```bash
cd ml
python3 -m unittest tests.test_ml        # o: python3 -m unittest ml.tests.test_ml
```

Estado actual: 15 tests (7 con numpy puro; 8 condicionales a deps).

## Principios

1. Funcionamiento offline.
2. Arquitectura modular y modelos reemplazables.
3. Sin falsa precisión: siempre rango + confianza.
4. Dataset reproducible, validación **por animal** (sin data leakage).
5. Versionado de modelos.
6. Sin backend, sin cloud, sin dependencias innecesarias.

## Documentación

- [Arquitectura](docs/architecture/architecture.md)
- [Pipeline ML](docs/ml/pipeline.md)
- [Entrenamiento](docs/ml/training.md)
- [Evaluación](docs/ml/evaluation.md)
- [Especificación del dataset](docs/dataset/dataset-specification.md)
- [Notas de investigación](docs/research/research-notes.md)
- [Privacidad](docs/privacy/privacy.md)

## Roadmap

- **MVP**: Android · offline · una cabra · vista lateral · marcador · peso + rango + historial
- **V2**: vista trasera · multi-view · BCS · más razas
- **V3**: ARCore · Depth · 3D · multimodal · cloud sync opcional