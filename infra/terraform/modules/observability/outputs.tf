output "alerts_topic_arn" {
  value       = aws_sns_topic.alerts.arn
  description = "SNS topic ARN — consumed by CloudWatch Alarms and by services that need to emit custom alerts"
}

output "dashboard_name" {
  value       = aws_cloudwatch_dashboard.urbanmove.dashboard_name
  description = "CloudWatch dashboard name (deep-link: https://<region>.console.aws.amazon.com/cloudwatch/home#dashboards:name=<this>)"
}
