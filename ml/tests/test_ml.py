"""Unit tests for the ML pipeline helpers.

`test_intervals_*` only needs numpy and therefore runs everywhere.
`test_ensemble_*` / `test_stratify_*` need sk-learn / pandas and are
skipped when those are not installed.
"""

import os
import random
import sys
import unittest

import numpy as np

PY_ROOT = os.path.dirname(os.path.dirname(os.path.abspath(__file__)))
if PY_ROOT not in sys.path:
    sys.path.insert(0, PY_ROOT)

try:
    from ensemble.intervals import (
        CENTRAL_ALPHA,
        DEFAULT_CALIBRATION_RATIO,
        interval_metrics,
        split_by_animal,
    )
except Exception as exc:  # pragma: no cover - sk-learn may be missing
    raise RuntimeError(f"Could not import intervals: {exc}")

from literature.reference_weight import (  # noqa: E402  (numpy-only)
    estimate_thoracic_girth,
    predict_weight,
    validate_features,
)


class TestSplitByAnimal(unittest.TestCase):
    def test_no_leak_between_sets(self):
        ids = np.repeat(np.arange(60), 4)
        cal, fit = split_by_animal(ids, seed=42)
        self.assertEqual(len(set(ids[cal]) & set(ids[fit])), 0)

    def test_partition_ratio(self):
        ids = np.repeat(np.arange(100), 3)
        cal, fit = split_by_animal(ids, ratio=0.20, seed=7)
        n_cal = len(set(ids[cal]))
        self.assertAlmostEqual(n_cal / 100, 0.20, delta=1e-9)

    def test_covers_all_indexes(self):
        ids = np.array([1, 1, 2, 2, 3, 3, 4, 4])
        cal, fit = split_by_animal(ids, seed=0)
        self.assertEqual(sorted(np.concatenate([cal, fit]).tolist()),
                         list(range(len(ids))))

    def test_default_ratio_constant(self):
        self.assertEqual(DEFAULT_CALIBRATION_RATIO, 0.20)


class TestIntervalMetrics(unittest.TestCase):
    def test_full_coverage(self):
        yt = np.array([30.0, 40.0, 50.0, 60.0])
        lo = np.array([28.0, 37.0, 48.0, 52.0])
        hi = np.array([33.0, 44.0, 53.0, 62.0])
        m = interval_metrics(yt, lo, hi)
        self.assertEqual(m["n"], 4)
        self.assertEqual(m["calibration_coverage"], 1.0)
        self.assertAlmostEqual(m["mpiw_kg"], 6.75)
        self.assertEqual(m["nominal_coverage"], CENTRAL_ALPHA)
        self.assertGreater(m["pinball"], 0.0)

    def test_partial_coverage(self):
        yt = np.array([30.0, 40.0])
        lo = np.array([28.0, 50.0])  # second point outside
        hi = np.array([33.0, 60.0])
        m = interval_metrics(yt, lo, hi)
        self.assertEqual(m["calibration_coverage"], 0.5)

    def test_nominal_coverage_constant(self):
        self.assertAlmostEqual(CENTRAL_ALPHA, 0.80, delta=1e-9)


try:
    from ensemble.ensemble import WeightEnsemble, build_ensemble

    HAVE_SKLEARN = True
except ImportError:
    HAVE_SKLEARN = False

try:
    from evaluation.stratify import _age_band, _weight_band, evaluate_by_subgroup

    HAVE_PANDAS = True
except ImportError:
    HAVE_PANDAS = False

try:
    from preprocessing.augmentation import (
        Augmenter,
        add_gaussian_noise,
        adjust_brightness_contrast,
        flip_horizontal,
        uniform_scale,
    )

    import cv2

    HAVE_CV2 = True
except ImportError:
    HAVE_CV2 = False


@unittest.skipUnless(HAVE_SKLEARN, "scikit-learn not installed")
class TestEnsemble(unittest.TestCase):
    def test_ensemble_predicts_median(self):
        rng = np.random.default_rng(0)
        X = rng.uniform(55, 95, (200, 8))
        y = X[:, 0] * 0.6 + X[:, 1] * 0.4 + rng.normal(0, 4, 200)
        animals = np.repeat(np.arange(50), 4)
        res = build_ensemble(X, y, animal_ids=animals, seed=1)
        preds = res.predict_interval(X[:10])
        self.assertEqual(len(preds), 10)
        for p in preds:
            self.assertLessEqual(p.lower, p.point)
            self.assertLessEqual(p.point, p.upper)
            self.assertGreaterEqual(p.confidence, 0.0)
            self.assertLessEqual(p.confidence, 1.0)


@unittest.skipUnless(HAVE_PANDAS, "pandas not installed")
class TestBanding(unittest.TestCase):
    def test_age_bands(self):
        self.assertEqual(_age_band(0), "0-6m")
        self.assertEqual(_age_band(5), "0-6m")
        self.assertEqual(_age_band(6), "6-12m")
        self.assertEqual(_age_band(24), "24m+")

    def test_weight_bands(self):
        self.assertEqual(_weight_band(19), "<20kg")
        self.assertEqual(_weight_band(20), "20-35kg")
        self.assertEqual(_weight_band(54), "35-55kg")
        self.assertEqual(_weight_band(55), "55kg+")


