output "cluster_id" {
  value       = aws_rds_cluster.this.id
  description = "Aurora cluster identifier"
}

output "cluster_arn" {
  value       = aws_rds_cluster.this.arn
  description = "Cluster ARN (for IAM database auth + monitoring)"
}

output "cluster_endpoint" {
  value       = aws_rds_cluster.this.endpoint
  description = "Writer endpoint (apps connect here for read/write)"
}

output "cluster_reader_endpoint" {
  value       = aws_rds_cluster.this.reader_endpoint
  description = "Reader endpoint (round-robins across read-only instances)"
}

output "cluster_port" {
  value       = aws_rds_cluster.this.port
  description = "Postgres port (5432)"
}

output "database_name" {
  value       = aws_rds_cluster.this.database_name
  description = "Default database name"
}

output "security_group_id" {
  value       = aws_security_group.this.id
  description = "SG to reference from EKS node security groups"
}

output "kms_key_arn" {
  value       = aws_kms_key.aurora.arn
  description = "KMS CMK protecting the cluster storage"
}

output "backup_vault_arn" {
  value       = var.enable_backup ? aws_backup_vault.this[0].arn : null
  description = "AWS Backup vault ARN (null when backups disabled)"
}

output "backup_plan_arn" {
  value       = var.enable_backup ? aws_backup_plan.aurora[0].arn : null
  description = "AWS Backup plan ARN"
}
