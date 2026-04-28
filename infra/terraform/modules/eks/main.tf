locals {
  cluster_name = "${var.name_prefix}-eks"

  min_size     = var.expensive_on || var.demo_mode ? 1 : 0
  desired_size = var.demo_mode ? 3 : (var.expensive_on ? 2 : 0)
  max_size     = var.demo_mode ? 6 : 4
}

module "eks" {
  source  = "terraform-aws-modules/eks/aws"
  version = "~> 20.24"

  cluster_name    = local.cluster_name
  cluster_version = var.eks_version

  vpc_id                          = var.vpc_id
  subnet_ids                      = var.private_subnet_ids
  control_plane_subnet_ids        = var.public_subnet_ids
  cluster_endpoint_public_access  = true
  cluster_endpoint_private_access = true

  enable_cluster_creator_admin_permissions = true
  authentication_mode                      = "API_AND_CONFIG_MAP"

  cluster_addons = {
    coredns = {
      most_recent = true
    }
    kube-proxy = {
      most_recent = true
    }
    vpc-cni = {
      most_recent = true
    }
    eks-pod-identity-agent = {
      most_recent = true
    }
  }

  eks_managed_node_groups = {
    default = {
      name           = "${var.name_prefix}-workers"
      instance_types = var.node_instance_types
      capacity_type  = "ON_DEMAND"

      min_size     = local.min_size
      max_size     = local.max_size
      desired_size = local.desired_size

      labels = {
        workload = "general"
      }

      tags = merge(var.tags, {
        Name = "${var.name_prefix}-worker"
      })
    }
  }

  cluster_enabled_log_types              = ["api", "audit", "authenticator"]
  cloudwatch_log_group_retention_in_days = 3

  tags = merge(var.tags, {
    Name = local.cluster_name
  })
}
