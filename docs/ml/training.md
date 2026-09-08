# Entrenamiento

## Reproducibilidad

Cada experimento guarda:

```
experiments/experiment-XXX/
├── config.json               # seed, dataset version, features, hiperparámetros
├── metrics.json              # ranking por MAE/RMSE/MAPE/R²
├── feature_importance.json   # peso de cada variable
├── report.json               # informe consolidado
└── model_*.joblib            # modelos entrenados
```

## Commandos

```bash
cd ml
pip install -r requirements.txt

# Generar metadata + splits
python -m dataset.split_dataset --animals 300 --output dataset

# Convertir a CSV de features
python -m preprocessing.features --csv dataset/features.csv

# Entrenar y comparar
python -m training.train_regression \
    --csv dataset/features.csv \
    --experiment experiment-001 \
    --output experiments

# Validación cruzada por animal
python -m evaluation.cross_validate_by_animal --csv dataset/features.csv

# Ensamble + intervalo de incertidumbre calibrado por animal
python -m ensemble.ensemble \
    --csv dataset/features.csv \
    --output experiments/experiment-001/ensemble

# Desglose de error por subgrupo (raza, sexo, edad, peso, ...)
python -m evaluation.stratify \
    --csv dataset/features.csv \
    --predictions-json predictions.json \
    --output experiments/experiment-001/subgroup_report.json
```

En Python, para entrenar el ensamble con intervalo:

```python
from ensemble.ensemble import build_ensemble
from preprocessing.features import FEATURE_COLUMNS, TARGET
import pandas as pd

df = pd.read_csv("dataset/features.csv")
X = df[FEATURE_COLUMNS].values
y = df[TARGET].values
res = build_ensemble(X, y, animal_ids=df["animal_id"].values, seed=42)
print(res.metrics)                      # PICP, MPIW, pinball, confidence
for p in res.predict_interval(X[:10]):  # point, lower, upper, confidence
    print(p)
res.save("experiments/experiment-001/ensemble")
```

## Selección de modelo

Se selecciona el modelo con el mejor equilibrio entre:

- Precisión (MAE/RMSE/MAPE/R²)
- Generalización (holgura train-vs-validation)
- Tamaño del modelo (adecuado para móvil)
- Velocidad de inferencia (< 50 ms objetivo)
- Compatibilidad móvil (TFLite/ONNX, INT8 quantization)

## Exportación móvil

```bash
python -m export.export_model \
    --model experiments/experiment-001/model_best.joblib \
    --version goat-weight-v1.0 \
    --output mobile/assets/models
```

La app lee `goat_weight_config.json` para conocer versión, features y métricas.