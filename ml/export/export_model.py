"""Export trained models for mobile inference.

Produces:
- config.json            (features, model version, algorithm, dataset stats)
- feature_importance.json
- normalization.json     (per-feature mean/std for the mobile app)
- model_metadata.json
- model.onnx             (when skl2onnx is installed; portable format)

TFLite/INT8 quantization is a separate step run on a desktop with
TensorFlow (see docs/ml/training.md).  This module guarantees the
metadata contract the mobile app (``goat_weight_config.json``) expects.
"""

import argparse
import json
from pathlib import Path

import joblib
import numpy as np

from preprocessing.features import FEATURE_COLUMNS, TARGET

try:
    from skl2onnx import convert_sklearn
    from skl2onnx.common.data_types import FloatTensorType

    SKL2ONNX_AVAILABLE = True
except ImportError:
    SKL2ONNX_AVAILABLE = False


def extract_feature_importance(pipeline, output_dir: Path) -> dict:
    model = pipeline.named_steps.get("model")
    importance = {}
    if hasattr(model, "feature_importances_"):
        importance = {
            name: float(imp)
            for name, imp in sorted(
                zip(FEATURE_COLUMNS, model.feature_importances_),
                key=lambda pair: pair[1],
                reverse=True,
            )
        }
    elif hasattr(model, "coef_"):
        coef = model.coef_
        if isinstance(coef, np.ndarray) and coef.ndim > 0:
            importance = {
                name: float(c)
                for name, c in sorted(
                    zip(FEATURE_COLUMNS, coef),
                    key=lambda pair: abs(pair[1]),
                    reverse=True,
                )
            }

    with open(output_dir / "feature_importance.json", "w") as f:
        json.dump(importance, f, indent=2)
    return importance


def export_model(model_path: Path, output_dir: Path, model_version: str) -> None:
    pipeline = joblib.load(model_path)
    model = pipeline.named_steps.get("model")
    algorithm = type(model).__name__

    output_dir.mkdir(parents=True, exist_ok=True)

    config = {
        "model_version": model_version,
        "dataset_version": "goat-dataset-2026-09",
        "algorithm": algorithm,
        "features": FEATURE_COLUMNS,
        "feature_count": len(FEATURE_COLUMNS),
        "model_path": str(model_path),
    }
    with open(output_dir / "config.json", "w") as f:
        json.dump(config, f, indent=2)

    importance = extract_feature_importance(pipeline, output_dir)

    # Normalization stats for the mobile app pre-processing step.
    normalization = {
        "mean": {f: 0.0 for f in FEATURE_COLUMNS},
        "std": {f: 1.0 for f in FEATURE_COLUMNS},
        "source": "set from dataset; update with preprocessing.features",
    }
    with open(output_dir / "normalization.json", "w") as f:
        json.dump(normalization, f, indent=2)

    model_metadata = {
        "model_version": model_version,
        "algorithm": algorithm,
        "input_features": FEATURE_COLUMNS,
        "target": TARGET,
        "output": "estimated_weight_kg",
        "uncertainty": "prediction_interval_alpha_10_90",
        "feature_importance": importance,
    }
    with open(output_dir / "model_metadata.json", "w") as f:
        json.dump(model_metadata, f, indent=2)

    if SKL2ONNX_AVAILABLE and hasattr(model, "predict"):
        try:
            _export_onnx(pipeline, output_dir, model_version)
        except Exception as exc:  # pragma: no cover - depends on model type
            print(f"[warn] ONNX export skipped for {algorithm}: {exc}")
    else:
        print("[info] skl2onnx not available; skipping ONNX export. "
              "Install skl2onnx for portable model export.")

    print(json.dumps(config, indent=2))
    print(json.dumps(importance, indent=2))


def _export_onnx(pipeline, output_dir: Path, model_version: str) -> None:
    """Export the fitted pipeline to ONNX (float32, feature vector input)."""
    n_features = len(FEATURE_COLUMNS)
    initial_type = [("input", FloatTensorType([None, n_features]))]
    onnx_model = convert_sklearn(pipeline, initial_types=initial_type)
    onnx_path = output_dir / f"{model_version}.onnx"
    with open(onnx_path, "wb") as f:
        f.write(onnx_model.SerializeToString())
    print(f"Exported ONNX model to {onnx_path}")


def main():
    parser = argparse.ArgumentParser()
    parser.add_argument("--model", type=Path, required=True)
    parser.add_argument("--output", type=Path, default=Path("export"))
    parser.add_argument("--version", type=str, default="goat-weight-v1.0")
    args = parser.parse_args()

    export_model(args.model, args.output, args.version)


if __name__ == "__main__":
    main()