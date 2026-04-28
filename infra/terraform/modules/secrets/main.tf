resource "random_password" "db" {
  length  = 32
  special = true
  override_special = "!#$%&*()-_=+[]{}<>:?"
}

resource "aws_secretsmanager_secret" "db" {
  name                    = "${var.name_prefix}/aurora/master"
  description             = "Aurora PostgreSQL master username + password for ${var.name_prefix}"
  recovery_window_in_days = var.recovery_window_days

  tags = merge(var.tags, {
    Name         = "${var.name_prefix}-aurora-master"
    Component    = "database"
    RotationTodo = "true"
  })
}

resource "aws_secretsmanager_secret_version" "db" {
  secret_id = aws_secretsmanager_secret.db.id

  secret_string = jsonencode({
    username = var.db_username
    password = random_password.db.result
    engine   = "postgres"
  })
}
