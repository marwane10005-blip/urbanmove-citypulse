output "role_arns" {
  value = {
    mobility_api        = aws_iam_role.mobility_api.arn
    identity_fleet      = aws_iam_role.identity_fleet.arn
    stream_processor    = aws_iam_role.stream_processor.arn
    analytics_dashboard = aws_iam_role.analytics_dashboard.arn
    simulator           = aws_iam_role.simulator.arn
    db_migrate          = aws_iam_role.db_migrate.arn
  }
  description = "Map of service → IAM role ARN assumed by the workload pods via Pod Identity"
}
