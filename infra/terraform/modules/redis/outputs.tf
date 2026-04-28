output "endpoint" {
  value       = var.expensive_on ? aws_elasticache_replication_group.this[0].primary_endpoint_address : null
  description = "Redis primary endpoint hostname — null when expensive_on=false"
}

output "port" {
  value       = var.expensive_on ? aws_elasticache_replication_group.this[0].port : null
  description = "Redis port (6379)"
}

output "security_group_id" {
  value       = aws_security_group.this.id
  description = "SG guarding Redis — add EKS node SG as an allowed source in the root composition"
}

output "replication_group_id" {
  value       = var.expensive_on ? aws_elasticache_replication_group.this[0].replication_group_id : null
  description = "Replication group identifier (for CLI ops + CloudWatch metric dimensions)"
}
