# Pipeline de ML

## Flujo general

```
Raw Images
 → Quality Control
 → Annotation (bbox, mask, landmarks, peso báscula)
 → Dataset Split (70/15/15 POR ANIMAL)
 → Feature Engineering (medidas cm)
 → Training (comparación de regresores)
 → Validation (GroupKFold por animal)
 → Model Selection (mejor equilibrio precisión/tamaño/velocidad)
 → Export (config + feature importance + metadata)
 → Mobile Integration (TFLite/ONNX)
```

## Modelos candidatos

- Linear Regression
- Polynomial Regression
- Random Forest
- Extra Trees
- SVR
- Gradient Boosting
- XGBoost
- MLP

**No se asume** que Random Forest sea el mejor; el ranking se decide por MAE
sobre un conjunto de validación sin animales vistos en entrenamiento.

## Reglas críticas

1. **Divisiones por animal, nunca por fotografía.** Una cabra no puede
   aparecer en train y test (evita data leakage).
2. Ejecutar validación cruzada **agrupada por animal** (GroupKFold).
3. Guardar seed, versión de dataset, hiperparámetros, lista de features y
   métricas para reproducibilidad.
4. Ground truth de peso = báscula. La imagen sola produce centímetros solo
   si hay calibración válida.

## Etapas del pipeline

### 1. Dataset
`ml/dataset/split_dataset.py` genera metadata sintética y los splits por
animal. Para datos reales se reemplaza el archivo CSV/JSON por
capturas anotadas reales.

### 2. Preprocesamiento
`ml/preprocessing/features.py` construye la matriz de features:

```
body_length_cm, withers_height_cm, rump_height_cm, chest_depth_cm,
chest_width_cm, rump_width_cm, rump_length_cm, paw_height_cm
```

y guarda estadísticas de normalización (mean/std) para la app.

`ml/preprocessing/augmentation.py` (spec §26) aplica aumentación para el
pipeline de CV (rotación, crop, brillo/contraste, blur, ruido, escala,
perspectiva suave, volteo). Solo se usan transformaciones geométricas que
**preservan las proporciones anatómicas** (sin escala no-uniforme ni
stretching, para no falsificar los ratios morfométricos). Los bounding
boxes, landmarks y el marcador de calibración se transforman junto con la
imagen para que las anotaciones sigan siendo válidas.

### 3. Entrenamiento
`ml/training/train_regression.py` entrena los candidatos y escribe
`metrics.json` con ranking por MAE, RMSE, MAPE y R².

### 3b. Ensemble + intervalo de incertidumbre
`ml/ensemble/ensemble.py` entrena un ensamble (median ensemble de
Random Forest + SVR + Gradient Boosting) y calibra un **intervalo de
predicción real** mediante regresión por cuantiles (α=0.10 y α=0.90).

Reglas de honestidad (spec §20–§21):

- La división para calibrar intervalos se hace **por animal**: los animales
  de calibración nunca se usan para entrenar el ensamble ni los cuantiles.
- La cobertura se **mide** sobre animales no vistos (PICP), no se asume.
- La confianza operativa que muestra la UI = cobertura calibrada medida.
- Se reportan además MPIW (anchura media) y pinball (nitidez) para
  documentar la calidad del intervalo sin inventar probabilidades.

### 4. Evaluación
`ml/evaluation/cross_validate_by_animal.py` produce métricas leales
(GroupKFold por animal). `metrics.py` reporta métricas globales.
`ml/evaluation/stratify.py` añade el **desglose por subgrupo** (spec §28):
error por raza, sexo, edad, rango de peso, dispositivo, iluminación,
ambiente, vista y distancia, y marca los subgrupos con pocas muestras
para no sobre-interpretar.

### 5. Exportación
`ml/export/export_model.py` genera `config.json`, `feature_importance.json`
y el modelo listo para móvil.

## Métricas de regresión

```
MAE  (kg), RMSE (kg), MAPE (%), R², error medio, desviación del error
```

Se reportan además intervalos de confianza y estratificación por grupo
cuando el dataset lo permite.