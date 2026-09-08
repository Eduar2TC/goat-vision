"""Split data by animal to prevent data leakage.

Never place images of the same animal in train and test.
"""

import argparse
import csv
import json
import random
from pathlib import Path

from dataset.spec import (
    ANIMAL_SPLIT_SEED,
    DATASET_COLUMNS,
    TRAIN_RATIO,
    VALIDATION_RATIO,
)
from preprocessing.features import FEATURE_COLUMNS, TARGET

BREEDS = ["alpine", "boer", "nubian", "saanen", "toggenburg", "criolla"]
SEXES = ["male", "female"]
REGIONS = ["nuevo-leon", "guanajuato", "jalisco", "veracruz", "puebla"]
LIGHTING = ["sunlight", "cloudy", "indoor", "low-light"]
ENVIRONMENTS = ["corral", "pasture", "indoor"]
VIEWS = ["side", "rear"]


def generate_metadata(num_animals: int, output_dir: Path) -> dict:
    """Generate synthetic metadata for pipeline development and testing."""
    random.seed(ANIMAL_SPLIT_SEED)

    metadata = {}
    for i in range(num_animals):
        animal_id = f"GOAT-{i + 1:04d}"
        weight = random.uniform(20.0, 70.0)
        n_captures = random.randint(3, 8)
        captures = []
        for c in range(n_captures):
            capture = {
                "capture_id": f"{animal_id}-C{c + 1:02d}",
                "breed": random.choice(BREEDS),
                "sex": random.choice(SEXES),
                "age_months": random.randint(6, 60),
                "region": random.choice(REGIONS),
                "real_weight_kg": round(weight + random.uniform(-2.0, 2.0), 1),
                "bcs": random.randint(1, 5),
                "camera": f"phone-{random.randint(1, 6)}",
                "capture_date": f"2026-0{random.randint(1, 9)}-{random.randint(1, 28):02d}",
                "lighting": random.choice(LIGHTING),
                "environment": random.choice(ENVIRONMENTS),
                "view": random.choice(VIEWS),
                "distance": random.choice(["close", "medium", "far"]),
                "camera_width_px": random.choice([1280, 1920, 3264]),
                "camera_height_px": random.choice([720, 1080, 2448]),
                "body_length_cm": round(random.uniform(45, 105), 1),
                "withers_height_cm": round(random.uniform(50, 95), 1),
                "rump_height_cm": round(random.uniform(50, 95), 1),
                "chest_depth_cm": round(random.uniform(20, 50), 1),
                "chest_width_cm": round(random.uniform(12, 35), 1),
                "rump_width_cm": round(random.uniform(10, 30), 1),
                "rump_length_cm": round(random.uniform(15, 45), 1),
                "paw_height_cm": round(random.uniform(15, 35), 1),
            }
            captures.append(capture)
        metadata[animal_id] = captures

    (output_dir / "metadata").mkdir(parents=True, exist_ok=True)
    with open(output_dir / "metadata" / "animals.json", "w") as f:
        json.dump(metadata, f, indent=2)
    return metadata


def create_splits(metadata: dict, output_dir: Path) -> None:
    """Create train/validation/test splits by animal."""
    animals = list(metadata.keys())
    random.shuffle(animals)

    n = len(animals)
    n_train = int(n * TRAIN_RATIO)
    n_val = int(n * VALIDATION_RATIO)

    train_animals = animals[:n_train]
    val_animals = animals[n_train:n_train + n_val]
    test_animals = animals[n_train + n_val:]

    split_dir = output_dir / "splits"
    split_dir.mkdir(parents=True, exist_ok=True)

    def _write(name: str, animals_list: list) -> None:
        with open(split_dir / f"{name}.txt", "w") as f:
            for animal in animals_list:
                for capture in metadata[animal]:
                    f.write(f"{capture['capture_id']}\n")

    _write("train", train_animals)
    _write("validation", val_animals)
    _write("test", test_animals)

    print(f"Train: {len(train_animals)} animals")
    print(f"Validation: {len(val_animals)} animals")
    print(f"Test: {len(test_animals)} animals")


def write_features_csv(metadata: dict, output_dir: Path) -> Path:
    """Flatten metadata into the features CSV consumed by the pipeline.

    One row per capture with columns ``DATASET_COLUMNS + [capture_id,
    train_split]``.  ``FEATURE_COLUMNS`` and ``TARGET`` are a subset of
    these so ``train_regression``/``cross_validate_by_animal``/
    ``ensemble``/``stratify`` can read the same file.
    """
    output_dir.mkdir(parents=True, exist_ok=True)
    csv_path = output_dir / "features.csv"

    columns = DATASET_COLUMNS + ["capture_id"]
    with open(csv_path, "w", newline="") as f:
        writer = csv.DictWriter(f, fieldnames=columns)
        writer.writeheader()
        for animal_id, captures in metadata.items():
            for capture in captures:
                row = {col: capture.get(col, "") for col in columns}
                row["animal_id"] = animal_id
                writer.writerow(row)

    # Guard that the columns the pipeline needs are all present.
    required = FEATURE_COLUMNS + [TARGET, "animal_id"]
    missing = [c for c in required if c not in columns]
    if missing:
        raise ValueError(f"features.csv is missing required columns: {missing}")

    print(f"Wrote {csv_path} ({len(metadata)} animals)")

    # Per-split subset CSVs make independent test evaluation trivial.
    split_dir = output_dir / "splits"
    if split_dir.exists():
        for split_name in ("train", "validation", "test"):
            ids = set(
                (split_dir / f"{split_name}.txt")
                .read_text()
                .strip()
                .splitlines()
            )
            out = output_dir / f"features_{split_name}.csv"
            with open(csv_path) as src, open(out, "w", newline="") as dst:
                reader = csv.DictReader(src)
                writer = csv.DictWriter(dst, fieldnames=reader.fieldnames)
                writer.writeheader()
                for row in reader:
                    if row["capture_id"] in ids:
                        writer.writerow(row)
            print(f"Wrote {out} ({len(ids)} captures)")
    return csv_path


def main() -> None:
    parser = argparse.ArgumentParser(description="Generate dataset metadata and splits")
    parser.add_argument(
        "--animals", type=int, default=300,
        help="Number of animals to generate",
    )
    parser.add_argument(
        "--output", type=Path, default=Path("goatvision/ml/dataset"),
        help="Output directory",
    )
    args = parser.parse_args()

    metadata = generate_metadata(args.animals, args.output)
    create_splits(metadata, args.output)
    write_features_csv(metadata, args.output)
    print(f"Total animals: {len(metadata)}")


if __name__ == "__main__":
    main()