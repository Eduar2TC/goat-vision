"""Data augmentation for the computer-vision pipeline (spec section 26).

Augmentation is applied *after* annotation so annotations (bounding box,
landmarks and calibration marker) can be transformed together.  Rules:

- Only *geometric* transforms that keep anatomical proportions are used
  (rotation, uniform scale, crop, perspective with mild distortion,
  horizontal flip).  No non-uniform scaling/stretching, which would
  falsify the very morphometric ratios the model learns from.
- Photometric transforms (brightness, contrast, blur, noise) are used
  for robustness to capture conditions.
- When a marker-anchored calibration is present, a known scale is
  preserved by transforming the marker box with the same geometry, so
  ``cm_per_pixel`` stays valid.

Each function returns ``(image, bbox, landmarks)`` so annotations move
with the pixels.  ``bbox`` is ``[x1, y1, x2, y2]`` and ``landmarks`` is a
list of ``(x, y)`` pixel coordinates.
"""

from __future__ import annotations

import random
from dataclasses import dataclass

import cv2
import numpy as np


@dataclass
class AugmentResult:
    image: np.ndarray
    bbox: np.ndarray  # [x1, y1, x2, y2]
    landmarks: np.ndarray  # (N, 2) x,y
    # Aruco/marker corners (4,2) in the original image, if present.
    marker_corners: np.ndarray | None = None


def _clip_bbox(bbox: np.ndarray, w: int, h: int) -> np.ndarray:
    x1 = float(np.clip(bbox[0], 0, w - 1))
    y1 = float(np.clip(bbox[1], 0, h - 1))
    x2 = float(np.clip(bbox[2], 0, w - 1))
    y2 = float(np.clip(bbox[3], 0, h - 1))
    return np.array([x1, y1, x2, y2])


def _apply_homography(
    image: np.ndarray,
    H: np.ndarray,
    bbox: np.ndarray,
    landmarks: np.ndarray,
    marker_corners: np.ndarray | None,
    out_size: tuple[int, int] | None = None,
) -> AugmentResult:
    h, w = image.shape[:2]
    out = cv2.warpPerspective(image, H, (w, h))
    out_w = out.shape[1]
    out_h = out.shape[0]

    def _transform_points(points: np.ndarray) -> np.ndarray:
        if points.size == 0:
            return points
        pts = points.reshape(-1, 1, 2).astype(np.float32)
        transformed = cv2.perspectiveTransform(pts, H).reshape(-1, 2)
        return transformed

    new_bbox = _transform_points(
        np.array([[bbox[0], bbox[1]], [bbox[2], bbox[3]]])
    ).reshape(-1)
    new_landmarks = _transform_points(np.asarray(landmarks, dtype=float))
    new_marker = (
        _transform_points(np.asarray(marker_corners, dtype=float))
        if marker_corners is not None
        else None
    )

    return AugmentResult(
        image=out,
        bbox=_clip_bbox(new_bbox, out_w, out_h),
        landmarks=new_landmarks,
        marker_corners=new_marker,
    )


def rotate_max_angle(rng: random.Random, max_deg: float = 8.0) -> float:
    return rng.uniform(-max_deg, max_deg)


def rotate(
    image: np.ndarray,
    bbox: np.ndarray,
    landmarks: np.ndarray,
    angle_deg: float,
    marker_corners: np.ndarray | None = None,
) -> AugmentResult:
    """Small rotation (<=~8 deg) keeps proportions intact."""
    h, w = image.shape[:2]
    center = (w / 2, h / 2)
    M = cv2.getRotationMatrix2D(center, angle_deg, 1.0)
    H = np.vstack([M, [0, 0, 1]])
    return _apply_homography(image, H, bbox, landmarks, marker_corners)


def uniform_scale(
    image: np.ndarray,
    bbox: np.ndarray,
    landmarks: np.ndarray,
    scale: float,
) -> AugmentResult:
    """Uniform scale (same in x and y) preserves proportions."""
    h, w = image.shape[:2]
    M = cv2.getRotationMatrix2D((w / 2, h / 2), 0, scale)
    H = np.vstack([M, [0, 0, 1]])
    return _apply_homography(image, H, bbox, landmarks, None)


