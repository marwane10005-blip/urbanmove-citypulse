resource "aws_elasticache_subnet_group" "this" {
  name       = "${var.name_prefix}-redis"
  subnet_ids = var.private_subnet_ids

  tags = merge(var.tags, {
    Name = "${var.name_prefix}-redis-subnet-group"
  })
}

resource "aws_security_group" "this" {
  name        = "${var.name_prefix}-redis"
  description = "Redis 6379 from within the VPC"
  vpc_id      = var.vpc_id

  tags = merge(var.tags, {
    Name = "${var.name_prefix}-redis-sg"
  })

  lifecycle {
    create_before_destroy = true
  }
}

resource "aws_vpc_security_group_ingress_rule" "redis_from_vpc" {
  security_group_id = aws_security_group.this.id
  description       = "Redis from within the VPC"
  cidr_ipv4         = var.vpc_cidr
  from_port         = 6379
  to_port           = 6379
  ip_protocol       = "tcp"

  tags = merge(var.tags, {
    Name = "${var.name_prefix}-redis-ingress"
  })
}

resource "aws_cloudwatch_log_group" "slow" {
  count             = var.expensive_on ? 1 : 0
  name              = "/aws/elasticache/${var.name_prefix}-redis/slowlog"
  retention_in_days = var.log_retention_days

  tags = var.tags
}

resource "aws_elasticache_replication_group" "this" {
  count                      = var.expensive_on ? 1 : 0
  replication_group_id       = "${var.name_prefix}-redis"
  description                = "UrbanMove live-position cache"
  engine                     = "redis"
  engine_version             = var.engine_version
  node_type                  = var.node_type
  num_cache_clusters         = 1
  parameter_group_name       = "default.redis7"
  port                       = 6379
  subnet_group_name          = aws_elasticache_subnet_group.this.name
  security_group_ids         = [aws_security_group.this.id]
  at_rest_encryption_enabled = true
  transit_encryption_enabled = true
  auth_token                 = var.auth_token

  apply_immediately         = true
  auto_minor_version_upgrade = true
  automatic_failover_enabled = false
  snapshot_retention_limit   = 0

  log_delivery_configuration {
    destination      = aws_cloudwatch_log_group.slow[0].name
    destination_type = "cloudwatch-logs"
    log_format       = "json"
    log_type         = "slow-log"
  }

  tags = merge(var.tags, {
    Name = "${var.name_prefix}-redis"
  })
}
