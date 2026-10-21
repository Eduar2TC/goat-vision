#!/usr/bin/env python3
"""PoC GoatVision — generador de escenas sintéticas con marcador tag36h11.

Genera las MISMAS imágenes para AprilTag (FFI Dart) y ArUco de OpenCV:
misma cámara, mismos GT de esquinas y de pose. Salida:
poc/apriltag_poc/images/*.png + images/ground_truth.json.

Convenciones:
- El plano del tag coincide con los ejes de la imagen del marcador:
  esquina img (0,0)   -> plano (-S/2, -S/2, 0)
  esquina img (w,0)   -> plano (+S/2, -S/2, 0)
  esquina img (w,h)   -> plano (+S/2, +S/2, 0)
  esquina img (0,h)   -> plano (-S/2, +S/2, 0)
  (X a la derecha, Y hacia abajo, Z hacia la cámara en el frame del tag.)
- GT corners: proyección de esos 4 puntos del plano con K[R|t].
"""
from __future__ import annotations

import json
import math
import random
import sys
from pathlib import Path

import cv2
import numpy as np

OUT_DIR = Path(__file__).resolve().parent.parent / "images"

CANVAS_W, CANVAS_H = 800, 600
FX = FY = 750.0
CX, CY = 400.0, 300.0
K = np.array([[FX, 0, CX], [0, FY, CY], [0, 0, 1]], dtype=np.float64)

TAG_SIDE_M = 0.10          # 10 cm, tamaño real del marcador
MARKER_IMG_PX = 400        # resolución del sprite del marcador antes del warp
N_TRIALS = 4               # repeticiones por condición (semillas fijas)
RNG_SEED = 20261019


def build_marker_sprite(tag_id: int) -> np.ndarray:
    dict_april = cv2.aruco.getPredefinedDictionary(cv2.aruco.DICT_APRILTAG_36H11)
    return cv2.aruco.generateImageMarker(dict_april, tag_id, MARKER_IMG_PX, 1)


def plane_corners(side_m: float) -> np.ndarray:
    h = side_m / 2.0
    # orden de esquinas del sprite: (0,0), (w,0), (w,h), (0,h)
    return np.array([[-h, -h, 0], [h, -h, 0], [h, h, 0], [-h, h, 0]], dtype=np.float64)


def rodrigues_from_euler(yaw_deg: float, pitch_deg: float, roll_deg: float) -> np.ndarray:
    """Rotación cámara<-tag como R = Rz(roll)·Ry(pitch)·Rx(yaw)."""
    y, p, r = (math.radians(a) for a in (yaw_deg, pitch_deg, roll_deg))
    Rx = np.array([[1, 0, 0], [0, math.cos(y), -math.sin(y)], [0, math.sin(y), math.cos(y)]])
    Ry = np.array([[math.cos(p), 0, math.sin(p)], [0, 1, 0], [-math.sin(p), 0, math.cos(p)]])
    Rz = np.array([[math.cos(r), -math.sin(r), 0], [math.sin(r), math.cos(r), 0], [0, 0, 1]])
    return Rz @ Ry @ Rx


def render_scene(
    sprite: np.ndarray,
    R: np.ndarray,
    tvec: np.ndarray,
) -> tuple[np.ndarray, np.ndarray, np.ndarray]:
    """Render del marcador en el lienzo; devuelve (escena, gt_corners_px, rvec)."""
    P = K @ np.hstack([R, tvec.reshape(3, 1)])
    obj = plane_corners(TAG_SIDE_M)
    obj_h = np.hstack([obj, np.ones((4, 1))])
    proj_h = (P @ obj_h.T).T
    proj = (proj_h[:, :2] / proj_h[:, 2:3]).astype(np.float64)

    sprite_corners = np.array(
        [[0, 0], [MARKER_IMG_PX - 1, 0], [MARKER_IMG_PX - 1, MARKER_IMG_PX - 1],
         [0, MARKER_IMG_PX - 1]], dtype=np.float64
    )
    H, _ = cv2.findHomography(sprite_corners.astype(np.float64), proj.astype(np.float64))

    scene = np.full((CANVAS_H, CANVAS_W), 190, dtype=np.uint8)
    # gradiente suave de fondo
    gx = np.linspace(-12, 12, CANVAS_W, dtype=np.float32)
    scene = np.clip(scene.astype(np.int16) + gx.astype(np.int16)[None, :], 0, 255).astype(np.uint8)

    mask = np.ones((MARKER_IMG_PX, MARKER_IMG_PX), dtype=np.uint8) * 255
    warped = cv2.warpPerspective(
        sprite, H, (CANVAS_W, CANVAS_H), flags=cv2.INTER_LINEAR,
        borderMode=cv2.BORDER_CONSTANT, borderValue=190,
    )
    warped_mask = cv2.warpPerspective(
        mask, H, (CANVAS_W, CANVAS_H), flags=cv2.INTER_LINEAR,
        borderMode=cv2.BORDER_CONSTANT, borderValue=0,
    )
    scene[warped_mask > 0] = warped[warped_mask > 0]

    rvec, _ = cv2.Rodrigues(R)
    return scene, proj.astype(np.float64), rvec


def add_gauss_noise(img: np.ndarray, sigma: float, rng: random.Random) -> np.ndarray:
    arr = img.astype(np.float32)
    noise = np.array(
        [[rng.gauss(0, sigma) for _ in range(img.shape[1])] for _ in range(img.shape[0])],
        dtype=np.float32,
    )
    return np.clip(arr + noise, 0, 255).astype(np.uint8)


