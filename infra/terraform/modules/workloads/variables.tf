variable "name_prefix" {
  type        = string
  description = "Name prefix for all IAM resources"
}

variable "cluster_name" {
  type        = string
  description = "EKS cluster name (required by Pod Identity Associations)"
}

variable "namespace" {
  type        = string
  default     = "urbanmove"
  description = "Kubernetes namespace the workload ServiceAccounts live in"
}

variable "aurora_secret_arn" {
  type        = string
  description = "ARN of the Aurora master credentials secret"
}

variable "iot_cert_secret_name" {
  type        = string
  default     = "iot/simulator-cert"
  description = "Name (not ARN — supports prefix wildcard matching) of the IoT cert secret"
}

variable "kinesis_stream_arn" {
  type        = string
  description = "ARN of the Kinesis telemetry stream"
}

variable "kinesis_leases_table_arn" {
  type        = string
  description = "ARN of the DynamoDB KCL leases table"
}

variable "lake_bucket_arn" {
  type        = string
  description = "Data lake bucket ARN"
}

variable "lake_kms_key_arn" {
  type        = string
  description = "KMS CMK ARN for the data lake"
}

variable "cognito_user_pool_arn" {
  type        = string
  description = "Cognito User Pool ARN — needed for identity-fleet admin ops"
}

variable "sagemaker_endpoint_name" {
  type        = string
  default     = "urbanmove-dev-eta"
  description = "Name of the SageMaker endpoint mobility-api invokes (for IAM resource scope)"
}

variable "tags" {
  type    = map(string)
  default = {}
}
