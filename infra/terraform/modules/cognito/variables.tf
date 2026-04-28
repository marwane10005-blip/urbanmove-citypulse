variable "name_prefix" {
  type        = string
  description = "Name prefix for the user pool and related resources"
}

variable "mfa_configuration" {
  type        = string
  default     = "OFF"
  description = "OFF | ON | OPTIONAL. OFF for dev/demo; OPTIONAL recommended for any public deployment."
  validation {
    condition     = contains(["OFF", "ON", "OPTIONAL"], var.mfa_configuration)
    error_message = "mfa_configuration must be one of OFF, ON, OPTIONAL."
  }
}

variable "callback_urls" {
  type        = list(string)
  default     = ["http://localhost:3000/auth/callback"]
  description = "OAuth2 callback URLs for the dashboard app client (add production URL once known)"
}

variable "logout_urls" {
  type        = list(string)
  default     = ["http://localhost:3000/auth/logout"]
  description = "OAuth2 logout URLs"
}

variable "access_token_validity_minutes" {
  type        = number
  default     = 60
  description = "Access token lifetime in minutes"
}

variable "refresh_token_validity_days" {
  type        = number
  default     = 30
  description = "Refresh token lifetime in days"
}

variable "tags" {
  type    = map(string)
  default = {}
}
