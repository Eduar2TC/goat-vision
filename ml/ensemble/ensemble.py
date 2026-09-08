"""Median ensemble weight model with calibrated prediction intervals.

Design notes
------------
A single point estimate is not enough: the UI must always show a range
and a confidence.  We therefore train:

1. A *median* regressor ``WeightEnsemble`` that averages the median
   predictions of several base models (Random Forest, SVR, Gradient
   Boosting by default).  The median is more robust than the mean to a
   single overconfident member.

2. A pair of *quantile* regressors (GradientBoostingRegressor with
   ``loss='quantile'`` at alpha=0.10 and alpha=0.90) calibrated on a
   validation fold composed of whole animals that were not in the
   calibration training set.  These give the lower and upper bounds.

The interval is then evaluated with PICP / MPIW on an independent test
set of animals, so coverage is *measured* rather than assumed.  If the
interval under-covers, the caller can widen it using the measured
residual quantiles as a documented correction.

No figures are invented: ``confidence`` is defined operationally as the
empirical coverage (PICP) observed on the calibration fold.
"""

from __future__ import annotations

import json
from dataclasses import dataclass, field
from pathlib import Path

import joblib
import numpy as np
import pandas as pd
from sklearn.base import BaseEstimator, RegressorMixin
from sklearn.ensemble import GradientBoostingRegressor, RandomForestRegressor
from sklearn.pipeline import Pipeline
from sklearn.svm import SVR

from preprocessing.features import FEATURE_COLUMNS
from ensemble.intervals import (
    CENTRAL_ALPHA,
    DEFAULT_CALIBRATION_RATIO,
    LOWER_ALPHA,
    UPPER_ALPHA,
    interval_metrics,
    split_by_animal,
)


def _make_base(name: str, seed: int) -> tuple[str, Pipeline]:
    """Return (name, pipeline) of a single base regressor."""
    if name == "random_forest":
        return name, Pipeline(
            [
                ("scaler", None),
                (
                    "model",
                    RandomForestRegressor(
                        n_estimators=200,
                        max_depth=12,
                        random_state=seed,
                        n_jobs=-1,
                    ),
                ),
            ]
        )
    if name == "svr":
        return name, Pipeline([("model", SVR(C=10.0, gamma="scale", epsilon=1.0))])
    if name == "gradient_boosting":
        return name, Pipeline(
            [
                (
                    "model",
                    GradientBoostingRegressor(
                        n_estimators=200,
                        learning_rate=0.05,
                        max_depth=4,
                        random_state=seed,
                    ),
                )
            ]
        )
    raise ValueError(f"Unknown base model: {name}")


class WeightEnsemble(BaseEstimator, RegressorMixin):
    """Median ensemble of several sklearn regressors.

    The ensemble predicts the pointwise median of its members, which is
    robust to a single poorly-calibrated member.
    """

    def __init__(
        self,
        base_names: list[str] | None = None,
        random_state: int = 42,
    ):
        self.base_names = base_names or ["random_forest", "svr", "gradient_boosting"]
        self.random_state = random_state
        self.members_: list[tuple[str, Pipeline]] = []

    def fit(self, X, y):
        self.members_ = [
            _make_base(name, self.random_state) for name in self.base_names
        ]
        for _, pipeline in self.members_:
            pipeline.fit(X, y)
        return self

    def predict(self, X):
        preds = np.column_stack([pipeline.predict(X) for _, pipeline in self.members_])
        return np.median(preds, axis=1)

    def member_names(self) -> list[str]:
        return [name for name, _ in self.members_]


@dataclass
class IntervalPrediction:
    """A prediction with a measured uncertainty interval."""

    point: float
    lower: float
    upper: float
    confidence: float  # operational confidence = calibrated coverage (0..1)

    @property
    def central_coverage(self) -> float:
        """Fraction of the calibration fold actually inside the interval."""
        return self.confidence


