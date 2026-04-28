data "aws_caller_identity" "current" {}
data "aws_partition" "current" {}
data "aws_region" "current" {}

resource "aws_kinesis_stream" "telemetry" {
  name             = "${var.name_prefix}-${var.stream_name}"
  retention_period = var.retention_hours

  stream_mode_details {
    stream_mode = "ON_DEMAND"
  }

  encryption_type = "KMS"
  kms_key_id      = "alias/aws/kinesis"

  tags = merge(var.tags, {
    Name = "${var.name_prefix}-${var.stream_name}"
  })
}

resource "aws_dynamodb_table" "leases" {
  name         = "${var.name_prefix}-stream-processor-leases"
  billing_mode = "PAY_PER_REQUEST"
  hash_key     = "leaseKey"

  attribute {
    name = "leaseKey"
    type = "S"
  }

  point_in_time_recovery {
    enabled = false
  }

  server_side_encryption {
    enabled = true
  }

  tags = merge(var.tags, {
    Name = "${var.name_prefix}-stream-processor-leases"
  })
}

resource "aws_iam_role" "firehose" {
  name = "${var.name_prefix}-firehose-lake"

  assume_role_policy = jsonencode({
    Version = "2012-10-17"
    Statement = [{
      Effect    = "Allow"
      Principal = { Service = "firehose.amazonaws.com" }
      Action    = "sts:AssumeRole"
    }]
  })

  tags = var.tags
}

resource "aws_iam_role_policy" "firehose" {
  name = "${var.name_prefix}-firehose-lake"
  role = aws_iam_role.firehose.id

  policy = jsonencode({
    Version = "2012-10-17"
    Statement = [
      {
        Sid    = "ReadStream"
        Effect = "Allow"
        Action = [
          "kinesis:DescribeStream",
          "kinesis:GetShardIterator",
          "kinesis:GetRecords",
          "kinesis:ListShards",
          "kinesis:SubscribeToShard",
        ]
        Resource = aws_kinesis_stream.telemetry.arn
      },
      {
        Sid    = "WriteLake"
        Effect = "Allow"
        Action = [
          "s3:AbortMultipartUpload",
          "s3:GetBucketLocation",
          "s3:GetObject",
          "s3:ListBucket",
          "s3:ListBucketMultipartUploads",
          "s3:PutObject",
        ]
        Resource = [
          var.lake_bucket_arn,
          "${var.lake_bucket_arn}/*",
        ]
      },
      {
        Sid    = "UseLakeKms"
        Effect = "Allow"
        Action = [
          "kms:Encrypt",
          "kms:Decrypt",
          "kms:ReEncrypt*",
          "kms:GenerateDataKey*",
          "kms:DescribeKey",
        ]
        Resource = var.lake_kms_key_arn
      },
      {
        Sid      = "WriteLogs"
        Effect   = "Allow"
        Action   = ["logs:PutLogEvents"]
        Resource = aws_cloudwatch_log_group.firehose.arn
      },
    ]
  })
}

resource "aws_cloudwatch_log_group" "firehose" {
  name              = "/aws/kinesisfirehose/${var.name_prefix}-${var.stream_name}"
  retention_in_days = var.log_retention_days
  tags              = var.tags
}

resource "aws_cloudwatch_log_stream" "firehose" {
  name           = "S3Delivery"
  log_group_name = aws_cloudwatch_log_group.firehose.name
}

resource "aws_kinesis_firehose_delivery_stream" "lake" {
  name        = "${var.name_prefix}-lake-sink"
  destination = "extended_s3"

  kinesis_source_configuration {
    kinesis_stream_arn = aws_kinesis_stream.telemetry.arn
    role_arn           = aws_iam_role.firehose.arn
  }

  extended_s3_configuration {
    role_arn            = aws_iam_role.firehose.arn
    bucket_arn          = var.lake_bucket_arn
    prefix              = "raw/telemetry/dt=!{timestamp:yyyy-MM-dd}/hr=!{timestamp:HH}/"
    error_output_prefix = "raw/_firehose-errors/!{firehose:error-output-type}/dt=!{timestamp:yyyy-MM-dd}/"

    buffering_size     = var.firehose_buffer_size_mb
    buffering_interval = var.firehose_buffer_interval_seconds
    compression_format = "GZIP"

    kms_key_arn = var.lake_kms_key_arn

    cloudwatch_logging_options {
      enabled         = true
      log_group_name  = aws_cloudwatch_log_group.firehose.name
      log_stream_name = aws_cloudwatch_log_stream.firehose.name
    }
  }

  tags = merge(var.tags, {
    Name = "${var.name_prefix}-lake-sink"
  })
}
