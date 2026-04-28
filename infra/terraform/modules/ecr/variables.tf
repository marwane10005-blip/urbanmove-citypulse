variable "name_prefix" {
  type        = string
  description = "Prefix applied to repository names (e.g. 'urbanmove' -> 'urbanmove/<svc>')"
}

variable "services" {
  type        = list(string)
  description = "List of service names. One ECR repository is created per entry."
}

variable "max_image_count" {
  type        = number
  default     = 10
  description = "How many tagged images to keep before the lifecycle policy evicts the oldest"
}

variable "untagged_expiry_days" {
  type        = number
  default     = 1
  description = "How many days an untagged image persists before deletion"
}

variable "scan_on_push" {
  type        = bool
  default     = true
  description = "Whether ECR runs a basic vulnerability scan on each pushed image"
}

variable "tag_mutability" {
  type        = string
  default     = "MUTABLE"
  description = "MUTABLE for dev (so we can overwrite :latest); IMMUTABLE for prod-grade repos"
  validation {
    condition     = contains(["MUTABLE", "IMMUTABLE"], var.tag_mutability)
    error_message = "tag_mutability must be MUTABLE or IMMUTABLE"
  }
}

variable "tags" {
  type        = map(string)
  default     = {}
  description = "Tags applied to all resources created by this module"
}
