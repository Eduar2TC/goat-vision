"""Reproducibility: capture full experiment configuration."""

import json
from pathlib import Path


def save_experiment(
    experiment_dir: Path,
    *,
    experiment_id: str,
    seed: int,
    metrics: dict,
    model_paths: list,
    feature_importances: dict,
    features: list,
    notes: str = "",
) -> None:
    experiment_dir.mkdir(parents=True, exist_ok=True)

    config = {
        "experiment_id": experiment_id,
        "seed": seed,
        "dataset_version": "goat-dataset-2026-09",
        "splits": {"train": 0.70, "validation": 0.15, "test": 0.15},
        "features": features,
        "notes": notes,
    }
    with open(experiment_dir / "config.json", "w") as f:
        json.dump(config, f, indent=2)

    with open(experiment_dir / "metrics.json", "w") as f:
        json.dump(metrics, f, indent=2)

    with open(experiment_dir / "feature_importance.json", "w") as f:
        json.dump(feature_importances, f, indent=2)

    report = {
        "experiment_id": experiment_id,
        "models": [str(p) for p in model_paths],
        "metrics": metrics,
    }
    with open(experiment_dir / "report.json", "w") as f:
        json.dump(report, f, indent=2)

    print(f"Saved experiment metadata to {experiment_dir}")


if __name__ == "__main__":
    save_experiment(
        Path("experiments/experiment-001"),
        experiment_id="experiment-001",
        seed=42,
        metrics={"mae": 0.0},
        model_paths=[],
        feature_importances={},
        features=["body_length"],
        notes="Example",
    )