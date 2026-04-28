from __future__ import annotations

import sys

from awsglue.context import GlueContext
from awsglue.job import Job
from awsglue.utils import getResolvedOptions
from pyspark.context import SparkContext
from pyspark.sql import functions as F
from pyspark.sql.types import (
    DoubleType,
    IntegerType,
    LongType,
    StringType,
    StructField,
    StructType,
    TimestampType,
)

ARGS = getResolvedOptions(sys.argv, ["JOB_NAME", "lake-bucket"])
sc = SparkContext()
glue = GlueContext(sc)
spark = glue.spark_session
job = Job(glue)
job.init(ARGS["JOB_NAME"], ARGS)

LAKE = ARGS["lake-bucket"]
RAW_PATH = f"s3://{LAKE}/raw/telemetry/"
OUT_PATH = f"s3://{LAKE}/processed/training-features/"

TELEMETRY_SCHEMA = StructType(
    [
        StructField("vehicle_id", StringType()),
        StructField("ts", DoubleType()),
        StructField("lat", DoubleType()),
        StructField("lon", DoubleType()),
        StructField("heading_deg", DoubleType()),
        StructField("speed_kmh", DoubleType()),
        StructField("battery_pct", DoubleType()),
        StructField("ingest_ts", LongType()),
    ]
)

raw = (
    spark.read.schema(TELEMETRY_SCHEMA)
    .option("recursiveFileLookup", "true")
    .json(RAW_PATH)
)

clean = raw.filter(F.col("lat").isNotNull() & F.col("speed_kmh").isNotNull())

with_time = clean.withColumn(
    "ts_ts", F.to_timestamp(F.col("ts").cast(TimestampType()))
).withColumn(
    "hour_of_day", F.hour("ts_ts").cast(IntegerType())
).withColumn(
    "day_of_week", ((F.dayofweek("ts_ts") + 5) % 7).cast(IntegerType())
)

features = with_time.withColumn(
    "zone_lat", F.round(F.col("lat") / 0.005) * 0.005
).withColumn(
    "zone_lon", F.round(F.col("lon") / 0.005) * 0.005
).withColumn(
    "zone_congestion_index",
    F.least(F.lit(1.0), F.greatest(F.lit(0.0), F.lit(1.0) - F.col("speed_kmh") / F.lit(30.0))),
)

agg = (
    features.groupBy(
        "vehicle_id",
        F.date_trunc("hour", "ts_ts").alias("hour_bucket"),
        "hour_of_day",
        "day_of_week",
        "zone_lat",
        "zone_lon",
    )
    .agg(
        F.avg("speed_kmh").alias("avg_speed_kmh"),
        F.avg("zone_congestion_index").alias("zone_congestion_index"),
        F.count(F.lit(1)).alias("sample_count"),
    )
    .withColumnRenamed("zone_lat", "origin_lat")
    .withColumnRenamed("zone_lon", "origin_lon")
)

(
    agg.withColumn("dt", F.date_format("hour_bucket", "yyyy-MM-dd"))
    .write.mode("overwrite")
    .partitionBy("dt")
    .parquet(OUT_PATH)
)

job.commit()
