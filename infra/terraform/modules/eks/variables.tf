variable "name_prefix" {
  type        = string
  description = "Name prefix for cluster + node groups"
}

variable "eks_version" {
  type        = string
  default     = "1.31"
  description = "Kubernetes minor version. 1.29 was EoL'd; 1.31 is supported as of scaffold time."
}

variable "vpc_id" {
  type        = string
  description = "VPC where the cluster + nodes run"
}

variable "private_subnet_ids" {
  type        = list(string)
  description = "Private subnets where worker nodes land"
}

variable "public_subnet_ids" {
  type        = list(string)
  description = "Public subnets used for the EKS control plane ENIs + public-facing ALBs"
}

variable "expensive_on" {
  type        = bool
  default     = false
  description = "When false, node group desired=0 (control plane still billed; nodes don't run)"
}

variable "demo_mode" {
  type        = bool
  default     = false
  description = "When true, size up the node group for presentation + chaos testing"
}

variable "node_instance_types" {
  type        = list(string)
  default     = ["t3.medium"]
  description = "EC2 instance types permitted in the managed node group"
}

variable "tags" {
  type    = map(string)
  default = {}
}
