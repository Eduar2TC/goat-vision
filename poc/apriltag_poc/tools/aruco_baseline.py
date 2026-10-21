#!/usr/bin/env python3
"""PoC GoatVision — baseline de OpenCV ArUco sobre las mismas escenas.

Lee images/ground_truth.json + images/*.png, detecta con DICT_APRILTAG_36H11,
refino de esquinas sub-pixel, pose con solvePnP (mismas intrínsecas), y
evalúa contra el GT. Escribe results/aruco_results.json.

Opcional: `banner` imprime la tabla comparativa con apriltag_results.json.
"""
from __future__ import annotations

import json
import math
import sys
import time
from pathlib import Path

import cv2
import numpy as np

HERE = Path(__file__).resolve().parent.parent
IMAGES = HERE / "images"
RESULTS = HERE / "results"

PERMS = [perm for perm in __import__("itertools").permutations(range(4))]


def match_corners(det, gt):
    """min-mean L2 assignment entre det (4x2) y gt (4x2) sobre permutaciones."""
    best, best_perm = math.inf, None
    for p in PERMS:
        err = det - gt[list(p)]
        d = np.linalg.norm(err, axis=1)
        m = float(np.mean(d))
        if m < best:
            best, best_perm = m, p
    return best, best_perm


def rot_err_deg(Rd: np.ndarray, Rg: np.ndarray) -> float:
    c = np.clip((np.trace(Rd @ Rg.T) - 1) / 2, -1.0, 1.0)
    return math.degrees(math.acos(c))


def evaluate_record(rec: dict, detector: cv2.aruco.ArucoDetector, detparams) -> dict:
    img_gray = cv2.imread(str(IMAGES / rec["file"]), cv2.IMREAD_GRAYSCALE)
    K = np.array(rec["K"], dtype=np.float64)
    gt_corners = np.array(rec["gt_corners_px"], dtype=np.float64)
    tvec_gt = np.array(rec["tvec"], dtype=np.float64)    
    Rg, _ = cv2.Rodrigues(np.array(rec["rvec"]))

    t0 = time.perf_counter()
    corners, ids, _ = detector.detectMarkers(img_gray)
    elapsed_ms = (time.perf_counter() - t0) * 1000.0

    out = {
        "name": rec["name"],
        "condition": rec["condition"],
        "detected": False,
        "elapsed_ms": elapsed_ms,
    }
    if ids is None or len(ids) == 0 or corners is None:
        return out
    # escena con un solo marcador: id 0
    found = None
    for i, cid in enumerate(ids):
        # cv2 4.x: ids con shape (N,1); cv2 5.x: shape (N,)
        if int(np.asarray(cid).item()) == rec["id"]:
            found = i
            break
    if found is None:
        return out

    det = corners[found].reshape(4, 2).astype(np.float64)

    # ArUco devuelve las esquinas en orientación canónica (normalizada por la
    # propia operación de la plantilla del patrón): TL,TR,BR,BL — coincide con
    # el orden del GT (corr). No hay que permutar: el marcador es cuadrado y
    # la simetría 4-fold hace indistinguibles por reproyección las rotaciones
    # de 90°/180° alrededor de la normal (virified empíricamente).
    s = rec["tag_side_m"] / 2.0
    obj = np.array([[-s, -s, 0], [s, -s, 0], [s, s, 0], [-s, s, 0]], dtype=np.float64)

    # mean corner error vs GT (para reporte; la correspondencia para pose usa
    # directamente el orden canónico de ArUco)
    mean_err, perm_l2 = match_corners(det, gt_corners)

    # SOLVEPNP_IPPE_SQUARE en cv2 5.0 Python devuelve resultados erróneos
    # (reproyección de miles de px, t≈0): usar ITERATIVE.
    solved = cv2.solvePnP(obj, det, K, None, flags=cv2.SOLVEPNP_ITERATIVE)
    ok, rvec, tvec = bool(solved[0]), solved[1], solved[2]
    out.update(
        detected=True,
        corner_err_px=mean_err,
        elapsed_ms=elapsed_ms,
    )
    if ok:
        proj, _ = cv2.projectPoints(obj, rvec, tvec, K, None)
        out["pnp_reproj_px"] = float(np.mean(np.linalg.norm(proj.reshape(4, 2) - det, axis=1)))
        out["pose_t_err_m"] = float(np.linalg.norm(tvec.flatten() - tvec_gt))
        out["pose_rot_err_deg"] = rot_err_deg(cv2.Rodrigues(rvec)[0], Rg)
    return out


