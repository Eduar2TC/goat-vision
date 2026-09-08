"""GoatVision dataset specification.

Dataset structure:

goatvision/ml/dataset/
    raw/
        <animal_id>/
            <capture_id>.jpg
    annotations/
        <capture_id>.json
    metadata/
        animals.csv
    splits/
        train.txt
        validation.txt
        test.txt
"""

DATASET_COLUMNS = [
    "animal_id",
    "breed",
    "sex",
    "age_months",
    "region",
    "real_weight_kg",
    "bcs",
    "camera",
    "capture_date",
    "lighting",
    "environment",
    "view",
    "distance",
    "camera_width_px",
    "camera_height_px",
    "body_length_cm",
    "withers_height_cm",
    "rump_height_cm",
    "chest_depth_cm",
    "chest_width_cm",
    "rump_width_cm",
    "rump_length_cm",
    "paw_height_cm",
]

# 70% / 15% / 15% split BY ANIMAL (never by image)
TRAIN_RATIO = 0.70
VALIDATION_RATIO = 0.15
TEST_RATIO = 0.15

ANIMAL_SPLIT_SEED = 42