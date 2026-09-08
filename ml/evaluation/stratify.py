"""Subgroup error evaluation (spec section 28).

Overall MAE/RMSE/R2 can hide a model that fails badly on a particular
breed, sex, age band, weight range, device or lighting condition.  This
module reports the error *per subgroup* so problems are visible and the
model card can state honestly where the model works worst.

Usage is deliberately simple: pass the test DataFrame, the true and
predicted weights, and the columns to stratify by.  Subgroups with few
samples are flagged so nobody over-interprets a tiny subset.
"""

from __future__ import annotations

import json
from dataclasses import dataclass
from pathlib import Path

import numpy as np
import pandas as pd

from evaluation.metrics import compute_metrics

# Minimum number of rows to treat a subgroup as statistically meaningful.
MIN_SAMPLES = 5


@dataclass
class SubgroupResult:
    subgroup: str
    value: str
    n: int
    metrics: dict
    flagged: bool = False


def _age_band(months: float) -> str:
    if months < 6:
        return "0-6m"
    if months < 12:
        return "6-12m"
    if months < 24:
        return "12-24m"
    return "24m+"


def _weight_band(kg: float) -> str:
    if kg < 20:
        return "<20kg"
    if kg < 35:
        return "20-35kg"
    if kg < 55:
        return "35-55kg"
    return "55kg+"


_BANDERS = {
    "age_band": _age_band,
    "weight_band": _weight_band,
}


def _bucketed_df(df: pd.DataFrame) -> pd.DataFrame:
    """Add derived bucketed columns for numeric stratification."""
    out = df.copy()
    if "age_months" in out.columns:
        out["age_band"] = out["age_months"].apply(_age_band)
    if "real_weight_kg" in out.columns:
        out["weight_band"] = out["real_weight_kg"].apply(_weight_band)
    return out


def evaluate_by_subgroup(
    df: pd.DataFrame,
    y_pred: np.ndarray,
    columns: list[str] | None = None,
    min_samples: int = MIN_SAMPLES,
) -> dict[str, list[SubgroupResult]]:
    """Compute error metrics per unique value of each stratification column.

    ``columns`` defaults to all categorical metadata columns available
    (breed, sex, region, camera, lighting, environment, view, distance)
    plus derived age_band and weight_band.
    """
    y_true = df["real_weight_kg"].to_numpy(dtype=float)
    y_pred = np.asarray(y_pred, dtype=float)

    if len(y_true) != len(y_pred):
        raise ValueError("y_true and y_pred must have the same length.")

    bucketed = _bucketed_df(df)

    default_cols = [
        c for c in ["breed", "sex", "region", "camera", "lighting",
                    "environment", "view", "distance", "age_band", "weight_band"]
        if c in bucketed.columns
    ]
    columns = columns or default_cols

    results: dict[str, list[SubgroupResult]] = {}
    for col in columns:
        if col not in bucketed.columns:
            continue
        subgroups: list[SubgroupResult] = []
        for value, group in bucketed.groupby(col, dropna=False):
            idx = group.index.to_numpy()
            metrics = compute_metrics(
                y_true[idx], y_pred[idx]
            )
            subgroups.append(
                SubgroupResult(
                    subgroup=col,
                    value=str(value),
                    n=int(len(idx)),
                    metrics=metrics,
                    flagged=int(len(idx)) < min_samples,
                )
            )
        subgroups.sort(key=lambda r: r.metrics["mae_kg"], reverse=True)
        results[col] = subgroups
    return results


def worst_subgroups(
    results: dict[str, list[SubgroupResult]],
    min_samples: int = MIN_SAMPLES,
) -> list[tuple[str, str, float, int]]:
    """Sorted list of (column, value, mae, n) from worst to best, filtering
    out subgroups that are too small to be meaningful."""
    rows: list[tuple[str, str, float, int]] = []
    for col, subgroups in results.items():
        for r in subgroups:
            if r.n >= min_samples:
                rows.append((r.subgroup, r.value, r.metrics["mae_kg"], r.n))
    rows.sort(key=lambda t: t[2], reverse=True)
    return rows


def format_report(
    results: dict[str, list[SubgroupResult]],
    min_samples: int = MIN_SAMPLES,
) -> str:
    lines = ["# Error by subgroup (MAE, kg)", ""]
    for col, subgroups in results.items():
        lines.append(f"## {col}")
        for r in subgroups:
            flag = "  ⚠ small sample" if r.flagged else ""
            lines.append(
                f"- {r.value}: MAE={r.metrics['mae_kg']:.2f} kg, "
                f"MAPE={r.metrics['mape_pct']:.1f}%, n={r.n}{flag}"
            )
        lines.append("")
    return "\n".join(lines)


def main() -> None:
    import argparse

    parser = argparse.ArgumentParser(
        description="Evaluate errors per subgroup (breed, sex, age, weight, ...)."
    )
    parser.add_argument("--csv", type=Path, required=True)
    parser.add_argument("--predictions-json", type=Path, default=None,
                        help='JSON {"predictions": [...], } aligned with the CSV rows.')
    parser.add_argument("--predictions-csv", type=Path, default=None,
                        help="CSV with a 'pred_weight_kg' column aligned with --csv.")
    parser.add_argument("--output", type=Path, default=Path("subgroup_report.json"))
    parser.add_argument("--min-samples", type=int, default=MIN_SAMPLES)
    args = parser.parse_args()

    df = pd.read_csv(args.csv)

    if args.predictions_json is not None:
        data = json.loads(args.predictions_json.read_text())
        y_pred = np.asarray(data["predictions"], dtype=float)
    elif args.predictions_csv is not None:
        pred_df = pd.read_csv(args.predictions_csv)
        y_pred = pred_df["pred_weight_kg"].to_numpy(dtype=float)
    else:
        raise SystemExit("Provide --predictions-json or --predictions-csv.")

    results = evaluate_by_subgroup(df, y_pred, min_samples=args.min_samples)

    serializable = {
        col: [
            {
                "value": r.value,
                "n": r.n,
                "metrics": r.metrics,
                "flagged": r.flagged,
            }
            for r in subgroups
        ]
        for col, subgroups in results.items()
    }
    args.output.write_text(json.dumps(serializable, indent=2))
    print(format_report(results, min_samples=args.min_samples))
    print(f"\nSaved {args.output}")


if __name__ == "__main__":
    main()
