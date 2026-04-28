variable "name_prefix" {
  type        = string
  description = "Name prefix for all secrets in this module"
}

variable "db_username" {
  type        = string
  default     = "urbanmove_admin"
  description = "Aurora master username (stored alongside the password in the secret payload)"
}

variable "recovery_window_days" {
  type        = number
  default     = 7
  description = "Days before a deleted secret is permanently destroyed (0 to delete immediately — useful for dev teardowns)"
}

variable "tags" {
  type    = map(string)
  default = {}
}
