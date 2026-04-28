variable "name" {
  type        = string
  description = "Name prefix applied to all network resources"
}

variable "vpc_cidr" {
  type        = string
  description = "CIDR block for the VPC (e.g. 10.10.0.0/16)"
}

variable "azs" {
  type        = list(string)
  description = "Availability zones to spread subnets across"
}

variable "public_subnet_newbits" {
  type        = number
  default     = 8
  description = "How many bits to add to the VPC CIDR when carving public subnets (/24 from a /16)"
}

variable "private_subnet_newbits" {
  type        = number
  default     = 8
  description = "How many bits to add to the VPC CIDR when carving private subnets"
}

variable "single_nat_gw" {
  type        = bool
  default     = true
  description = "If true, a single NAT Gateway is placed in the first AZ. If false, one NAT per AZ."
}

variable "enable_flow_logs" {
  type        = bool
  default     = true
  description = "Whether to enable VPC Flow Logs to CloudWatch"
}

variable "tags" {
  type        = map(string)
  default     = {}
  description = "Tags applied to all resources created by this module"
}
