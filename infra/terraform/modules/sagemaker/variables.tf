variable "name_prefix" {
  type        = string
  description = "Prefix for all ML pipeline resources"
}

variable "lake_bucket_arn" {
  type        = string
  description = "Data lake bucket ARN (training inputs + model artefacts live here)"
}

variable "lake_kms_key_arn" {
  type        = string
  description = "KMS CMK ARN guarding the lake bucket"
}

variable "demo_mode" {
  type        = bool
  default     = false
  description = "When true, create the SageMaker endpoint so `mobility-api` can call /eta for real. Off by default — endpoint is the most expensive piece."
}

variable "schedule_expression" {
  type        = string
  default     = "cron(0 2 * * ? *)"
  description = "EventBridge cron for the daily training pipeline (default: 02:00 UTC)"
}

variable "schedule_enabled" {
  type        = bool
  default     = false
  description = "Whether the EventBridge schedule is ENABLED. Keep false until the Glue script + training container are published."
}

variable "enable_glue_job" {
  type        = bool
  default     = false
  description = "Whether to create the Glue ETL job. Default false — AWS Glue CreateJob requires account-level activation that can lag the rest of the account by days. Flip to true once `aws glue create-job` succeeds from the CLI."
}

variable "tags" {
  type    = map(string)
  default = {}
}
