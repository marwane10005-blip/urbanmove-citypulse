variable "name_prefix" {
  type        = string
  description = "Prefix applied to IoT resources"
}

variable "kinesis_stream_name" {
  type        = string
  description = "Name of the Kinesis Data Stream the IoT Rule will forward telemetry into"
}

variable "kinesis_stream_arn" {
  type        = string
  description = "ARN of the Kinesis Data Stream (for the IoT Rule's IAM policy)"
}

variable "fleet_topic_prefix" {
  type        = string
  default     = "urbanmove/fleet"
  description = "MQTT topic prefix devices publish under. Full topic: <prefix>/<vehicle_id>/telemetry"
}

variable "log_retention_days" {
  type        = number
  default     = 3
  description = "CloudWatch log retention for IoT Rule errors"
}

variable "tags" {
  type    = map(string)
  default = {}
}
