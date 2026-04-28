data "aws_region" "current" {}

resource "aws_sns_topic" "alerts" {
  name = "${var.name_prefix}-alerts"

  tags = merge(var.tags, {
    Name = "${var.name_prefix}-alerts"
  })
}

resource "aws_sns_topic_subscription" "email" {
  topic_arn = aws_sns_topic.alerts.arn
  protocol  = "email"
  endpoint  = var.alert_email
}

resource "aws_cloudwatch_metric_alarm" "aurora_cpu_high" {
  alarm_name          = "${var.name_prefix}-aurora-cpu-high"
  alarm_description   = "Aurora ${var.aurora_cluster_id} average CPU > ${var.aurora_cpu_threshold}% over ${var.alarm_evaluation_periods} minutes"
  comparison_operator = "GreaterThanThreshold"
  evaluation_periods  = var.alarm_evaluation_periods
  threshold           = var.aurora_cpu_threshold
  metric_name         = "CPUUtilization"
  namespace           = "AWS/RDS"
  statistic           = "Average"
  period              = 60
  treat_missing_data  = "notBreaching"

  dimensions = {
    DBClusterIdentifier = var.aurora_cluster_id
  }

  alarm_actions = [aws_sns_topic.alerts.arn]
  ok_actions    = [aws_sns_topic.alerts.arn]

  tags = var.tags
}

resource "aws_cloudwatch_metric_alarm" "kinesis_iterator_age" {
  alarm_name          = "${var.name_prefix}-kinesis-iterator-age"
  alarm_description   = "Kinesis ${var.kinesis_stream_name} GetRecords.IteratorAgeMilliseconds > ${var.iterator_age_threshold_ms} ms"
  comparison_operator = "GreaterThanThreshold"
  evaluation_periods  = var.alarm_evaluation_periods
  threshold           = var.iterator_age_threshold_ms
  metric_name         = "GetRecords.IteratorAgeMilliseconds"
  namespace           = "AWS/Kinesis"
  statistic           = "Maximum"
  period              = 60
  treat_missing_data  = "notBreaching"

  dimensions = {
    StreamName = var.kinesis_stream_name
  }

  alarm_actions = [aws_sns_topic.alerts.arn]
  ok_actions    = [aws_sns_topic.alerts.arn]

  tags = var.tags
}

resource "aws_cloudwatch_metric_alarm" "billing_estimated" {
  alarm_name          = "${var.name_prefix}-billing-estimated-over-50"
  alarm_description   = "Account EstimatedCharges exceeded $50 (half the class-project budget)"
  comparison_operator = "GreaterThanThreshold"
  evaluation_periods  = 1
  threshold           = 50
  metric_name        = "EstimatedCharges"
  namespace          = "AWS/Billing"
  statistic          = "Maximum"
  period             = 21600
  treat_missing_data = "notBreaching"

  dimensions = {
    Currency = "USD"
  }

  alarm_actions = [aws_sns_topic.alerts.arn]

  tags = var.tags
}

resource "aws_xray_sampling_rule" "urbanmove" {
  rule_name      = "${var.name_prefix}-default"
  priority       = 5000
  reservoir_size = 1
  fixed_rate     = var.xray_sampling_rate

  host         = "*"
  http_method  = "*"
  resource_arn = "*"
  service_name = "*"
  service_type = "*"
  url_path     = "*"

  version = 1

  tags = var.tags
}

resource "aws_cloudwatch_dashboard" "urbanmove" {
  dashboard_name = "${var.name_prefix}-overview"

  dashboard_body = jsonencode({
    widgets = [
      {
        type   = "metric"
        x      = 0
        y      = 0
        width  = 12
        height = 6
        properties = {
          region = data.aws_region.current.name
          title  = "Aurora CPU (cluster ${var.aurora_cluster_id})"
          metrics = [
            ["AWS/RDS", "CPUUtilization", "DBClusterIdentifier", var.aurora_cluster_id],
          ]
          stat   = "Average"
          period = 60
        }
      },
      {
        type   = "metric"
        x      = 12
        y      = 0
        width  = 12
        height = 6
        properties = {
          region = data.aws_region.current.name
          title  = "Kinesis IteratorAge (${var.kinesis_stream_name})"
          metrics = [
            ["AWS/Kinesis", "GetRecords.IteratorAgeMilliseconds", "StreamName", var.kinesis_stream_name],
          ]
          stat   = "Maximum"
          period = 60
        }
      },
      {
        type   = "metric"
        x      = 0
        y      = 6
        width  = 12
        height = 6
        properties = {
          region = data.aws_region.current.name
          title  = "EKS API server 5xx rate"
          metrics = [
            ["ContainerInsights", "apiserver_request_total", "ClusterName", var.eks_cluster_name],
          ]
          stat   = "Sum"
          period = 60
        }
      },
      {
        type   = "metric"
        x      = 12
        y      = 6
        width  = 12
        height = 6
        properties = {
          region = data.aws_region.current.name
          title  = "SNS publishes (alerts topic)"
          metrics = [
            ["AWS/SNS", "NumberOfMessagesPublished", "TopicName", aws_sns_topic.alerts.name],
          ]
          stat   = "Sum"
          period = 300
        }
      },
    ]
  })
}