def perspective(
    image: np.ndarray,
    bbox: np.ndarray,
    landmarks: np.ndarray,
    strength: float = 0.02,
    marker_corners: np.ndarray | None = None,
    rng: random.Random | None = None,
) -> AugmentResult:
    """Mild perspective distortion (strength << 1) for viewpoint variety.

    This does not stretch a single line segment, so silhouette ratios
    stay approximately valid while matching real capture variability.
    """
    rng = rng or random.Random()
    h, w = image.shape[:2]
    dx = w * strength
    dy = h * strength
    src = np.float32([[0, 0], [w, 0], [w, h], [0, h]])
    dst = np.float32(
        [
            [rng.uniform(-dx, dx), rng.uniform(-dy, dy)],
            [w + rng.uniform(-dx, dx), rng.uniform(-dy, dy)],
            [w + rng.uniform(-dx, dx), h + rng.uniform(-dy, dy)],
            [rng.uniform(-dx, dx), h + rng.uniform(-dy, dy)],
        ]
    )
    H, _ = cv2.findHomography(src, dst)
    return _apply_homography(image, H, bbox, landmarks, marker_corners)


def flip_horizontal(
    image: np.ndarray,
    bbox: np.ndarray,
    landmarks: np.ndarray,
    marker_corners: np.ndarray | None = None,
) -> AugmentResult:
    """Horizontal flip (mirror) is proportion-preserving."""
    w = image.shape[1]
    flipped = cv2.flip(image, 1)
    new_landmarks = np.asarray(landmarks, dtype=float).copy()
    new_landmarks[:, 0] = w - 1 - new_landmarks[:, 0]
    x1, y1, x2, y2 = bbox
    new_bbox = np.array([w - 1 - x2, y1, w - 1 - x1, y2])
    new_marker = None
    if marker_corners is not None:
        mc = np.asarray(marker_corners, dtype=float).copy()
        mc[:, 0] = w - 1 - mc[:, 0]
        new_marker = mc
    return AugmentResult(
        image=flipped,
        bbox=_clip_bbox(new_bbox, w, image.shape[0]),
        landmarks=new_landmarks,
        marker_corners=new_marker,
    )


def adjust_brightness_contrast(image: np.ndarray, brightness: float, contrast: float) -> np.ndarray:
    alpha = contrast
    beta = brightness
    return np.clip(image.astype(np.float32) * alpha + beta, 0, 255).astype(np.uint8)


def add_gaussian_noise(image: np.ndarray, sigma: float) -> np.ndarray:
    noise = np.random.normal(0, sigma, image.shape).astype(np.float32)
    return np.clip(image.astype(np.float32) + noise, 0, 255).astype(np.uint8)


def blur(image: np.ndarray, ksize: int) -> np.ndarray:
    if ksize < 3:
        return image
    k = ksize if ksize % 2 == 1 else ksize + 1
    return cv2.GaussianBlur(image, (k, k), 0)


def random_crop(
    image: np.ndarray,
    bbox: np.ndarray,
    landmarks: np.ndarray,
    margin_ratio: float = 0.10,
    rng: random.Random | None = None,
) -> AugmentResult:
    """Crop that keeps the whole goat plus a margin inside the frame.

    The crop window is always large enough to contain the object plus a
    margin, then shifted randomly within that slack, so a landmark never
    leaves the frame and body proportions are unaffected.
    """
    rng = rng or random.Random()
    h, w = image.shape[:2]
    x1, y1, x2, y2 = bbox
    obj_w = x2 - x1
    obj_h = y2 - y1
    margin_w = obj_w * margin_ratio
    margin_h = obj_h * margin_ratio

    min_x = max(0.0, x1 - margin_w)
    max_x = min(float(w), x2 + margin_w)
    min_y = max(0.0, y1 - margin_h)
    max_y = min(float(h), y2 + margin_h)

    # Ensure crop window fits inside the image and is at least as large
    # as the object bbox.
    cx = (min_x + max_x) / 2
    cy = (min_y + max_y) / 2
    crop_w = max_x - min_x
    crop_h = max_y - min_y

    # Randomly shift within the available slack along x.
    slack_x = max(0.0, (w - crop_w) / 2)
    slack_y = max(0.0, (h - crop_h) / 2)
    shift_x = rng.uniform(-slack_x, slack_x)
    shift_y = rng.uniform(-slack_y, slack_y)

    cx = min(max(cx + shift_x, crop_w / 2), w - crop_w / 2)
    cy = min(max(cy + shift_y, crop_h / 2), h - crop_h / 2)
    left = int(round(cx - crop_w / 2))
    top = int(round(cy - crop_h / 2))
    left = max(0, min(left, w - int(crop_w)))
    top = max(0, min(top, h - int(crop_h)))

    crop = image[top: top + int(crop_h), left: left + int(crop_w)]
    new_landmarks = np.asarray(landmarks, dtype=float).copy()
    new_landmarks[:, 0] -= left
    new_landmarks[:, 1] -= top
    new_bbox = np.array([x1 - left, y1 - top, x2 - left, y2 - top])
    return AugmentResult(
        image=crop,
        bbox=_clip_bbox(new_bbox, crop.shape[1], crop.shape[0]),
        landmarks=new_landmarks,
        marker_corners=None,
    )


