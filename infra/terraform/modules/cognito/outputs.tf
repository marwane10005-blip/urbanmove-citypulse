output "user_pool_id" {
  value       = aws_cognito_user_pool.this.id
  description = "Cognito User Pool ID"
}

output "user_pool_arn" {
  value       = aws_cognito_user_pool.this.arn
  description = "Cognito User Pool ARN (use in IAM policies to authorise admin ops)"
}

output "user_pool_endpoint" {
  value       = aws_cognito_user_pool.this.endpoint
  description = "Issuer URL for JWT verification (combine with /.well-known/jwks.json)"
}

output "dashboard_client_id" {
  value       = aws_cognito_user_pool_client.dashboard.id
  description = "App client ID the dashboard configures in Amplify"
}

output "hosted_ui_domain" {
  value       = "${aws_cognito_user_pool_domain.this.domain}.auth.${data.aws_region.current.name}.amazoncognito.com"
  description = "Hosted UI URL (used for OAuth redirect flow during development)"
}

data "aws_region" "current" {}
