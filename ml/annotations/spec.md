# Annotation specification

Each capture directory produces one annotation JSON per photo.

## Example

```json
{
  "capture_id": "GOAT-0001-C01",
  "animal_id": "GOAT-0001",
  "image": "GOAT-0001-C01.jpg",
  "image_width": 1920,
  "image_height": 1080,
  "ground_truth": {
    "real_weight_kg": 43.1,
    "bcs": 3
  },
  "detection": {
    "bbox": [210.0, 140.0, 1250.0, 820.0],
    "confidence": 0.92
  },
  "segmentation": {
    "mask_path": "GOAT-0001-C01_mask.png",
    "iou_gt": null
  },
  "landmarks": {
    "HEAD":     [320, 400, 0.95],
    "NECK":     [600, 360, 0.94],
    "WITHERS":  [800, 220, 0.97],
    "BACK":     [1000, 260, 0.96],
    "RUMP":     [1280, 300, 0.96],
    "CHEST":    [760, 520, 0.90],
    "FRONT_LEG":[720, 900, 0.93],
    "HIND_LEG": [1260, 920, 0.94],
    "HOOF":     [1250, 1000, 0.95],
    "TAIL_BASE":[1290, 380, 0.93]
  },
  "calibration": {
    "method": "marker_aruco_id14",
    "marker_width_px": 620,
    "real_width_cm": 30.0,
    "cm_per_pixel": 0.048387
  },
  "morphometrics": {
    "body_length_cm": 78.2,
    "withers_height_cm": 71.4,
    "rump_height_cm": 68.9,
    "chest_depth_cm": 32.5,
    "chest_width_cm": 18.3,
    "rump_width_cm": 12.1,
    "rump_length_cm": 22.7,
    "paw_height_cm": 16.2,
    "body_area_cm2": 4100.0,
    "body_aspect_ratio": 1.10
  },
  "quality": {
    "lighting": "sunlight",
    "environment": "corral",
    "view": "side",
    "distance": "medium",
    "camera": "phone-3",
    "capture_date": "2026-09-07",
    "sharpness_score": 0.94,
    "overall_quality": "accepted"
  }
}
```

## Landmark coordinate format

Landmarks are stored as `[x, y, confidence]` in pixel coordinates
(origin at top-left of the image).

Fields:

| Field          | Type      | Description                        |
|----------------|-----------|------------------------------------|
| `x`            | number    | Horizontal pixel coordinate        |
| `y`            | number    | Vertical pixel coordinate          |
| `confidence`   | number 0-1| Model confidence for this landmark  |

## Validation rules

- A capture with landmarks missing `WITHERS`, `HOOF`, or `TAIL_BASE`
  must be rejected from training data.
- Ground truth `real_weight_kg` must come from a scale.
- Image-based measurements (centimeters) require a valid calibration entry.