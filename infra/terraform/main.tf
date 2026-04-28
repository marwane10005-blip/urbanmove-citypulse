locals {
  name_prefix = "${var.project}-${var.environment}"

  common_tags = {
    Project     = var.project
    Environment = var.environment
    ManagedBy   = "terraform"
  }
}

data "aws_caller_identity" "current" {}
data "aws_partition" "current" {}

module "network_prod" {
  source = "./modules/network"

  name          = "${local.name_prefix}-prod"
  vpc_cidr      = var.vpc_cidr_prod
  azs           = var.azs
  single_nat_gw = !var.demo_mode
  tags          = local.common_tags
}

module "network_ml" {
  source = "./modules/network"

  name          = "${local.name_prefix}-ml"
  vpc_cidr      = var.vpc_cidr_ml
  azs           = [var.azs[1]]
  single_nat_gw = true
  tags          = local.common_tags
}

resource "aws_vpc_peering_connection" "prod_to_ml" {
  vpc_id      = module.network_prod.vpc_id
  peer_vpc_id = module.network_ml.vpc_id
  auto_accept = true

  tags = merge(local.common_tags, {
    Name = "${local.name_prefix}-peer-prod-ml"
  })
}

locals {
  services = [
    "simulator",
    "mobility-api",
    "identity-fleet",
    "analytics-dashboard",
    "stream-processor",
    "ml-training",
    "dashboard-web",
    "db-migrate",
  ]
}

module "ecr" {
  source = "./modules/ecr"

  name_prefix     = var.project
  services        = local.services
  max_image_count = 10
  tags            = local.common_tags
}

module "s3_lake" {
  source = "./modules/s3-lake"

  name = "${var.project}-lake-${data.aws_caller_identity.current.account_id}"
  tags = local.common_tags
}

module "kinesis" {
  source = "./modules/kinesis"

  name_prefix      = local.name_prefix
  lake_bucket_arn  = module.s3_lake.bucket_arn
  lake_kms_key_arn = module.s3_lake.kms_key_arn
  tags             = local.common_tags
}

module "iot" {
  source = "./modules/iot"

  name_prefix         = local.name_prefix
  kinesis_stream_name = module.kinesis.stream_name
  kinesis_stream_arn  = module.kinesis.stream_arn
  tags                = local.common_tags
}

module "aurora" {
  source = "./modules/aurora"

  name_prefix        = local.name_prefix
  vpc_id             = module.network_prod.vpc_id
  vpc_cidr           = var.vpc_cidr_prod
  private_subnet_ids = module.network_prod.private_subnet_ids

  engine_version   = var.aurora_engine_version
  db_username      = module.secrets.db_username
  db_password      = module.secrets.db_password
  min_capacity_acu = 0.5
  max_capacity_acu = var.demo_mode ? 4.0 : 2.0

  expensive_on = var.expensive_on
  tags         = local.common_tags
}

module "cognito" {
  source = "./modules/cognito"

  name_prefix = local.name_prefix
  tags        = local.common_tags
}

module "eks" {
  source = "./modules/eks"

  name_prefix        = local.name_prefix
  eks_version        = var.eks_version
  vpc_id             = module.network_prod.vpc_id
  private_subnet_ids = module.network_prod.private_subnet_ids
  public_subnet_ids  = module.network_prod.public_subnet_ids
  expensive_on       = var.expensive_on
  demo_mode          = var.demo_mode
  tags               = local.common_tags
}

resource "aws_vpc_security_group_ingress_rule" "aurora_from_eks" {
  security_group_id            = module.aurora.security_group_id
  description                  = "Postgres from EKS worker nodes"
  referenced_security_group_id = module.eks.node_security_group_id
  from_port                    = 5432
  to_port                      = 5432
  ip_protocol                  = "tcp"

  tags = merge(local.common_tags, {
    Name = "${local.name_prefix}-aurora-ingress-from-eks"
  })
}

module "redis" {
  source = "./modules/redis"

  name_prefix        = local.name_prefix
  vpc_id             = module.network_prod.vpc_id
  vpc_cidr           = var.vpc_cidr_prod
  private_subnet_ids = module.network_prod.private_subnet_ids
  expensive_on       = var.expensive_on
  tags               = local.common_tags
}

resource "aws_vpc_security_group_ingress_rule" "redis_from_eks" {
  security_group_id            = module.redis.security_group_id
  description                  = "Redis from EKS worker nodes"
  referenced_security_group_id = module.eks.node_security_group_id
  from_port                    = 6379
  to_port                      = 6379
  ip_protocol                  = "tcp"

  tags = merge(local.common_tags, {
    Name = "${local.name_prefix}-redis-ingress-from-eks"
  })
}

module "security" {
  source = "./modules/security"

  name_prefix = local.name_prefix
  tags        = local.common_tags
}

module "workloads" {
  source = "./modules/workloads"

  name_prefix             = local.name_prefix
  cluster_name            = module.eks.cluster_name
  aurora_secret_arn       = module.secrets.db_secret_arn
  kinesis_stream_arn      = module.kinesis.stream_arn
  kinesis_leases_table_arn = module.kinesis.leases_table_arn
  lake_bucket_arn         = module.s3_lake.bucket_arn
  lake_kms_key_arn        = module.s3_lake.kms_key_arn
  cognito_user_pool_arn   = module.cognito.user_pool_arn
  tags                    = local.common_tags
}

module "sagemaker" {
  source = "./modules/sagemaker"

  name_prefix      = local.name_prefix
  lake_bucket_arn  = module.s3_lake.bucket_arn
  lake_kms_key_arn = module.s3_lake.kms_key_arn
  demo_mode        = var.demo_mode
  schedule_enabled = false
  tags             = local.common_tags
}

module "observability" {
  source = "./modules/observability"

  name_prefix         = local.name_prefix
  alert_email         = var.admin_email
  aurora_cluster_id   = module.aurora.cluster_id
  kinesis_stream_name = module.kinesis.stream_name
  eks_cluster_name    = module.eks.cluster_name
  tags                = local.common_tags
}

module "secrets" {
  source = "./modules/secrets"

  name_prefix = local.name_prefix
  recovery_window_days = 0
  tags                 = local.common_tags
}

resource "aws_budgets_budget" "monthly" {
  name              = "${local.name_prefix}-monthly"
  budget_type       = "COST"
  limit_amount      = tostring(var.cost_budget_usd)
  limit_unit        = "USD"
  time_unit         = "MONTHLY"
  time_period_start = "2026-01-01_00:00"

  dynamic "notification" {
    for_each = [50, 80, 100]
    content {
      comparison_operator        = "GREATER_THAN"
      threshold                  = notification.value
      threshold_type             = "PERCENTAGE"
      notification_type          = "ACTUAL"
      subscriber_email_addresses = [var.admin_email]
    }
  }
}
