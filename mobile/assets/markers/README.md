# GoatVision — Calibration Marker

This directory hosts source patterns for the GoatVision calibration marker.

## Specification

| Property            | Value                          |
|---------------------|--------------------------------|
| Real width          | 30.0 cm                        |
| Real height         | 30.0 cm                        |
| Print size          | A4 (marker centered)           |
| Pattern             | ArUco 4x4_50, dictionary id 14 |
| Detection lib       | OpenCV ArUco / AprilTag        |
| Background          | White with thin black border   |
| Required in frame   | Fully visible, minimal tilt    |

## Usage

1. Print the marker at exact real-world size (30 × 30 cm).
2. Measure to verify the printed size.
3. Place it flat, level, and next to the goat in the same depth plane.

## Generation

The ArUco image is generated with:

```python
import cv2
import cv2.aruco as aruco

dictionary = aruco.getPredefinedDictionary(aruco.DICT_4X4_50)
img = aruco.generateImageMarker(dictionary, 14, 600)
cv2.imwrite("marker_aruco_id14.png", img)
```

TIP: After printing, scan the sheet at 300 DPI and verify the marker
measures exactly 30 cm to account for printer scaling.