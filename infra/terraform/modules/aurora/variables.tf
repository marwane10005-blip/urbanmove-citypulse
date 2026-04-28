variable "name_prefix" {
  type        = string
  description = "Name prefix for all Aurora resources"
}

variable "vpc_id" {
  type        = string
  description = "VPC ID where the DB subnet group + security group live"
}

variable "vpc_cidr" {
  type        = string
  description = "VPC CIDR — used to allow-list service-plane connections to the DB"
}

variable "private_subnet_ids" {
  type        = list(string)
  description = "Private subnet IDs for the DB subnet group (must span at least 2 AZs)"
}

variable "db_name" {
  type        = string
  default     = "urbanmove"
  description = "Name of the initial database created in the cluster"
}

variable "db_username" {
  type        = string
  description = "Master username (from secrets module)"
}

variable "db_password" {
  type        = string
  sensitive   = true
  description = "Master password (from secrets module)"
}

variable "engine_version" {
  type        = string
  default     = "15.5"
  description = "Aurora PostgreSQL engine version"
}

variable "min_capacity_acu" {
  type        = number
  default     = 0.5
  description = "Minimum Serverless v2 capacity in ACUs (0.5 is the absolute floor)"
}

variable "max_capacity_acu" {
  type        = number
  default     = 2.0
  description = "Maximum Serverless v2 capacity in ACUs"
}

variable "auto_pause_seconds" {
  type        = number
  default     = 300
  description = "Seconds of inactivity before Serverless v2 pauses the reader (and scales writer to 0). 300-86400 allowed; 0 disables auto-pause."
}

variable "expensive_on" {
  type        = bool
  default     = false
  description = "When false, skip the read-replica instance (cluster + writer still exist)"
}

variable "backup_retention_days" {
  type        = number
  default     = 1
  description = "Automated-backup retention in days. Default 1 to stay within the AWS free-tier hard cap for new accounts. Bump to 7 once the account is off the free tier."
}

variable "deletion_protection" {
  type        = bool
  default     = false
  description = "Deletion protection — keep false during dev so `terraform destroy` succeeds"
}

variable "skip_final_snapshot" {
  type        = bool
  default     = true
  description = "Skip the final snapshot on cluster deletion (dev only; flip to false for prod)"
}

variable "enable_backup" {
  type        = bool
  default     = true
  description = "Whether to create an AWS Backup plan + vault for the cluster. Turn off during early dev to keep destroy fast."
}

variable "backup_plan_retention_days" {
  type        = number
  default     = 7
  description = "Days AWS Backup retains each snapshot"
}

variable "tags" {
  type    = map(string)
  default = {}
}
