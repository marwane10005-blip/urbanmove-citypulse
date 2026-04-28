variable "name_prefix" {
  type        = string
  description = "Name prefix for Redis resources"
}

variable "vpc_id" {
  type        = string
  description = "VPC where Redis + its SG live"
}

variable "vpc_cidr" {
  type        = string
  description = "VPC CIDR allowed to reach Redis on 6379"
}

variable "private_subnet_ids" {
  type        = list(string)
  description = "Private subnets for the ElastiCache subnet group"
}

variable "node_type" {
  type        = string
  default     = "cache.t4g.micro"
  description = "ElastiCache node type. t4g.micro is the cheapest (~$0.017/hr in eu-west-3)."
}

variable "engine_version" {
  type        = string
  default     = "7.1"
  description = "Redis engine version"
}

variable "auth_token" {
  type        = string
  default     = null
  sensitive   = true
  description = "Optional Redis AUTH token. When null, in-transit encryption uses IAM-auth-free mode; SGs are the only guard. Set a value for defense-in-depth."
}

variable "expensive_on" {
  type        = bool
  default     = false
  description = "When false, skip provisioning Redis entirely (returns empty outputs)"
}

variable "log_retention_days" {
  type        = number
  default     = 3
}

variable "tags" {
  type    = map(string)
  default = {}
}
