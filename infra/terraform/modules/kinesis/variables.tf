variable "name_prefix" {
  type        = string
  description = "Name prefix for all resources (stream, firehose, tables, roles)"
}

variable "stream_name" {
  type        = string
  default     = "vehicle-telemetry-v1"
  description = "Kinesis Data Stream name. Bump the suffix for schema-breaking changes."
}

variable "retention_hours" {
  type        = number
  default     = 24
  description = "Stream retention in hours (24 = default, up to 8760 = 1 year)"
}

variable "lake_bucket_arn" {
  type        = string
  description = "ARN of the S3 data lake bucket Firehose will land raw events into"
}

variable "lake_kms_key_arn" {
  type        = string
  description = "KMS CMK ARN guarding the lake bucket — Firehose needs kms:GenerateDataKey on this"
}

variable "firehose_buffer_size_mb" {
  type        = number
  default     = 5
  description = "Firehose buffer size in MiB (1–128). 5 gives reasonable latency/cost balance."
}

variable "firehose_buffer_interval_seconds" {
  type        = number
  default     = 60
  description = "Firehose flush interval in seconds (60–900). 60 keeps dashboards feeling live."
}

variable "log_retention_days" {
  type        = number
  default     = 3
  description = "CloudWatch log retention for Firehose errors"
}

variable "tags" {
  type    = map(string)
  default = {}
}
