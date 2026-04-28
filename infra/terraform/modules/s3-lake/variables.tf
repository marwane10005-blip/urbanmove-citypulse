variable "name" {
  type        = string
  description = "Bucket name (must be globally unique — append account ID if the project prefix alone may collide)"
}

variable "ia_transition_days" {
  type        = number
  default     = 60
  description = "Days in Standard before transitioning to Standard-IA (matches LAB 04 default)"
}

variable "glacier_transition_days" {
  type        = number
  default     = 180
  description = "Days before transitioning to Glacier Instant Retrieval"
}

variable "expiration_days" {
  type        = number
  default     = 365
  description = "Days before current object versions are deleted"
}

variable "noncurrent_version_expiration_days" {
  type        = number
  default     = 30
  description = "Days before noncurrent (overwritten) versions are deleted"
}

variable "kms_deletion_window_days" {
  type        = number
  default     = 7
  description = "Days before the KMS CMK is permanently deleted after marked for deletion (7 is the minimum)"
}

variable "enable_macie_tag" {
  type        = bool
  default     = true
  description = "Tag the bucket so Amazon Macie picks it up for PII scanning automatically"
}

variable "tags" {
  type        = map(string)
  default     = {}
  description = "Tags applied to all resources in this module"
}