def summarize(results: list[dict]) -> dict:
    by_cond: dict[str, list[dict]] = {}
    for r in results:
        by_cond.setdefault(r["condition"], []).append(r)
    mean = lambda rows, key: (
        vals := [r[key] for r in rows if key in r],
        None if not vals else sum(vals) / len(vals),
    )[1]
    return {
        "total_images": len(results),
        "overall_detection_rate": sum(r["detected"] for r in results) / len(results),
        "conditions": {
            k: {
                "det_rate": sum(r["detected"] for r in v) / len(v),
                "mean_corner_err_px": mean(v, "corner_err_px"),
                "mean_pose_t_err_m": mean(v, "pose_t_err_m"),
                "mean_pose_rot_err_deg": mean(v, "pose_rot_err_deg"),
                "mean_elapsed_ms": mean(v, "elapsed_ms"),
            }
            for k, v in by_cond.items()
        },
    }


def run_baseline() -> None:
    RESULTS.mkdir(parents=True, exist_ok=True)
    records = json.loads((IMAGES / "ground_truth.json").read_text())
    params = cv2.aruco.DetectorParameters()
    params.cornerRefinementMethod = cv2.aruco.CORNER_REFINE_SUBPIX
    dict_april = cv2.aruco.getPredefinedDictionary(cv2.aruco.DICT_APRILTAG_36H11)
    detector = cv2.aruco.ArucoDetector(dict_april, params)
    results = [evaluate_record(r, detector, params) for r in records]
    (RESULTS / "aruco_results.json").write_text(
        json.dumps({"per_image": results, "summary": summarize(results)}, indent=1)
    )
    s = summarize(results)
    print(f"aruco baseline: det_rate global = {s['overall_detection_rate']:.3f}")


def banner() -> None:
    at = json.loads((RESULTS / "apriltag_results.json").read_text())
    ar = json.loads((RESULTS / "aruco_results.json").read_text())
    print(
        f"{'condición':<12} | {'AT det':>7} {'Ar det':>7} | "
        f"{'AT corner':>10} {'Ar corner':>10} | "
        f"{'AT t[m]':>8} {'Ar t[m]':>8} | {'AT rot°':>8} {'Ar rot°':>8} | {'AT ms':>7} {'Ar ms':>7}"
    )
    print("-" * 118)
    for k in sorted(set(at["summary"]["conditions"]) | set(ar["summary"]["conditions"])):
        a = at["summary"]["conditions"].get(k, {})
        b = ar["summary"]["conditions"].get(k, {})
        f = lambda v, nd=3: ("%.*f" % (nd, v)) if v is not None else "—"
        print(
            f"{k:<12} | {f(a.get('det_rate'),2):>7} {f(b.get('det_rate'),2):>7} | "
            f"{f(a.get('mean_corner_err_px'),2):>10} {f(b.get('mean_corner_err_px'),2):>10} | "
            f"{f(a.get('mean_pose_t_err_m')):>8} {f(b.get('mean_pose_t_err_m')):>8} | "
            f"{f(a.get('mean_pose_rot_err_deg'),1):>8} {f(b.get('mean_pose_rot_err_deg'),1):>8} | "
            f"{f(a.get('mean_elapsed_ms'),1):>7} {f(b.get('mean_elapsed_ms'),1):>7}"
        )
    print("-" * 118)
    print(
        f"{'GLOBAL':<12} | {at['summary']['overall_detection_rate']:.3f} {ar['summary']['overall_detection_rate']:.3f}"
    )


if __name__ == "__main__":
    if len(sys.argv) > 1 and sys.argv[1] == "banner":
        banner()
    else:
        run_baseline()
