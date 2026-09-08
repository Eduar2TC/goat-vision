"""Body-weight reference model based on published zoometric equations.

This is the out-of-the-box fallback used when NO locally-trained model is
available. It must never be presented as a calibrated producer of GoatVision;
the weights come from a peer-reviewed study and the reported uncertainty is
the study's residual standard error, not a PICP measured on our pipeline.

Reference:
  Paredes-Chocce, J. F., et al. (2025). Predicting body weight using body
  measurements in Peruvian creole goats. Biodiversitas 26(7):3193-3198.
  DOI: 10.13057/biodiv/d260710. n = 356.

Selected model (stepwise, AIC 928.29, r2 = 0.644):
  BW (kg) = -45.642 + 0.71*TG + 0.21*RH + 0.99*RW        (RSE = 6.305 kg)

  TG = thoracic girth (cm), RH = rump height (cm), RW = rump width (cm).

GoatVision does not measure thoracic girth (lateral view, linear measures),
so TG is ESTIMATED as the perimeter of the chest cross-section using the
Ramanujan approximation of an ellipse with semi-axes D/2 (chest depth) and
CW/2 (chest width). Sanity check against the study means
(TG 84.97, D ~34, CW 18.98) is enforced by the test suite.
"""

from __future__ import annotations

import math

MODEL_VERSION = "ref-paredes-chocce-2025"
DATASET_VERSION = "biodiv-d260710"
R2_ADJUSTED = 0.644
RSE_KG = 6.305
N_SAMPLES = 356

# Study ranges (cm) used for input validation.
STUDY_RANGES = {
    # Chest depth is not published; the range below is the ellipse-girth fit
    # that reproduces the published thoracic-girth span [65, 103] cm.
    "chest_depth_cm": (22.0, 45.0),
    "chest_width_cm": (12.0, 27.0),
    "rump_height_cm": (51.0, 89.2),
    "rump_width_cm": (8.7, 27.0),
}

# 80% two-sided normal quantile, applied to RSE for the prediction interval.
_P80_Z = 1.2816


def estimate_thoracic_girth(chest_depth_cm: float, chest_width_cm: float) -> float:
    """Perimeter of the chest cross-section via Ramanujan ellipse estimate.

    Semi-axes: a = depth/2 (vertical), b = width/2 (horizontal).
    """
    a = chest_depth_cm / 2.0
    b = chest_width_cm / 2.0
    return math.pi * (3.0 * (a + b) - math.sqrt((3.0 * a + b) * (a + 3.0 * b)))


def predict_weight(
    chest_depth_cm: float,
    chest_width_cm: float,
    rump_height_cm: float,
    rump_width_cm: float,
) -> dict:
    """Predict body weight (kg) from the Paredes-Chocce stepwise equation.

    Returns a dict with the point estimate, an 80% interval based on the
    published RSE, and the model-version tag. No dictionary is polymorphic.
    """
    features = {
        "chest_depth_cm": chest_depth_cm,
        "chest_width_cm": chest_width_cm,
        "rump_height_cm": rump_height_cm,
        "rump_width_cm": rump_width_cm,
    }
    errors = validate_features(**features)
    if errors:
        return {"valid": False, "errors": errors, "estimated_weight_kg": None}

    tg = estimate_thoracic_girth(chest_depth_cm, chest_width_cm)
    estimated = -45.642 + 0.71 * tg + 0.21 * rump_height_cm + 0.99 * rump_width_cm
    half_interval = _P80_Z * RSE_KG
    return {
        "valid": True,
        "errors": [],
        "estimated_weight_kg": round(estimated, 3),
        "lower_bound_kg": round(estimated - half_interval, 3),
        "upper_bound_kg": round(estimated + half_interval, 3),
        "confidence": R2_ADJUSTED,
        "thoracic_girth_cm": round(tg, 3),
        "model_version": MODEL_VERSION,
        "dataset_version": DATASET_VERSION,
        "n_samples": N_SAMPLES,
        "rse_kg": RSE_KG,
    }


def validate_features(
    chest_depth_cm: float,
    chest_width_cm: float,
    rump_height_cm: float,
    rump_width_cm: float,
) -> list[str]:
    """Range-check inputs against the study's observed ranges."""
    errors = []
    values = {
        "chest_depth_cm": chest_depth_cm,
        "chest_width_cm": chest_width_cm,
        "rump_height_cm": rump_height_cm,
        "rump_width_cm": rump_width_cm,
    }
    for name, value in values.items():
        if value <= 0:
            errors.append(f"{name} must be positive (got {value})")
            continue
        lo, hi = STUDY_RANGES[name]
        if not (lo <= value <= hi):
            errors.append(
                f"{name} out of reference range [{lo}, {hi}] cm (got {value})"
            )
    return errors