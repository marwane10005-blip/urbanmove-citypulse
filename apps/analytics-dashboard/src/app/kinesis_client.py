from __future__ import annotations

import asyncio
import base64
import json
import os
import time
from collections.abc import Awaitable, Callable
from dataclasses import dataclass, field

import boto3
import structlog
from prometheus_client import Counter, Gauge

log = structlog.get_logger(__name__)

records_consumed = Counter(
    "kinesis_records_consumed_total",
    "Records returned by GetRecords and successfully handled.",
    ["stream", "shard"],
)
records_failed = Counter(
    "kinesis_records_failed_total",
    "Records the handler raised on.",
    ["stream", "shard"],
)
iterator_age_ms = Gauge(
    "kinesis_iterator_age_ms",
    "Max age of records in the last batch, per shard.",
    ["stream", "shard"],
)

Record = dict
Handler = Callable[[Record], Awaitable[None]]

@dataclass
class ShardLoop:
    stream_name: str
    handler: Handler

    idle_sleep: float = 1.0

    batch_size: int = 500

    starting_position: str = "LATEST"

    lease_table: str | None = None

    _client: boto3.client = field(default=None, init=False, repr=False)
    _stop: asyncio.Event = field(default_factory=asyncio.Event, init=False, repr=False)

    def __post_init__(self) -> None:
        region = os.environ.get("AWS_REGION", "eu-west-3")
        self._client = boto3.client("kinesis", region_name=region)

    async def run(self) -> None:
        shards = self._list_shards()
        log.info("shards_discovered", stream=self.stream_name, count=len(shards))
        await asyncio.gather(*(self._consume_shard(s) for s in shards))

    async def shutdown(self) -> None:
        self._stop.set()

    def _list_shards(self) -> list[str]:
        shards: list[str] = []
        paginator = self._client.get_paginator("list_shards")
        for page in paginator.paginate(StreamName=self.stream_name):
            shards.extend(s["ShardId"] for s in page["Shards"])
        return shards

    async def _consume_shard(self, shard_id: str) -> None:
        iterator = self._client.get_shard_iterator(
            StreamName=self.stream_name,
            ShardId=shard_id,
            ShardIteratorType=self.starting_position,
        )["ShardIterator"]

        while not self._stop.is_set():
            try:
                resp = await asyncio.to_thread(
                    self._client.get_records,
                    ShardIterator=iterator,
                    Limit=self.batch_size,
                )
            except self._client.exceptions.ProvisionedThroughputExceededException:
                log.warning("throughput_exceeded", shard=shard_id)
                await asyncio.sleep(2.0)
                continue
            except self._client.exceptions.ExpiredIteratorException:
                log.warning("iterator_expired_restarting", shard=shard_id)
                iterator = self._client.get_shard_iterator(
                    StreamName=self.stream_name,
                    ShardId=shard_id,
                    ShardIteratorType=self.starting_position,
                )["ShardIterator"]
                continue

            records = resp.get("Records", [])
            iterator = resp["NextShardIterator"]
            iterator_age_ms.labels(stream=self.stream_name, shard=shard_id).set(
                resp.get("MillisBehindLatest", 0)
            )

            for record in records:
                try:
                    payload = self._decode(record)
                    await self.handler(payload)
                    records_consumed.labels(stream=self.stream_name, shard=shard_id).inc()
                except Exception as exc:
                    records_failed.labels(stream=self.stream_name, shard=shard_id).inc()
                    log.exception("handler_failed", shard=shard_id, error=str(exc))

            if not records:
                await asyncio.sleep(self.idle_sleep)

    @staticmethod
    def _decode(record: dict) -> Record:

        data = record["Data"]
        if isinstance(data, str):
            data = base64.b64decode(data)
        return json.loads(data)

def sink_to_redis(redis_client, key_template: str = "vehicle:{vehicle_id}:position"):

    async def _handle(record: Record) -> None:
        key = key_template.format(**record)
        value = json.dumps({
            "lat": record["lat"],
            "lon": record["lon"],
            "speed_kmh": record.get("speed_kmh"),
            "ts": record.get("ts", time.time()),
        })
        await asyncio.to_thread(redis_client.setex, key, 300, value)

    return _handle
