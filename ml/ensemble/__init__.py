"""Ensemble weight model with honest prediction intervals.

The MVP spec (section 20) allows an optional ensemble of
Random Forest + SVR + Gradient Boosting.  The science section (21)
requires that we never present a bare point estimate as a precise
measurement.  This package provides:

- ``build_ensemble``/``WeightEnsemble``: a median ensemble of several
  regressors.
- ``split_by_animal``/``interval_metrics``: numpy-only helpers that
  split by whole animal (leakage-free) and measure interval coverage.

The ``intervals`` submodule has no optional dependencies so it can be
imported even where sk-learn is not installed.
"""

from .intervals import (
    CENTRAL_ALPHA,
    DEFAULT_CALIBRATION_RATIO,
    interval_metrics,
    split_by_animal,
)

# The heavy (sk-learn) parts are imported lazily so the numpy-only helpers
# above remain importable anywhere.
def _load_ensemble():
    from .ensemble import WeightEnsemble, build_ensemble  # noqa: PLC0415

    return WeightEnsemble, build_ensemble


__all__ = [
    "split_by_animal",
    "interval_metrics",
    "DEFAULT_CALIBRATION_RATIO",
    "CENTRAL_ALPHA",
]

try:
    WeightEnsemble, build_ensemble = _load_ensemble()
    __all__ += ["WeightEnsemble", "build_ensemble"]
except Exception:  # pragma: no cover - sk-learn missing in some envs
    pass
