variable "project" {
  type        = string
  default     = "urbanmove"
  description = "Project prefix applied to all resources"
}

variable "environment" {
  type        = string
  default     = "dev"
  description = "Environment name (dev, staging, prod)"
}

variable "aws_region" {
  type        = string
  default     = "eu-west-3"
  description = "AWS region (Paris per LAB 01)"
}

variable "azs" {
  type        = list(string)
  default     = ["eu-west-3a", "eu-west-3b"]
  description = "Availability zones to span"
}

variable "vpc_cidr_prod" {
  type        = string
  default     = "10.10.0.0/16"
  description = "CIDR block for the Production App VPC"
}

variable "vpc_cidr_ml" {
  type        = string
  default     = "10.20.0.0/16"
  description = "CIDR block for the Machine Learning VPC"
}

variable "expensive_on" {
  type        = bool
  default     = false
  description = "Master switch for EKS node groups, Aurora instances, NAT GW beyond AZ-a, SageMaker endpoints"
}

variable "demo_mode" {
  type        = bool
  default     = false
  description = "Enable second NAT GW, upsize node groups, bring up SageMaker endpoint"
}

variable "admin_email" {
  type        = string
  default     = "ali.h.cherri@gmail.com"
  description = "Email address to receive CloudWatch alarm notifications"
}

variable "eks_version" {
  type        = string
  default     = "1.31"
  description = "Kubernetes version for EKS. 1.29 was removed from standard support; 1.31 is the current-gen long-support version at scaffold time."
}

variable "aurora_engine_version" {
  type        = string
  default     = "16.13"
  description = "Aurora PostgreSQL engine version. 15.x was removed from the available list in eu-west-3; use a 16.x to stay current."
}

variable "cost_budget_usd" {
  type        = number
  default     = 70
  description = "Monthly cost budget in USD; alerts fire at 50%, 80%, 100%"
}
