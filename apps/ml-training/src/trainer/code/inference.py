from __future__ import annotations

import json
import os

import joblib
import pandas as pd

FEATURE_COLS = [
    "origin_lat",
    "origin_lon",
    "dest_lat",
    "dest_lon",
    "hour_of_day",
    "day_of_week",
    "zone_congestion_index",
]

def model_fn(model_dir: str):

    return joblib.load(os.path.join(model_dir, "model.joblib"))

def input_fn(request_body: bytes | str, content_type: str = "application/json"):
    if "json" not in (content_type or ""):
        raise ValueError(f"unsupported content type: {content_type}")

    payload = (
        json.loads(request_body)
        if isinstance(request_body, (bytes, str))
        else request_body
    )
    instances = payload.get("instances") or [payload]
    return pd.DataFrame(instances, columns=FEATURE_COLS)

def predict_fn(features: pd.DataFrame, model):
    preds = model.predict(features)
    return [float(p) for p in preds]

def output_fn(prediction, accept: str = "application/json"):
    if "json" not in (accept or ""):
        raise ValueError(f"unsupported accept type: {accept}")
    return json.dumps({"predictions": prediction}), "application/json"
