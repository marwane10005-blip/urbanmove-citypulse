data "aws_caller_identity" "current" {}
data "aws_region" "current" {}

resource "aws_iam_role" "sagemaker_exec" {
  name = "${var.name_prefix}-sagemaker-exec"

  assume_role_policy = jsonencode({
    Version = "2012-10-17"
    Statement = [{
      Effect    = "Allow"
      Principal = { Service = "sagemaker.amazonaws.com" }
      Action    = "sts:AssumeRole"
    }]
  })

  tags = var.tags
}

resource "aws_iam_role_policy" "sagemaker_exec" {
  name = "${var.name_prefix}-sagemaker-exec"
  role = aws_iam_role.sagemaker_exec.id

  policy = jsonencode({
    Version = "2012-10-17"
    Statement = [
      {
        Sid    = "LakeReadWrite"
        Effect = "Allow"
        Action = [
          "s3:GetObject",
          "s3:PutObject",
          "s3:DeleteObject",
          "s3:ListBucket",
        ]
        Resource = [
          var.lake_bucket_arn,
          "${var.lake_bucket_arn}/*",
        ]
      },
      {
        Sid    = "LakeKms"
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
        Sid    = "CloudWatchLogs"
        Effect = "Allow"
        Action = [
          "logs:CreateLogGroup",
          "logs:CreateLogStream",
          "logs:PutLogEvents",
          "logs:DescribeLogStreams",
        ]
        Resource = "*"
      },
      {
        Sid    = "ECRPullTraining"
        Effect = "Allow"
        Action = [
          "ecr:GetAuthorizationToken",
          "ecr:BatchCheckLayerAvailability",
          "ecr:GetDownloadUrlForLayer",
          "ecr:BatchGetImage",
        ]
        Resource = "*"
      },
    ]
  })
}

resource "aws_iam_role" "glue" {
  name = "${var.name_prefix}-glue-etl"

  assume_role_policy = jsonencode({
    Version = "2012-10-17"
    Statement = [{
      Effect    = "Allow"
      Principal = { Service = "glue.amazonaws.com" }
      Action    = "sts:AssumeRole"
    }]
  })

  tags = var.tags
}

resource "aws_iam_role_policy_attachment" "glue_service" {
  role       = aws_iam_role.glue.name
  policy_arn = "arn:aws:iam::aws:policy/service-role/AWSGlueServiceRole"
}