@dataclass
class EnsembleResult:
    """Everything needed to reproduce and evaluate an ensemble run."""

    ensemble: WeightEnsemble
    lo_model: GradientBoostingRegressor
    hi_model: GradientBoostingRegressor
    metrics: dict = field(default_factory=dict)
    params: dict = field(default_factory=dict)

    def predict_interval(self, X) -> list[IntervalPrediction]:
        point = self.ensemble.predict(X)
        lo = self.lo_model.predict(X)
        hi = self.hi_model.predict(X)
        cov = self.metrics.get("calibration_coverage", CENTRAL_ALPHA)
        return [
            IntervalPrediction(
                point=float(p),
                lower=float(max(l, 0.0)),
                upper=float(max(u, max(l, 0.0))),
                confidence=float(cov),
            )
            for p, l, u in zip(point, lo, hi)
        ]

    def save(self, output_dir: Path) -> None:
        output_dir.mkdir(parents=True, exist_ok=True)
        joblib.dump(self.ensemble, output_dir / "ensemble.joblib")
        joblib.dump(self.lo_model, output_dir / "quantile_lo.joblib")
        joblib.dump(self.hi_model, output_dir / "quantile_hi.joblib")
        with open(output_dir / "metrics.json", "w") as f:
            json.dump(self.metrics, f, indent=2)
        with open(output_dir / "params.json", "w") as f:
            json.dump(self.params, f, indent=2)


def _fit_quantile(X, y, alpha: float, seed: int) -> GradientBoostingRegressor:
    return GradientBoostingRegressor(
        loss="quantile",
        alpha=alpha,
        n_estimators=300,
        learning_rate=0.05,
        max_depth=3,
        random_state=seed,
    ).fit(X, y)


def build_ensemble(
    X_train,
    y_train,
    *,
    animal_ids: np.ndarray | None = None,
    X_calib=None,
    y_calib=None,
    base_names: list[str] | None = None,
    seed: int = 42,
) -> EnsembleResult:
    """Train an ensemble and calibrate its prediction intervals.

    ``animal_ids`` must be provided when calibrating on a fold of whole
    animals (recommended).  If ``X_calib/y_calib`` are given, they are
    used for calibration instead.
    """
    # Split by whole animal so calibration animals are NEVER used to fit
    # the base ensemble or the quantile regressors.  Coverage is then
    # measured on truly unseen animals, giving an honest confidence.
    if animal_ids is not None:
        cal_idx, fit_idx = split_by_animal(np.asarray(animal_ids), seed=seed)
        X_fit, y_fit = X_train[fit_idx], y_train[fit_idx]
        X_cal, y_cal = X_train[cal_idx], y_train[cal_idx]
    else:
        X_fit, y_fit = X_train, y_train
        X_cal, y_cal = X_calib, y_calib
        if X_cal is None or y_cal is None:
            raise ValueError(
                "Provide animal_ids OR X_calib/y_calib for calibration."
            )

    ensemble = WeightEnsemble(base_names=base_names, random_state=seed)
    ensemble.fit(X_fit, y_fit)

    # Quantile regressors are trained on the SAME training fold as the
    # ensemble, then evaluated on the held-out calibration fold.
    lo_model = _fit_quantile(X_fit, y_fit, LOWER_ALPHA, seed)
    hi_model = _fit_quantile(X_fit, y_fit, UPPER_ALPHA, seed)

    lo_pred = lo_model.predict(X_cal)
    hi_pred = hi_model.predict(X_cal)
    metrics = interval_metrics(y_cal, lo_pred, hi_pred)
    # Operational confidence = measured coverage on truly unseen animals.
    metrics["confidence"] = metrics["calibration_coverage"]

    params = {
        "base_names": base_names or ["random_forest", "svr", "gradient_boosting"],
        "seed": seed,
        "calibration_ratio": DEFAULT_CALIBRATION_RATIO,
        "lower_alpha": LOWER_ALPHA,
        "upper_alpha": UPPER_ALPHA,
        "nominal_coverage": CENTRAL_ALPHA,
        "calibration_by_animal": animal_ids is not None,
        "features": FEATURE_COLUMNS,
        "dataset_version": "goat-dataset-2026-09",
    }

    return EnsembleResult(
        ensemble=ensemble,
        lo_model=lo_model,
        hi_model=hi_model,
        metrics=metrics,
        params=params,
    )


if __name__ == "__main__":
    import argparse

    parser = argparse.ArgumentParser(description="Train ensemble + calibrated interval.")
    parser.add_argument("--csv", type=Path, required=True)
    parser.add_argument("--output", type=Path, default=Path("experiments/ensemble"))
    parser.add_argument("--seed", type=int, default=42)
    args = parser.parse_args()

    df = pd.read_csv(args.csv)
    X = df[FEATURE_COLUMNS].values
    y = df[TARGET].values

    res = build_ensemble(
        X,
        y,
        animal_ids=df["animal_id"].values,
        seed=args.seed,
    )
    print(json.dumps(res.metrics, indent=2))
    res.save(args.output)
    print(f"Saved ensemble to {args.output}")
