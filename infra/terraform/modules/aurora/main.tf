resource "aws_db_subnet_group" "this" {
  name       = "${var.name_prefix}-aurora"
  subnet_ids = var.private_subnet_ids

  tags = merge(var.tags, {
    Name = "${var.name_prefix}-aurora-subnet-group"
  })
}

resource "aws_security_group" "this" {
  name        = "${var.name_prefix}-aurora"
  description = "Aurora PostgreSQL access"
  vpc_id      = var.vpc_id

  tags = merge(var.tags, {
    Name = "${var.name_prefix}-aurora-sg"
  })

  lifecycle {
    create_before_destroy = true
  }
}

resource "aws_vpc_security_group_ingress_rule" "postgres_from_vpc" {
  security_group_id = aws_security_group.this.id
  description       = "PostgreSQL from within the VPC"
  cidr_ipv4         = var.vpc_cidr
  from_port         = 5432
  to_port           = 5432
  ip_protocol       = "tcp"

  tags = merge(var.tags, {
    Name = "${var.name_prefix}-aurora-ingress-postgres"
  })
}

resource "aws_vpc_security_group_egress_rule" "all_egress" {
  security_group_id = aws_security_group.this.id
  description       = "All outbound (Aurora needs to reach AWS service endpoints)"
  cidr_ipv4         = "0.0.0.0/0"
  ip_protocol       = "-1"

  tags = merge(var.tags, {
    Name = "${var.name_prefix}-aurora-egress-all"
  })
}

resource "aws_kms_key" "aurora" {
  description             = "${var.name_prefix} Aurora cluster encryption key"
  enable_key_rotation     = true
  deletion_window_in_days = 7

  tags = merge(var.tags, {
    Name = "${var.name_prefix}-aurora-cmk"
  })
}

resource "aws_kms_alias" "aurora" {
  name          = "alias/${var.name_prefix}-aurora"
  target_key_id = aws_kms_key.aurora.key_id
}

resource "aws_rds_cluster_parameter_group" "this" {
  name        = "${var.name_prefix}-aurora-pg16"
  family      = "aurora-postgresql16"
  description = "UrbanMove cluster parameters (PostGIS preload)"

  parameter {
    name  = "shared_preload_libraries"
    value = "pg_stat_statements"
    apply_method = "pending-reboot"
  }

  tags = var.tags
}

resource "aws_rds_cluster" "this" {
  cluster_identifier     = "${var.name_prefix}-aurora"
  engine                 = "aurora-postgresql"
  engine_version         = var.engine_version
  engine_mode            = "provisioned"
  database_name          = var.db_name
  master_username        = var.db_username
  master_password        = var.db_password
  db_subnet_group_name   = aws_db_subnet_group.this.name
  vpc_security_group_ids = [aws_security_group.this.id]

  db_cluster_parameter_group_name = aws_rds_cluster_parameter_group.this.name

  storage_encrypted = true
  kms_key_id        = aws_kms_key.aurora.arn

  backup_retention_period      = var.backup_retention_days
  preferred_backup_window      = "02:00-03:00"
  preferred_maintenance_window = "sun:03:30-sun:04:30"

  deletion_protection       = var.deletion_protection
  skip_final_snapshot       = var.skip_final_snapshot
  final_snapshot_identifier = var.skip_final_snapshot ? null : "${var.name_prefix}-aurora-final-${formatdate("YYYYMMDDhhmmss", timestamp())}"

  copy_tags_to_snapshot               = true
  enabled_cloudwatch_logs_exports     = ["postgresql"]
  iam_database_authentication_enabled = true

  serverlessv2_scaling_configuration {
    min_capacity             = var.min_capacity_acu
    max_capacity             = var.max_capacity_acu
    seconds_until_auto_pause = var.auto_pause_seconds
  }

  tags = merge(var.tags, {
    Name = "${var.name_prefix}-aurora"
  })

  lifecycle {
    ignore_changes = [final_snapshot_identifier]
  }
}

resource "aws_rds_cluster_instance" "writer" {
  identifier         = "${var.name_prefix}-aurora-writer"
  cluster_identifier = aws_rds_cluster.this.id
  instance_class     = "db.serverless"
  engine             = aws_rds_cluster.this.engine
  engine_version     = aws_rds_cluster.this.engine_version

  db_subnet_group_name = aws_db_subnet_group.this.name

  publicly_accessible          = false
  auto_minor_version_upgrade   = true
  performance_insights_enabled = false

  tags = merge(var.tags, {
    Name = "${var.name_prefix}-aurora-writer"
    Role = "writer"
  })
}

resource "aws_rds_cluster_instance" "reader" {
  count              = var.expensive_on ? 1 : 0
  identifier         = "${var.name_prefix}-aurora-reader"
  cluster_identifier = aws_rds_cluster.this.id
  instance_class     = "db.serverless"
  engine             = aws_rds_cluster.this.engine
  engine_version     = aws_rds_cluster.this.engine_version

  db_subnet_group_name = aws_db_subnet_group.this.name

  publicly_accessible        = false
  auto_minor_version_upgrade = true

  tags = merge(var.tags, {
    Name = "${var.name_prefix}-aurora-reader"
    Role = "reader"
  })
}

resource "aws_kms_key" "backup" {
  count                   = var.enable_backup ? 1 : 0
  description             = "${var.name_prefix} AWS Backup vault encryption key"
  enable_key_rotation     = true
  deletion_window_in_days = 7
  tags                    = var.tags
}

resource "aws_backup_vault" "this" {
  count       = var.enable_backup ? 1 : 0
  name        = "${var.name_prefix}-aurora-vault"
  kms_key_arn = aws_kms_key.backup[0].arn
  tags        = var.tags
}

resource "aws_backup_plan" "aurora" {
  count = var.enable_backup ? 1 : 0
  name  = "${var.name_prefix}-aurora-daily"

  rule {
    rule_name         = "daily-retained-${var.backup_plan_retention_days}d"
    target_vault_name = aws_backup_vault.this[0].name
    schedule          = "cron(0 2 ? * * *)"
    start_window      = 60
    completion_window = 300

    lifecycle {
      delete_after = var.backup_plan_retention_days
    }
  }

  tags = var.tags
}

resource "aws_iam_role" "backup" {
  count = var.enable_backup ? 1 : 0
  name  = "${var.name_prefix}-aws-backup"

  assume_role_policy = jsonencode({
    Version = "2012-10-17"
    Statement = [{
      Effect    = "Allow"
      Principal = { Service = "backup.amazonaws.com" }
      Action    = "sts:AssumeRole"
    }]
  })

  tags = var.tags
}

resource "aws_iam_role_policy_attachment" "backup_service" {
  count      = var.enable_backup ? 1 : 0
  role       = aws_iam_role.backup[0].name
  policy_arn = "arn:aws:iam::aws:policy/service-role/AWSBackupServiceRolePolicyForBackup"
}

resource "aws_iam_role_policy_attachment" "backup_restore" {
  count      = var.enable_backup ? 1 : 0
  role       = aws_iam_role.backup[0].name
  policy_arn = "arn:aws:iam::aws:policy/service-role/AWSBackupServiceRolePolicyForRestores"
}

resource "aws_backup_selection" "aurora" {
  count        = var.enable_backup ? 1 : 0
  name         = "${var.name_prefix}-aurora-select"
  plan_id      = aws_backup_plan.aurora[0].id
  iam_role_arn = aws_iam_role.backup[0].arn
  resources    = [aws_rds_cluster.this.arn]
}
