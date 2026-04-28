data "aws_caller_identity" "current" {}
data "aws_region" "current" {}

data "aws_iot_endpoint" "data_ats" {
  endpoint_type = "iot:Data-ATS"
}

resource "aws_iot_thing_type" "vehicle" {
  name = "${var.name_prefix}-vehicle"

  properties {
    description           = "Connected mobility vehicle (scooter, bike, car). Publishes telemetry under urbanmove/fleet/(id)/telemetry."
    searchable_attributes = ["fleet_id", "model"]
  }

  tags = var.tags
}

resource "aws_iot_policy" "device" {
  name = "${var.name_prefix}-device-policy"

  policy = jsonencode({
    Version = "2012-10-17"
    Statement = [
      {
        Sid      = "ConnectAsOwnThing"
        Effect   = "Allow"
        Action   = "iot:Connect"
        Resource = "arn:aws:iot:${data.aws_region.current.name}:${data.aws_caller_identity.current.account_id}:client/$${iot:Connection.Thing.ThingName}"
      },
      {
        Sid    = "PublishOnOwnTelemetry"
        Effect = "Allow"
        Action = "iot:Publish"
        Resource = [
          "arn:aws:iot:${data.aws_region.current.name}:${data.aws_caller_identity.current.account_id}:topic/${var.fleet_topic_prefix}/$${iot:Connection.Thing.ThingName}/telemetry",
          "arn:aws:iot:${data.aws_region.current.name}:${data.aws_caller_identity.current.account_id}:topic/${var.fleet_topic_prefix}/$${iot:Connection.Thing.ThingName}/events",
        ]
      },
      {
        Sid    = "ReceiveOwnCommands"
        Effect = "Allow"
        Action = ["iot:Subscribe", "iot:Receive"]
        Resource = [
          "arn:aws:iot:${data.aws_region.current.name}:${data.aws_caller_identity.current.account_id}:topicfilter/${var.fleet_topic_prefix}/$${iot:Connection.Thing.ThingName}/commands",
          "arn:aws:iot:${data.aws_region.current.name}:${data.aws_caller_identity.current.account_id}:topic/${var.fleet_topic_prefix}/$${iot:Connection.Thing.ThingName}/commands",
        ]
      },
    ]
  })
}

resource "aws_iam_role" "iot_rule" {
  name = "${var.name_prefix}-iot-rule"

  assume_role_policy = jsonencode({
    Version = "2012-10-17"
    Statement = [{
      Effect    = "Allow"
      Principal = { Service = "iot.amazonaws.com" }
      Action    = "sts:AssumeRole"
    }]
  })

  tags = var.tags
}

resource "aws_iam_role_policy" "iot_rule" {
  name = "${var.name_prefix}-iot-rule"
  role = aws_iam_role.iot_rule.id

  policy = jsonencode({
    Version = "2012-10-17"
    Statement = [
      {
        Sid      = "PutToKinesis"
        Effect   = "Allow"
        Action   = ["kinesis:PutRecord", "kinesis:PutRecords"]
        Resource = var.kinesis_stream_arn
      },
      {
        Sid      = "WriteErrorLogs"
        Effect   = "Allow"
        Action   = ["logs:CreateLogStream", "logs:PutLogEvents"]
        Resource = aws_cloudwatch_log_group.iot_errors.arn
      },
    ]
  })
}

resource "aws_cloudwatch_log_group" "iot_errors" {
  name              = "/aws/iot/${var.name_prefix}-ingest"
  retention_in_days = var.log_retention_days
  tags              = var.tags
}

resource "aws_iot_topic_rule" "ingest" {
  name        = "${replace(var.name_prefix, "-", "_")}_ingest_telemetry"
  description = "Forward device telemetry from MQTT to Kinesis for stream processing"
  enabled     = true
  sql         = "SELECT *, timestamp() AS ingest_ts FROM '${var.fleet_topic_prefix}/+/telemetry'"
  sql_version = "2016-03-23"

  kinesis {
    role_arn      = aws_iam_role.iot_rule.arn
    stream_name   = var.kinesis_stream_name
    partition_key = "$${vehicle_id}"
  }

  error_action {
    cloudwatch_logs {
      log_group_name = aws_cloudwatch_log_group.iot_errors.name
      role_arn       = aws_iam_role.iot_rule.arn
    }
  }

  tags = var.tags
}
