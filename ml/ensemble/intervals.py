"""Pure-numpy helpers for honest prediction intervals.

Kept dependency-free (numpy only) so the uncertainty logic can be unit
tested without sk-learn installed.
"""

from __future__ import annotations

import numpy as np

# Quantile levels for the lower/upper bounds (nominal central coverage 0.80).
LOWER_ALPHA = 0.10
UPPER_ALPHA = 0.90
CENTRAL_ALPHA = UPPER_ALPHA - LOWER_ALPHA

# Fraction of animals held out to calibrate the prediction intervals.
DEFAULT_CALIBRATION_RATIO = 0.20


def split_by_animal(
    animal_ids: np.ndarray,
    ratio: float = DEFAULT_CALIBRATION_RATIO,
    seed: int = 42,
) -> tuple[np.ndarray, np.ndarray]:
    """Split by *animal* into (calibration_idxs, training_idxs).

    Whole animals are assigned to one side, so no animal leaks between
    calibration and training.
    """
    rng = np.random.default_rng(seed)
    unique = np.unique(animal_ids)
    rng.shuffle(unique)
    n_cal = max(1, int(round(len(unique) * ratio)))
    calib_animals = set(unique[:n_cal])
    calib_mask = np.array([a in calib_animals for a in animal_ids])
    return np.where(calib_mask)[0], np.where(~calib_mask)[0]


def interval_metrics(y_true: np.ndarray, lo: np.ndarray, hi: np.ndarray) -> dict:
    """Evaluate a prediction interval.

    PICP = Prediction Interval Coverage Probability (measured coverage).
    MPIW = Mean Prediction Interval Width (in kg).
    Pinball = mean quantile loss; smaller = sharper.
    """
    y_true = np.asarray(y_true, dtype=float)
    lo = np.asarray(lo, dtype=float)
    hi = np.asarray(hi, dtype=float)

    inside = (y_true >= lo) & (y_true <= hi)
    picp = float(np.mean(inside))
    mpiw = float(np.mean(hi - lo))
    sharpness_pinball = float(
        0.5 * np.mean(np.maximum(y_true - lo, 0) + np.maximum(hi - y_true, 0))
    )
    return {
        "nominal_coverage": CENTRAL_ALPHA,
        "calibration_coverage": round(picp, 4),
        "mpiw_kg": round(mpiw, 4),
        "pinball": round(sharpness_pinball, 4),
        "n": int(len(y_true)),
    }
