output "db_secret_arn" {
  value       = aws_secretsmanager_secret.db.arn
  description = "ARN of the Aurora master credentials secret (feed into aurora module + service IRSA policies)"
}

output "db_secret_name" {
  value       = aws_secretsmanager_secret.db.name
  description = "Human-friendly secret name"
}

output "db_username" {
  value       = var.db_username
  description = "Aurora master username (also embedded in the secret payload)"
}

output "db_password" {
  value       = random_password.db.result
  sensitive   = true
  description = "Generated master password (marked sensitive — prefer reading from Secrets Manager at runtime)"
}
