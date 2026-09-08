"""Feature extraction from morphometric measurements.

Converts CSV of captures into a feature matrix for regression training.
"""

import argparse
import json
from pathlib import Path

import numpy as np

FEATURE_COLUMNS = [
    "body_length_cm",
    "withers_height_cm",
    "rump_height_cm",
    "chest_depth_cm",
    "chest_width_cm",
    "rump_width_cm",
    "rump_length_cm",
    "paw_height_cm",
]

TARGET = "real_weight_kg"


def load_feature_matrix(csv_path: Path) -> pd.DataFrame:
    # Lazy import: pandas is only needed for real training/evaluation, so
    # scripts that just consume the constants (e.g. split_dataset) can run
    # with numpy only.
    import pandas as pd

    df = pd.read_csv(csv_path)
    required = FEATURE_COLUMNS + [TARGET, "animal_id"]
    missing = [c for c in required if c not in df.columns]
    if missing:
        raise ValueError(f"Missing columns: {missing}")

    features = df[FEATURE_COLUMNS].copy()
    stats = {
        "mean": features.mean().round(3).to_dict(),
        "std": features.std().round(3).to_dict(),
        "min": features.min().round(3).to_dict(),
        "max": features.max().round(3).to_dict(),
        "n_animals": df["animal_id"].nunique(),
        "n_captures": len(df),
        "weight_min": df[TARGET].min(),
        "weight_max": df[TARGET].max(),
    }

    normalized = (features - features.mean()) / (features.std() + 1e-9)

    return df, normalized, stats


def save_experiment_config(
    output_dir: Path,
    experiment_id: str,
    extra: dict,
) -> None:
    output_dir.mkdir(parents=True, exist_ok=True)
    config = {
        "experiment_id": experiment_id,
        "features": FEATURE_COLUMNS,
        "target": TARGET,
        "seed": 42,
        "dataset_version": "goat-dataset-2026-09",
        **extra,
    }
    with open(output_dir / "config.json", "w") as f:
        json.dump(config, f, indent=2)
    print(f"Saved config to {output_dir / 'config.json'}")


def main() -> None:
    parser = argparse.ArgumentParser()
    parser.add_argument("--csv", type=Path, required=True, help="Path to features CSV")
    args = parser.parse_args()

    df, normalized, stats = load_feature_matrix(args.csv)
    print(json.dumps(stats, indent=2))


if __name__ == "__main__":
    main()