resource "aws_iam_role_policy" "glue_lake_access" {
  name = "${var.name_prefix}-glue-lake-access"
  role = aws_iam_role.glue.id

  policy = jsonencode({
    Version = "2012-10-17"
    Statement = [
      {
        Effect = "Allow"
        Action = [
          "s3:GetObject",
          "s3:PutObject",
          "s3:DeleteObject",
          "s3:ListBucket",
        ]
        Resource = [
          var.lake_bucket_arn,
          "${var.lake_bucket_arn}/*",
        ]
      },
      {
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
    ]
  })
}

resource "aws_iam_role" "stepfn" {
  name = "${var.name_prefix}-stepfn-ml"

  assume_role_policy = jsonencode({
    Version = "2012-10-17"
    Statement = [{
      Effect    = "Allow"
      Principal = { Service = "states.amazonaws.com" }
      Action    = "sts:AssumeRole"
    }]
  })

  tags = var.tags
}

resource "aws_iam_role_policy" "stepfn" {
  name = "${var.name_prefix}-stepfn-ml"
  role = aws_iam_role.stepfn.id

  policy = jsonencode({
    Version = "2012-10-17"
    Statement = [
      {
        Sid    = "InvokeGlue"
        Effect = "Allow"
        Action = [
          "glue:StartJobRun",
          "glue:GetJobRun",
          "glue:GetJobRuns",
          "glue:BatchStopJobRun",
        ]
        Resource = "*"
      },
      {
        Sid    = "InvokeSageMaker"
        Effect = "Allow"
        Action = [
          "sagemaker:CreateTrainingJob",
          "sagemaker:DescribeTrainingJob",
          "sagemaker:StopTrainingJob",
          "sagemaker:CreateModel",
          "sagemaker:CreateEndpointConfig",
          "sagemaker:UpdateEndpoint",
          "sagemaker:DescribeEndpoint",
        ]
        Resource = "*"
      },
      {
        Sid    = "PassExecutionRole"
        Effect = "Allow"
        Action = "iam:PassRole"
        Resource = [
          aws_iam_role.sagemaker_exec.arn,
          aws_iam_role.glue.arn,
        ]
      },
    ]
  })
}

resource "aws_glue_job" "etl" {
  count    = var.enable_glue_job ? 1 : 0
  name     = "${var.name_prefix}-etl-telemetry"
  role_arn = aws_iam_role.glue.arn

  command {
    script_location = "s3://${regex("arn:aws:s3:::(.+)", var.lake_bucket_arn)[0]}/jobs/etl.py"
    python_version  = "3"
  }

  glue_version      = "4.0"
  worker_type       = "G.1X"
  number_of_workers = 2
  timeout           = 30

  default_arguments = {
    "--job-language"                     = "python"
    "--enable-metrics"                   = "true"
    "--enable-continuous-cloudwatch-log" = "true"
    "--lake-bucket"                      = regex("arn:aws:s3:::(.+)", var.lake_bucket_arn)[0]
  }

  tags = merge(var.tags, {
    Name = "${var.name_prefix}-etl-telemetry"
  })
}

resource "aws_sfn_state_machine" "ml_pipeline" {
  name     = "${var.name_prefix}-ml-pipeline"
  role_arn = aws_iam_role.stepfn.arn

  definition = var.enable_glue_job ? jsonencode({
    Comment = "UrbanMove daily ML pipeline — Glue ETL → SageMaker training → endpoint update."
    StartAt = "RunGlueETL"
    States = {
      RunGlueETL = {
        Type       = "Task"
        Resource   = "arn:aws:states:::glue:startJobRun.sync"
        Parameters = { JobName = try(aws_glue_job.etl[0].name, "") }
        Next       = "TrainingPlaceholder"
        Retry = [{
          ErrorEquals     = ["States.ALL"]
          IntervalSeconds = 30
          MaxAttempts     = 2
        }]
        Catch = [{
          ErrorEquals = ["States.ALL"]
          Next        = "NotifyFailure"
        }]
      }
      TrainingPlaceholder = {
        Type   = "Pass"
        Result = { message = "SageMaker training step — TODO: swap Pass for CreateTrainingJob.sync" }
        End    = true
      }
      NotifyFailure = {
        Type  = "Fail"
        Cause = "Pipeline step failed"
        Error = "MLPipelineError"
      }
    }
    }) : jsonencode({
    Comment = "UrbanMove daily ML pipeline (Glue disabled — enable_glue_job=false)."
    StartAt = "RunGlueETL"
    States = {
      RunGlueETL = {
        Type   = "Pass"
        Result = { message = "Glue ETL skipped (enable_glue_job=false)" }
        Next   = "TrainingPlaceholder"
      }
      TrainingPlaceholder = {
        Type   = "Pass"
        Result = { message = "SageMaker training step — TODO: swap Pass for CreateTrainingJob.sync" }
        End    = true
      }
    }
  })

  tags = var.tags
}

resource "aws_iam_role" "eventbridge_stepfn" {
  name = "${var.name_prefix}-eventbridge-stepfn"

  assume_role_policy = jsonencode({
    Version = "2012-10-17"
    Statement = [{
      Effect    = "Allow"
      Principal = { Service = "events.amazonaws.com" }
      Action    = "sts:AssumeRole"
    }]
  })

  tags = var.tags
}

resource "aws_iam_role_policy" "eventbridge_stepfn" {
  name = "${var.name_prefix}-eventbridge-stepfn"
  role = aws_iam_role.eventbridge_stepfn.id

  policy = jsonencode({
    Version = "2012-10-17"
    Statement = [{
      Effect   = "Allow"
      Action   = "states:StartExecution"
      Resource = aws_sfn_state_machine.ml_pipeline.arn
    }]
  })
}

resource "aws_cloudwatch_event_rule" "daily" {
  name                = "${var.name_prefix}-ml-pipeline-daily"
  description         = "Fires the daily ML training pipeline"
  schedule_expression = var.schedule_expression
  state               = var.schedule_enabled ? "ENABLED" : "DISABLED"

  tags = var.tags
}

resource "aws_cloudwatch_event_target" "daily" {
  rule     = aws_cloudwatch_event_rule.daily.name
  arn      = aws_sfn_state_machine.ml_pipeline.arn
  role_arn = aws_iam_role.eventbridge_stepfn.arn
}

data "aws_sagemaker_prebuilt_ecr_image" "sklearn" {
  repository_name = "sagemaker-scikit-learn"
  image_tag       = "1.2-1-cpu-py3"
}

resource "aws_sagemaker_model" "eta" {
  count              = var.demo_mode ? 1 : 0
  name               = "${var.name_prefix}-eta-model"
  execution_role_arn = aws_iam_role.sagemaker_exec.arn

  primary_container {
    image          = data.aws_sagemaker_prebuilt_ecr_image.sklearn.registry_path
    model_data_url = "s3://${regex("arn:aws:s3:::(.+)", var.lake_bucket_arn)[0]}/model-artifacts/eta/model.tar.gz"
    environment = {
      SAGEMAKER_PROGRAM           = "inference.py"
      SAGEMAKER_SUBMIT_DIRECTORY  = "/opt/ml/model/code"
      SAGEMAKER_CONTAINER_LOG_LEVEL = "20"
    }
  }

  tags = var.tags
}

resource "aws_sagemaker_endpoint_configuration" "eta" {
  count = var.demo_mode ? 1 : 0
  name  = "${var.name_prefix}-eta-config"

  production_variants {
    variant_name           = "AllTraffic"
    model_name             = aws_sagemaker_model.eta[0].name
    initial_instance_count = 1
    instance_type          = "ml.t2.medium"
    initial_variant_weight = 1
  }

  tags = var.tags
}

resource "aws_sagemaker_endpoint" "eta" {
  count                = var.demo_mode ? 1 : 0
  name                 = "${var.name_prefix}-eta"
  endpoint_config_name = aws_sagemaker_endpoint_configuration.eta[0].name

  tags = var.tags
}
