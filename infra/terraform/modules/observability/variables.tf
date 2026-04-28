variable "name_prefix" {
  type        = string
  description = "Prefix for SNS topic, dashboard, and alarm names"
}

variable "alert_email" {
  type        = string
  description = "Email address for SNS subscription — receives all alarm notifications"
}

variable "aurora_cluster_id" {
  type        = string
  description = "Aurora DBClusterIdentifier used as the dimension for cluster-level alarms"
}

variable "kinesis_stream_name" {
  type        = string
  description = "Kinesis stream name used as the dimension for iterator-age alarm"
}

variable "eks_cluster_name" {
  type        = string
  description = "EKS cluster name — used in alarm naming so operators know the scope"
}

variable "aurora_cpu_threshold" {
  type        = number
  default     = 75
  description = "CPU utilisation percent above which the Aurora alarm fires"
}

variable "iterator_age_threshold_ms" {
  type        = number
  default     = 60000
  description = "Kinesis IteratorAge threshold in ms (1 minute = stream-processor falling behind)"
}

variable "alarm_evaluation_periods" {
  type        = number
  default     = 3
  description = "How many consecutive periods must breach before alarming (3 ≈ 3m dampening)"
}

variable "xray_sampling_rate" {
  type        = number
  default     = 0.1
  description = "Fraction of requests X-Ray samples (0.0 – 1.0). 0.1 keeps cost low in dev."
}

variable "tags" {
  type    = map(string)
  default = {}
}