@dataclass
class Augmenter:
    """Random augmentation policy that keeps anatomical proportions.

    Geometric ops (rotation, uniform resize, perspective, flip) transform
    the annotations together with the image.  Photometric ops are applied
    in-place because they do not move pixels.
    """

    prob_rotate: float = 0.5
    max_rotation_deg: float = 8.0
    prob_scale: float = 0.5
    scale_range: tuple[float, float] = (0.9, 1.1)
    prob_perspective: float = 0.3
    perspective_strength: float = 0.02
    prob_flip: bool = True
    prob_photometric: float = 0.6
    brightness_range: tuple[float, float] = (-40, 40)
    contrast_range: tuple[float, float] = (0.8, 1.2)
    noise_sigma_range: tuple[float, float] = (0.0, 6.0)
    blur_max: int = 3

    def __call__(
        self,
        image: np.ndarray,
        bbox: np.ndarray,
        landmarks: np.ndarray,
        marker_corners: np.ndarray | None = None,
        rng: random.Random | None = None,
    ) -> AugmentResult:
        rng = rng or random.Random()
        res = AugmentResult(
            image=image,
            bbox=np.asarray(bbox, dtype=float),
            landmarks=np.asarray(landmarks, dtype=float),
            marker_corners=(
                np.asarray(marker_corners, dtype=float)
                if marker_corners is not None
                else None
            ),
        )

        if self.prob_flip and rng.random() < 0.5:
            res = flip_horizontal(res.image, res.bbox, res.landmarks, res.marker_corners)

        if rng.random() < self.prob_rotate:
            ang = rotate_max_angle(rng, self.max_rotation_deg)
            res = rotate(res.image, res.bbox, res.landmarks, ang, res.marker_corners)

        if rng.random() < self.prob_scale:
            s = rng.uniform(*self.scale_range)
            res = uniform_scale(res.image, res.bbox, res.landmarks, s)

        if rng.random() < self.prob_perspective:
            res = perspective(
                res.image, res.bbox, res.landmarks, self.perspective_strength,
                res.marker_corners, rng,
            )

        if rng.random() < self.prob_photometric:
            img = res.image
            if rng.random() < 0.5:
                img = adjust_brightness_contrast(
                    img,
                    rng.uniform(*self.brightness_range),
                    rng.uniform(*self.contrast_range),
                )
            sigma = rng.uniform(*self.noise_sigma_range)
            if sigma > 1.0:
                img = add_gaussian_noise(img, sigma)
            if self.blur_max >= 3 and rng.random() < 0.3:
                img = blur(img, rng.randint(3, self.blur_max))
            res.image = img

        # Keep bbox/labels consistent; marker corners (if still present)
        # may have been reduced to None by geometric ops that clip.
        return res


if __name__ == "__main__":
    rng = random.Random(7)
    sample_img = np.full((480, 640, 3), 128, dtype=np.uint8)
    sample_bbox = np.array([180.0, 120.0, 460.0, 400.0])
    sample_lm = np.array([[200, 150], [300, 160], [400, 180], [300, 380]])
    aug = Augmenter()
    out = aug(sample_img, sample_bbox, sample_lm, rng=rng)
    print("out shape:", out.image.shape)
    print("bbox:", out.bbox)
    print("landmarks:", out.landmarks.tolist())