@unittest.skipUnless(HAVE_CV2, "opencv-python not installed")
class TestAugmentation(unittest.TestCase):
    """Geometric transforms must keep annotations aligned with the pixels.

    The bbox is [x1, y1, x2, y2]; landmarks are (N, 2) pixel coords.
    """

    @classmethod
    def setUpClass(cls):
        rng = np.random.default_rng(0)
        cls.img = rng.integers(0, 256, (200, 300, 3), dtype=np.uint8)
        cls.bbox = np.array([100.0, 60.0, 220.0, 180.0])  # w=120, h=120
        cls.lm = np.array([[120.0, 80.0], [200.0, 90.0], [180.0, 160.0]])

    def _ratio(self, bbox):
        return (bbox[2] - bbox[0]) / max((bbox[3] - bbox[1]), 1e-6)

    def test_uniform_scale_identity_ratio(self):
        # scale == 1 is the identity: bbox and landmarks unchanged, and the
        # width/height ratio is preserved for any scale factor.
        res = uniform_scale(self.img, self.bbox, self.lm, scale=1.0)
        np.testing.assert_allclose(res.bbox, self.bbox, atol=2.0)
        np.testing.assert_allclose(res.landmarks, self.lm, atol=2.0)
        self.assertAlmostEqual(self._ratio(res.bbox), self._ratio(self.bbox))

    def test_uniform_scale_preserves_proportions(self):
        # Uniform scale must keep the bbox aspect ratio (proportions intact),
        # unlike non-uniform scaling which would falsify morphometrics.
        res = uniform_scale(self.img, self.bbox, self.lm, scale=1.12)
        self.assertAlmostEqual(
            self._ratio(res.bbox), self._ratio(self.bbox), delta=0.05
        )
        # Landmarks scale about the image centre at the same factor.
        h, w = self.img.shape[:2]
        cx, cy = w / 2.0, h / 2.0
        for (x, y), (nx, ny) in zip(self.lm, res.landmarks):
            self.assertAlmostEqual(nx, cx + 1.12 * (x - cx), delta=4.0)
            self.assertAlmostEqual(ny, cy + 1.12 * (y - cy), delta=4.0)

    def test_flip_horizontal_reflects_x(self):
        w = self.img.shape[1]
        res = flip_horizontal(self.img, self.bbox, self.lm)
        for (x, y), (nx, ny) in zip(self.lm, res.landmarks):
            self.assertAlmostEqual(nx, w - 1 - x, delta=1.0)
            self.assertAlmostEqual(ny, y, delta=1.0)
        # bbox x coords reflect too.
        self.assertAlmostEqual(res.bbox[0], w - 1 - self.bbox[2], delta=1.0)
        self.assertAlmostEqual(res.bbox[2], w - 1 - self.bbox[0], delta=1.0)
        self.assertAlmostEqual(res.bbox[1], self.bbox[1], delta=1.0)
        self.assertAlmostEqual(res.bbox[3], self.bbox[3], delta=1.0)

    def test_photometric_identity(self):
        out = adjust_brightness_contrast(self.img, brightness=0.0, contrast=1.0)
        np.testing.assert_array_equal(out, self.img)
        noisy = add_gaussian_noise(self.img, sigma=0.0)
        np.testing.assert_array_equal(noisy, self.img)

    def test_augmenter_disabled_is_identity(self):
        aug = Augmenter(
            prob_rotate=0.0,
            prob_scale=0.0,
            prob_perspective=0.0,
            prob_flip=False,
            prob_photometric=0.0,
        )
        res = aug(self.img, self.bbox, self.lm, rng=random.Random(1))
        np.testing.assert_array_equal(res.image, self.img)
        np.testing.assert_allclose(res.bbox, self.bbox, atol=1e-6)
        np.testing.assert_allclose(res.landmarks, self.lm, atol=1e-6)


class TestReferenceWeight(unittest.TestCase):
    """Reference (literature) weight predictor, pure numpy."""

    def test_ellipse_girth_reproduces_study_mean(self):
        # Paper means: TG = 84.97 cm with CW = 18.98 cm; the ellipse fit sets
        # chest depth so the Ramanujan perimeter matches the published girth.
        tg = estimate_thoracic_girth(34.0, 18.98)
        self.assertAlmostEqual(tg, 84.97, delta=0.5)

    def test_ellipse_girth_spans_study_range(self):
        lo = estimate_thoracic_girth(22.3, 12.0)
        hi = estimate_thoracic_girth(44.1, 27.0)
        self.assertGreaterEqual(lo, 55.0)
        self.assertLessEqual(hi, 120.0)

    def test_prediction_matches_study_range_at_means(self):
        res = predict_weight(34.0, 18.98, 72.61, 17.17)
        self.assertTrue(res["valid"])
        # BW mean from paper is 48.06 kg; formula gives ~46.9 (within RSE).
        self.assertAlmostEqual(res["estimated_weight_kg"], 46.9, delta=1.5)
        self.assertEqual(res["model_version"], "ref-paredes-chocce-2025")
        self.assertEqual(res["confidence"], 0.644)

    def test_interval_is_symmetric_and_positive(self):
        res = predict_weight(31.0, 17.0, 68.0, 15.0)
        half = (res["upper_bound_kg"] - res["lower_bound_kg"]) / 2.0
        self.assertAlmostEqual(half, 1.2816 * 6.305, places=3)
        self.assertGreater(res["lower_bound_kg"], 0.0)

    def test_validate_rejects_non_positive_and_out_of_range(self):
        errors = validate_features(0.0, 18.98, 72.61, 17.17)
        self.assertTrue(errors)
        errors = validate_features(34.0, 28.0, 72.61, 17.17)
        self.assertTrue(any("chest_width_cm" in e for e in errors))

    def test_multiline_equation_monotonic_in_girth(self):
        small = predict_weight(24.0, 13.0, 60.0, 11.0)["estimated_weight_kg"]
        big = predict_weight(40.0, 24.0, 80.0, 22.0)["estimated_weight_kg"]
        self.assertGreater(big, small)


if __name__ == "__main__":
    unittest.main()