def occlude(scene: np.ndarray, gt_corners: np.ndarray, frac: float, rng: random.Random) -> np.ndarray:
    """Parche circular aleatorio sobre el marcador, con diámetro ≈ frac del lado."""
    side_px = float(np.mean([
        np.linalg.norm(gt_corners[(i + 1) % 4] - gt_corners[i]) for i in range(4)
    ]))
    radius = (frac * side_px) / 2.0
    # punto aleatorio dentro del quad (interpolación bilineal)
    tx, ty = rng.uniform(0.2, 0.8), rng.uniform(0.2, 0.8)
    top = gt_corners[0] + tx * (gt_corners[1] - gt_corners[0])
    bottom = gt_corners[3] + tx * (gt_corners[2] - gt_corners[3])
    center = top + ty * (bottom - top)
    color = 0 if rng.random() < 0.5 else 255
    out = scene.copy()
    cv2.circle(out, (int(center[0]), int(center[1])), int(radius), color, -1)
    return out


def degrade(scene: np.ndarray, cond: dict, trial: int) -> np.ndarray:
    img = scene
    rng = random.Random(RNG_SEED + trial * 977 + hash(cond["name"]) % 4093)
    if cond.get("noise_sigma"):
        img = add_gauss_noise(img, cond["noise_sigma"], rng)
    if cond.get("blur_k"):
        img = cv2.GaussianBlur(img, (cond["blur_k"], cond["blur_k"]), 0)
    if cond.get("jpeg_q"):
        ok, buf = cv2.imencode(".jpg", img, [int(cv2.IMWRITE_JPEG_QUALITY), cond["jpeg_q"]])
        assert ok
        img = cv2.imdecode(buf, cv2.IMREAD_GRAYSCALE)
    return img


CONDITIONS: list[dict] = [
    dict(name="clean", z=(1.2, 2.0), tilt=(5, 15)),
    dict(name="tilt_20", z=(1.2, 2.0), tilt=(20, 20)),
    dict(name="tilt_35", z=(1.2, 2.0), tilt=(35, 35)),
    dict(name="dist_mid", z=(1.7, 2.2), tilt=(10, 20)),
    dict(name="dist_far", z=(2.4, 3.0), tilt=(10, 20)),
    dict(name="noise_20", z=(1.2, 2.0), tilt=(10, 20), noise_sigma=20),
    dict(name="noise_35", z=(1.2, 2.0), tilt=(10, 20), noise_sigma=35),
    dict(name="blur_5", z=(1.2, 2.0), tilt=(10, 20), blur_k=5),
    dict(name="blur_9", z=(1.2, 2.0), tilt=(10, 20), blur_k=9),
    dict(name="occl_25", z=(1.2, 2.0), tilt=(10, 20), occl_frac=0.25),
    dict(name="occl_40", z=(1.2, 2.0), tilt=(10, 20), occl_frac=0.40),
    dict(name="jpeg_20", z=(1.2, 2.0), tilt=(10, 20), jpeg_q=20),
    dict(name="jpeg_10", z=(1.2, 2.0), tilt=(10, 20), jpeg_q=10),
    dict(name="combined", z=(1.5, 2.2), tilt=(15, 30), noise_sigma=15, blur_k=3, jpeg_q=75),
]


def main() -> None:
    OUT_DIR.mkdir(parents=True, exist_ok=True)
    records = []
    sprite0 = build_marker_sprite(0)
    idx = 0
    for cond in CONDITIONS:
        for trial in range(N_TRIALS):
            rng = random.Random(RNG_SEED + trial * 131 + CONDITIONS.index(cond) * 17)
            z = rng.uniform(*cond["z"])
            yaw = rng.uniform(-cond["tilt"][0], cond["tilt"][0])
            pitch = rng.uniform(-cond["tilt"][1], cond["tilt"][1])
            roll = rng.uniform(-35, 35)
            x = rng.uniform(-0.15, 0.15)
            y = rng.uniform(-0.12, 0.12)
            R = rodrigues_from_euler(yaw, pitch, roll)
            tvec = np.array([x, y, z], dtype=np.float64)

            scene, gt_corners, rvec = render_scene(sprite0, R, tvec)

            side_px = float(
                np.mean([
                    np.linalg.norm(gt_corners[(i + 1) % 4] - gt_corners[i])
                    for i in range(4)
                ])
            )
            if cond.get("occl_frac"):
                scene = occlude(scene, gt_corners, cond["occl_frac"], rng)
            out = degrade(scene, cond, trial)

            name = f"{cond['name']}_t{trial}"
            cv2.imwrite(str(OUT_DIR / f"{name}.png"), out)
            records.append({
                "name": name,
                "condition": cond["name"],
                "file": f"{name}.png",
                "id": 0,
                "tag_side_m": TAG_SIDE_M,
                "K": K.tolist(),
                "gt_corners_px": gt_corners.tolist(),
                "rvec": rvec.flatten().tolist(),
                "tvec": tvec.tolist(),
                "side_px": side_px,
            })
            idx += 1
    (OUT_DIR / "ground_truth.json").write_text(json.dumps(records, indent=1))
    print(f"generated {idx} scenes -> {OUT_DIR}")


if __name__ == "__main__":
    sys.exit(main())
