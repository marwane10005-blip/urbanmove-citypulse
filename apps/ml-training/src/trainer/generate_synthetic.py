from __future__ import annotations

import argparse
from pathlib import Path

import numpy as np
import pandas as pd

LAT_MIN, LAT_MAX = 48.815, 48.905
LON_MIN, LON_MAX = 2.260, 2.420

HOURLY_SPEED_KMH = np.array(
    [
        32, 33, 33, 33, 33, 32, 28, 18, 14, 18, 22, 24,
        22, 20, 22, 22, 18, 14, 16, 22, 26, 28, 30, 32,
    ],
    dtype=float,
)

def haversine_m(lat1, lon1, lat2, lon2) -> np.ndarray:
    R = 6_371_000.0
    p1, p2 = np.radians(lat1), np.radians(lat2)
    dlat = np.radians(lat2 - lat1)
    dlon = np.radians(lon2 - lon1)
    a = np.sin(dlat / 2) ** 2 + np.cos(p1) * np.cos(p2) * np.sin(dlon / 2) ** 2
    return 2 * R * np.arcsin(np.sqrt(a))

def generate(n: int, seed: int = 42) -> pd.DataFrame:
    rng = np.random.default_rng(seed)

    origin_lat = rng.uniform(LAT_MIN, LAT_MAX, n)
    origin_lon = rng.uniform(LON_MIN, LON_MAX, n)
    dest_lat = rng.uniform(LAT_MIN, LAT_MAX, n)
    dest_lon = rng.uniform(LON_MIN, LON_MAX, n)

    hour_of_day = rng.integers(0, 24, n).astype(int)
    day_of_week = rng.integers(0, 7, n).astype(int)

    weekend = (day_of_week >= 5).astype(float)
    rush = ((hour_of_day >= 7) & (hour_of_day <= 9)).astype(float)
    rush += ((hour_of_day >= 17) & (hour_of_day <= 19)).astype(float)
    congestion = rng.beta(2, 5, n) + 0.35 * rush - 0.15 * weekend
    congestion = np.clip(congestion, 0.0, 1.0)

    dist_m = haversine_m(origin_lat, origin_lon, dest_lat, dest_lon)

    base_speed = HOURLY_SPEED_KMH[hour_of_day]
    effective_speed = base_speed * (1.0 - 0.55 * congestion)
    effective_speed = np.maximum(effective_speed, 4.0)
    effective_speed_mps = effective_speed * 1000.0 / 3600.0

    eta_seconds = dist_m / effective_speed_mps
    eta_seconds += rng.normal(0, eta_seconds * 0.08)
    eta_seconds = np.maximum(eta_seconds, 30.0)

    return pd.DataFrame(
        {
            "origin_lat": origin_lat,
            "origin_lon": origin_lon,
            "dest_lat": dest_lat,
            "dest_lon": dest_lon,
            "hour_of_day": hour_of_day,
            "day_of_week": day_of_week,
            "zone_congestion_index": congestion,
            "distance_m": dist_m,
            "eta_seconds": eta_seconds,
        }
    )

def split(
    df: pd.DataFrame, val_fraction: float = 0.2, seed: int = 42
) -> tuple[pd.DataFrame, pd.DataFrame]:
    rng = np.random.default_rng(seed)
    idx = rng.permutation(len(df))
    cut = int(len(df) * (1 - val_fraction))
    return df.iloc[idx[:cut]].reset_index(drop=True), df.iloc[idx[cut:]].reset_index(drop=True)

def write(df: pd.DataFrame, path: str) -> None:
    if path.startswith("s3://"):
        df.to_parquet(path, index=False)
    else:
        out = Path(path)
        out.parent.mkdir(parents=True, exist_ok=True)
        df.to_parquet(out, index=False)

def main() -> None:
    parser = argparse.ArgumentParser()
    parser.add_argument("--samples", type=int, default=50_000)
    parser.add_argument("--seed", type=int, default=42)
    parser.add_argument(
        "--out-train",
        required=True,
        help="Output path for train set (local or s3://)",
    )
    parser.add_argument(
        "--out-val",
        required=True,
        help="Output path for validation set (local or s3://)",
    )
    args = parser.parse_args()

    df = generate(args.samples, seed=args.seed)
    train, val = split(df, val_fraction=0.2, seed=args.seed)
    write(train, args.out_train)
    write(val, args.out_val)
    print(f"wrote {len(train):,} train / {len(val):,} val rows")
    print(f"  mean eta: {df['eta_seconds'].mean():.1f}s")
    print(f"  median distance: {df['distance_m'].median():.0f}m")

if __name__ == "__main__":
    main()
