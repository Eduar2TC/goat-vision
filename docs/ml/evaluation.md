# Evaluación científica

## Métricas

Para regresión de peso **nunca usar "accuracy"**. Reportar:

- **MAE** — error absoluto medio (kg)
- **RMSE** — raíz del error cuadrático medio (kg)
- **MAPE** — error porcentual absoluto medio (%)
- **R²** — coeficiente de determinación
- error medio y desviación del error (kg)
- intervalos de confianza cuando corresponda

## Prevención de data leakage

- El split es por **animal** (70% train / 15% validación / 15% test).
- Una fotografía y sus variantes (augmentadas) del mismo animal no pueden
  cruzar a test.
- Validación cruzada con `GroupKFold(n_splits)` agrupando por `animal_id`.

## Estratificación del error

Reportar error por:

- raza
- sexo
- rango de edad
- rango de peso
- dispositivo/cámara
- condición de iluminación
- ambiente
- distancia y pose

Esto indica **dónde funciona peor el modelo** y guía la recolección futura.

Implementación: `ml/evaluation/stratify.py` genera el desglose por
subgrupo a partir del CSV de test y las predicciones, marca los subgrupos
con pocas muestras y ordena de peor a mejor MAE.

```bash
python -m evaluation.stratify \
    --csv dataset/features_test.csv \
    --predictions-json predictions.json \
    --output subgroup_report.json
```

## Incertidumbre honesta (intervalo de predicción)

`ml/ensemble/ensemble.py` entrena un median-ensemble
(Random Forest + SVR + Gradient Boosting) con **regresión por cuantiles**
(α=0.10 y α=0.90) para dar el rango bajo/alto.

- La calibración se hace **por animal**: los animales de calibración
  nunca entrenan al ensamble ni a los cuantiles.
- **PICP** = cobertura medida (fracción de cabras cuyo peso real cae
  dentro del rango). Es la **confianza operativa** mostrada en la UI.
- **MPIW** = anchura media del intervalo (kg); **pinball** = nitidez.

Nunca se inventa una probabilidad: la confianza se mide sobre animales
no vistos.

## Condiciones de prueba

- Indoor / outdoor
- Sol / nublado
- Baja luz
- Diferentes fondos
- Diferentes razas
- Diferentes teléfonos
- Diferentes distancias
- Diferentes poses
- Múltiples capturas por animal

## Criterio de aceptación del MVP

El MVP es científicamente válido cuando la estimación reporta:

1. peso estimado
2. rango de incertidumbre
3. confianza definida y documentada
4. métricas reales sobre un test independiente (sin fugas)

Nunca: un único número con decimales sin incertidumbre.