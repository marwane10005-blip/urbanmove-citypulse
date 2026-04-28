from __future__ import annotations

import json
import os
from pathlib import Path

import joblib
import pandas as pd
from sklearn.ensemble import GradientBoostingRegressor
from sklearn.metrics import mean_absolute_error
from sklearn.model_selection import train_test_split

INPUT_DIR = Path(os.environ.get("SM_CHANNEL_TRAIN", "/opt/ml/input/data/train"))
MODEL_DIR = Path(os.environ.get("SM_MODEL_DIR", "/opt/ml/model"))


def load_features(path: Path) -> pd.DataFrame:
    parquet_files = sorted(path.glob("*.parquet"))
    if not parquet_files:
        raise FileNotFoundError(f"no parquet files under {path}")
    return pd.concat((pd.read_parquet(p) for p in parquet_files), ignore_index=True)


def main() -> None:
    df = load_features(INPUT_DIR)
    feature_cols = [
        "origin_lat",
        "origin_lon",
        "dest_lat",
        "dest_lon",
        "hour_of_day",
        "day_of_week",
        "zone_congestion_index",
    ]
    target_col = "eta_seconds"

    X = df[feature_cols]
    y = df[target_col]
    X_train, X_test, y_train, y_test = train_test_split(X, y, test_size=0.2, random_state=42)

    model = GradientBoostingRegressor(n_estimators=200, max_depth=4, random_state=42)
    model.fit(X_train, y_train)

    mae = mean_absolute_error(y_test, model.predict(X_test))
    print(f"eval_mae_seconds={mae:.2f}")

    MODEL_DIR.mkdir(parents=True, exist_ok=True)
    joblib.dump(model, MODEL_DIR / "model.joblib")
    (MODEL_DIR / "metrics.json").write_text(
        json.dumps({"mae_seconds": mae, "n_train": len(X_train)})
    )


if __name__ == "__main__":
    main()
