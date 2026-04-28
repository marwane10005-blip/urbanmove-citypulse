output "repository_urls" {
  value       = { for svc, r in aws_ecr_repository.this : svc => r.repository_url }
  description = "Map of service name → ECR repository URL"
}

output "repository_arns" {
  value       = { for svc, r in aws_ecr_repository.this : svc => r.arn }
  description = "Map of service name → ECR repository ARN"
}

output "repository_names" {
  value       = { for svc, r in aws_ecr_repository.this : svc => r.name }
  description = "Map of service name → ECR repository name (without registry host)"
}
