from __future__ import annotations

import argparse
import shutil
import sys
import tarfile
import tempfile
from pathlib import Path

ROOT = Path(__file__).resolve().parents[1]
sys.path.insert(0, str(ROOT / "apps" / "ml-training" / "src"))

import boto3
import joblib
from sklearn.ensemble import GradientBoostingRegressor
from sklearn.metrics import mean_absolute_error

from trainer.generate_synthetic import generate, split

FEATURE_COLS = [
    "origin_lat",
    "origin_lon",
    "dest_lat",
    "dest_lon",
    "hour_of_day",
    "day_of_week",
    "zone_congestion_index",
]
TARGET = "eta_seconds"

def train_model(samples: int, seed: int):
    print(f"[1/4] generating {samples:,} synthetic rows…")
    df = generate(samples, seed=seed)
    train, val = split(df, val_fraction=0.2, seed=seed)

    print(f"[2/4] training GradientBoostingRegressor…")
    model = GradientBoostingRegressor(n_estimators=200, max_depth=4, random_state=seed)
    model.fit(train[FEATURE_COLS], train[TARGET])

    val_mae = mean_absolute_error(val[TARGET], model.predict(val[FEATURE_COLS]))
    print(f"      val MAE: {val_mae:.1f} s")
    return model, val_mae

def package(model, out_path: Path) -> Path:
    print(f"[3/4] packaging into {out_path.name}…")
    with tempfile.TemporaryDirectory() as tmpdir:
        tmp = Path(tmpdir)
        joblib.dump(model, tmp / "model.joblib")

        src_code = ROOT / "apps" / "ml-training" / "src" / "trainer" / "code"
        shutil.copytree(src_code, tmp / "code")

        with tarfile.open(out_path, "w:gz") as tar:
            for entry in tmp.iterdir():
                tar.add(entry, arcname=entry.name)
    print(f"      wrote {out_path} ({out_path.stat().st_size // 1024} KiB)")
    return out_path

def upload(local_path: Path, bucket: str, key: str, region: str) -> str:
    print(f"[4/4] uploading to s3://{bucket}/{key}…")
    s3 = boto3.client("s3", region_name=region)
    s3.upload_file(str(local_path), bucket, key)
    s3_url = f"s3://{bucket}/{key}"
    print(f"      done: {s3_url}")
    return s3_url

def main() -> int:
    p = argparse.ArgumentParser()
    p.add_argument("--bucket", required=True, help="Data lake S3 bucket name")
    p.add_argument("--region", default="eu-west-3")
    p.add_argument("--samples", type=int, default=50_000)
    p.add_argument("--seed", type=int, default=42)
    p.add_argument("--key", default="model-artifacts/eta/model.tar.gz")
    args = p.parse_args()

    model, val_mae = train_model(args.samples, args.seed)
    out = Path(tempfile.mkdtemp()) / "model.tar.gz"
    package(model, out)
    s3_url = upload(out, args.bucket, args.key, args.region)

    print(f"\nReady. Set SAGEMAKER_ETA_ENDPOINT once Terraform has applied:")
    print(f"  kubectl -n urbanmove patch configmap urbanmove-config \\\\")
    print(f"    --type merge -p '{{\"data\":{{\"SAGEMAKER_ETA_ENDPOINT\":\"urbanmove-dev-eta\"}}}}'")
    print(f"  kubectl -n urbanmove rollout restart deploy/mobility-api")
    print(f"\nVal MAE: {val_mae:.1f} s · model artefact: {s3_url}")
    return 0

if __name__ == "__main__":
    sys.exit(main())
