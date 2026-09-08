"""GroupKFold evaluation by animal for honest, leakage-free metrics."""

import argparse
import json
from pathlib import Path

import numpy as np
import pandas as pd
from sklearn.ensemble import ExtraTreesRegressor, GradientBoostingRegressor, RandomForestRegressor
from sklearn.linear_model import LinearRegression
from sklearn.metrics import mean_absolute_error, root_mean_squared_error, r2_score
from sklearn.model_selection import GroupKFold
from sklearn.pipeline import Pipeline
from sklearn.preprocessing import PolynomialFeatures, StandardScaler
from sklearn.svm import SVR

from preprocessing.features import FEATURE_COLUMNS, TARGET


def cross_validate_by_animal(X, y, groups, n_splits=5):
    gkf = GroupKFold(n_splits=n_splits)

    models = {
        "linear": Pipeline([("scaler", StandardScaler()), ("model", LinearRegression())]),
        "polynomial": Pipeline([
            ("poly", PolynomialFeatures(degree=2, include_bias=False)),
            ("scaler", StandardScaler()),
            ("model", LinearRegression()),
        ]),
        "random_forest": Pipeline([
            ("scaler", StandardScaler()),
            ("model", RandomForestRegressor(n_estimators=150, random_state=42, n_jobs=-1)),
        ]),
        "extra_trees": Pipeline([
            ("scaler", StandardScaler()),
            ("model", ExtraTreesRegressor(n_estimators=150, random_state=42, n_jobs=-1)),
        ]),
        "svr": Pipeline([
            ("scaler", StandardScaler()),
            ("model", SVR(C=10.0, gamma="scale")),
        ]),
        "gradient_boosting": Pipeline([
            ("scaler", StandardScaler()),
            ("model", GradientBoostingRegressor(n_estimators=150, random_state=42)),
        ]),
    }

    results = {}
    for name, model in models.items():
        mae_list, rmse_list, r2_list, mape_list = [], [], [], []
        for train_idx, test_idx in gkf.split(X, y, groups):
            model.fit(X[train_idx], y[train_idx])
            pred = model.predict(X[test_idx])
            mae_list.append(mean_absolute_error(y[test_idx], pred))
            rmse_list.append(root_mean_squared_error(y[test_idx], pred))
            r2_list.append(r2_score(y[test_idx], pred))
            mape = np.mean(np.abs((y[test_idx] - pred) / (y[test_idx] + 1e-9))) * 100
            mape_list.append(mape)

        results[name] = {
            "mae_mean": float(np.mean(mae_list)),
            "mae_std": float(np.std(mae_list)),
            "rmse_mean": float(np.mean(rmse_list)),
            "mape_mean": float(np.mean(mape_list)),
            "r2_mean": float(np.mean(r2_list)),
        }
        print(f"{name:20s} MAE={results[name]['mae_mean']:6.2f}±{results[name]['mae_std']:4.2f} "
              f"R2={results[name]['r2_mean']:6.4f}")

    return results


def main():
    parser = argparse.ArgumentParser()
    parser.add_argument("--csv", type=Path, required=True)
    parser.add_argument("--splits", type=int, default=5)
    args = parser.parse_args()

    df = pd.read_csv(args.csv)
    X = df[FEATURE_COLUMNS].values
    y = df[TARGET].values
    groups = df["animal_id"].values

    results = cross_validate_by_animal(X, y, groups, args.splits)
    with open("evaluation_report.json", "w") as f:
        json.dump(results, f, indent=2)
    print("\nSaved evaluation_report.json")


if __name__ == "__main__":
    main()