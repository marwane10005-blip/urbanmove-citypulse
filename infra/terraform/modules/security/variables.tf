variable "name_prefix" {
  type        = string
  description = "Name prefix (only used on tags + the WAF ACL name)"
}

variable "enable_guardduty" {
  type        = bool
  default     = true
  description = "Enable Amazon GuardDuty (continuous threat detection). ~free for low-volume accounts."
}

variable "enable_security_hub" {
  type        = bool
  default     = true
  description = "Enable Security Hub + the CIS AWS Foundations standard"
}

variable "enable_macie" {
  type        = bool
  default     = true
  description = "Enable Amazon Macie for PII scanning on the data lake"
}

variable "enable_waf" {
  type        = bool
  default     = true
  description = "Create a regional WAF WebACL. Association to an ALB is done in the root composition (once the ALB exists)."
}

variable "tags" {
  type    = map(string)
  default = {}
}
