"""Metrics used to evaluate the GoatVision weight model.

All metrics are computed on a test set of animals that were NEVER
seen during training or validation (no same-animal leakage).

Weight regression
-----------------
MAE  : Mean Absolute Error in kg
RMSE : Root Mean Squared Error in kg
MAPE : Mean Absolute Percentage Error in %
R2   : Coefficient of determination

Report these additional stratifications:
- error by breed
- error by sex
- error by age range
- error by weight range
- error by device
- error by lighting condition
- error by environment
"""

import json

import numpy as np


def compute_metrics(y_true: np.ndarray, y_pred: np.ndarray) -> dict:
    """Compute standard regression metrics."""
    y_true = np.asarray(y_true, dtype=float)
    y_pred = np.asarray(y_pred, dtype=float)

    mae = float(np.mean(np.abs(y_true - y_pred)))
    rmse = float(np.sqrt(np.mean((y_true - y_pred) ** 2)))
    mape = float(np.mean(np.abs((y_true - y_pred) / (y_true + 1e-9))) * 100)

    ss_res = np.sum((y_true - y_pred) ** 2)
    ss_tot = np.sum((y_true - np.mean(y_true)) ** 2)
    r2 = float(1 - ss_res / (ss_tot + 1e-9))

    return {
        "mae_kg": mae,
        "rmse_kg": rmse,
        "mape_pct": mape,
        "r2": r2,
        "mean_error_kg": float(np.mean(y_pred - y_true)),
        "error_std_kg": float(np.std(y_pred - y_true)),
        "n": int(len(y_true)),
    }


def report_model_card(metrics: dict, dataset_summary: dict) -> str:
    """Generate a human-readable model card."""
    lines = [
        "# GoatVision Weight Model Card",
        "",
        "## Model performance",
        f"- MAE: {metrics['mae_kg']:.2f} kg",
        f"- RMSE: {metrics['rmse_kg']:.2f} kg",
        f"- MAPE: {metrics['mape_pct']:.2f} %",
        f"- R²: {metrics['r2']:.3f}",
        f"- Mean error: {metrics['mean_error_kg']:.2f} kg",
        f"- Error std: {metrics['error_std_kg']:.2f} kg",
        "",
        "## Dataset",
        f"- Animals: {dataset_summary.get('n_animals')}",
        f"- Captures: {dataset_summary.get('n_captures')}",
        f"- Breeds: {dataset_summary.get('breeds')}",
        f"- Weight range: {dataset_summary.get('weight_range')}",
        "",
        "## Known limitations",
        "- Estimates are NOT scale measurements.",
        "- Error increases in poor lighting and extreme body conditions.",
        "- Model degrades on breeds under-represented in the training set.",
        "",
        "## Usage disclaimer",
        "- Use the provided uncertainty range, never a single number.",
    ]
    return "\n".join(lines)


if __name__ == "__main__":
    y_true = np.array([30.0, 40.0, 50.0, 60.0])
    y_pred = np.array([30.5, 39.2, 51.0, 58.5])
    print(json.dumps(compute_metrics(y_true, y_pred), indent=2))