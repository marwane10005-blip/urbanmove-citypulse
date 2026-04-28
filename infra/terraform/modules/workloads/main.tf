data "aws_caller_identity" "current" {}
data "aws_region" "current" {}
data "aws_partition" "current" {}

data "aws_iam_policy_document" "pod_identity_trust" {
  statement {
    effect  = "Allow"
    actions = ["sts:AssumeRole", "sts:TagSession"]
    principals {
      type        = "Service"
      identifiers = ["pods.eks.amazonaws.com"]
    }
  }
}

locals {
  services = {
    simulator            = "simulator"
    mobility-api         = "mobility-api"
    identity-fleet       = "identity-fleet"
    analytics-dashboard  = "analytics-dashboard"
    stream-processor     = "stream-processor"
    db-migrate           = "db-migrate"
  }
}

resource "aws_iam_role" "mobility_api" {
  name               = "${var.name_prefix}-mobility-api"
  assume_role_policy = data.aws_iam_policy_document.pod_identity_trust.json
  tags               = var.tags
}

resource "aws_iam_role_policy" "mobility_api" {
  name = "${var.name_prefix}-mobility-api"
  role = aws_iam_role.mobility_api.id

  policy = jsonencode({
    Version = "2012-10-17"
    Statement = [
      {
        Sid      = "ReadAuroraSecret"
        Effect   = "Allow"
        Action   = ["secretsmanager:GetSecretValue", "secretsmanager:DescribeSecret"]
        Resource = var.aurora_secret_arn
      },
      {
        Sid    = "InvokeSageMaker"
        Effect = "Allow"
        Action = ["sagemaker:InvokeEndpoint"]
        Resource = "arn:${data.aws_partition.current.partition}:sagemaker:${data.aws_region.current.name}:${data.aws_caller_identity.current.account_id}:endpoint/${var.sagemaker_endpoint_name}"
      },
    ]
  })
}

resource "aws_eks_pod_identity_association" "mobility_api" {
  cluster_name    = var.cluster_name
  namespace       = var.namespace
  service_account = "mobility-api"
  role_arn        = aws_iam_role.mobility_api.arn
  tags            = var.tags
}

resource "aws_iam_role" "identity_fleet" {
  name               = "${var.name_prefix}-identity-fleet"
  assume_role_policy = data.aws_iam_policy_document.pod_identity_trust.json
  tags               = var.tags
}

resource "aws_iam_role_policy" "identity_fleet" {
  name = "${var.name_prefix}-identity-fleet"
  role = aws_iam_role.identity_fleet.id

  policy = jsonencode({
    Version = "2012-10-17"
    Statement = [
      {
        Sid    = "ListAndAdminUsers"
        Effect = "Allow"
        Action = [
          "cognito-idp:ListUsers",
          "cognito-idp:AdminGetUser",
          "cognito-idp:AdminCreateUser",
          "cognito-idp:AdminAddUserToGroup",
          "cognito-idp:AdminRemoveUserFromGroup",
          "cognito-idp:ListGroups",
        ]
        Resource = var.cognito_user_pool_arn
      },
      {
        Sid      = "ReadAuroraSecret"
        Effect   = "Allow"
        Action   = ["secretsmanager:GetSecretValue"]
        Resource = var.aurora_secret_arn
      },
    ]
  })
}

resource "aws_eks_pod_identity_association" "identity_fleet" {
  cluster_name    = var.cluster_name
  namespace       = var.namespace
  service_account = "identity-fleet"
  role_arn        = aws_iam_role.identity_fleet.arn
  tags            = var.tags
}

resource "aws_iam_role" "stream_processor" {
  name               = "${var.name_prefix}-stream-processor"
  assume_role_policy = data.aws_iam_policy_document.pod_identity_trust.json
  tags               = var.tags
}

resource "aws_iam_role_policy" "stream_processor" {
  name = "${var.name_prefix}-stream-processor"
  role = aws_iam_role.stream_processor.id

  policy = jsonencode({
    Version = "2012-10-17"
    Statement = [
      {
        Sid    = "KinesisReadWrite"
        Effect = "Allow"
        Action = [
          "kinesis:DescribeStream",
          "kinesis:DescribeStreamSummary",
          "kinesis:GetShardIterator",
          "kinesis:GetRecords",
          "kinesis:ListShards",
          "kinesis:SubscribeToShard",
          "kinesis:PutRecord",
          "kinesis:PutRecords",
        ]
        Resource = var.kinesis_stream_arn
      },
      {
        Sid    = "LeaseCoordination"
        Effect = "Allow"
        Action = [
          "dynamodb:GetItem",
          "dynamodb:PutItem",
          "dynamodb:UpdateItem",
          "dynamodb:DeleteItem",
          "dynamodb:Query",
          "dynamodb:Scan",
        ]
        Resource = var.kinesis_leases_table_arn
      },
      {
        Sid      = "ReadAuroraSecret"
        Effect   = "Allow"
        Action   = ["secretsmanager:GetSecretValue"]
        Resource = var.aurora_secret_arn
      },
    ]
  })
}

resource "aws_eks_pod_identity_association" "stream_processor" {
  cluster_name    = var.cluster_name
  namespace       = var.namespace
  service_account = "stream-processor"
  role_arn        = aws_iam_role.stream_processor.arn
  tags            = var.tags
}

resource "aws_iam_role" "analytics_dashboard" {
  name               = "${var.name_prefix}-analytics-dashboard"
  assume_role_policy = data.aws_iam_policy_document.pod_identity_trust.json
  tags               = var.tags
}

resource "aws_iam_role_policy" "analytics_dashboard" {
  name = "${var.name_prefix}-analytics-dashboard"
  role = aws_iam_role.analytics_dashboard.id

  policy = jsonencode({
    Version = "2012-10-17"
    Statement = [
      {
        Sid    = "KinesisRead"
        Effect = "Allow"
        Action = [
          "kinesis:DescribeStream",
          "kinesis:DescribeStreamSummary",
          "kinesis:GetShardIterator",
          "kinesis:GetRecords",
          "kinesis:ListShards",
        ]
        Resource = var.kinesis_stream_arn
      },
      {
        Sid      = "AthenaQuery"
        Effect   = "Allow"
        Action   = ["athena:StartQueryExecution", "athena:GetQueryExecution", "athena:GetQueryResults"]
        Resource = "*"
      },
      {
        Sid    = "LakeRead"
        Effect = "Allow"
        Action = ["s3:GetObject", "s3:ListBucket"]
        Resource = [
          var.lake_bucket_arn,
          "${var.lake_bucket_arn}/*",
        ]
      },
      {
        Sid      = "LakeKms"
        Effect   = "Allow"
        Action   = ["kms:Decrypt", "kms:DescribeKey"]
        Resource = var.lake_kms_key_arn
      },
    ]
  })
}

resource "aws_eks_pod_identity_association" "analytics_dashboard" {
  cluster_name    = var.cluster_name
  namespace       = var.namespace
  service_account = "analytics-dashboard"
  role_arn        = aws_iam_role.analytics_dashboard.arn
  tags            = var.tags
}

resource "aws_iam_role" "simulator" {
  name               = "${var.name_prefix}-simulator"
  assume_role_policy = data.aws_iam_policy_document.pod_identity_trust.json
  tags               = var.tags
}

resource "aws_iam_role_policy" "simulator" {
  name = "${var.name_prefix}-simulator"
  role = aws_iam_role.simulator.id

  policy = jsonencode({
    Version = "2012-10-17"
    Statement = [{
      Sid      = "ReadIoTCertSecret"
      Effect   = "Allow"
      Action   = ["secretsmanager:GetSecretValue", "secretsmanager:DescribeSecret"]
      Resource = "arn:${data.aws_partition.current.partition}:secretsmanager:${data.aws_region.current.name}:${data.aws_caller_identity.current.account_id}:secret:${var.name_prefix}/${var.iot_cert_secret_name}-*"
    }]
  })
}

resource "aws_eks_pod_identity_association" "simulator" {
  cluster_name    = var.cluster_name
  namespace       = var.namespace
  service_account = "simulator"
  role_arn        = aws_iam_role.simulator.arn
  tags            = var.tags
}

resource "aws_iam_role" "db_migrate" {
  name               = "${var.name_prefix}-db-migrate"
  assume_role_policy = data.aws_iam_policy_document.pod_identity_trust.json
  tags               = var.tags
}

resource "aws_iam_role_policy" "db_migrate" {
  name = "${var.name_prefix}-db-migrate"
  role = aws_iam_role.db_migrate.id

  policy = jsonencode({
    Version = "2012-10-17"
    Statement = [{
      Sid      = "ReadAuroraSecret"
      Effect   = "Allow"
      Action   = ["secretsmanager:GetSecretValue"]
      Resource = var.aurora_secret_arn
    }]
  })
}

resource "aws_eks_pod_identity_association" "db_migrate" {
  cluster_name    = var.cluster_name
  namespace       = var.namespace
  service_account = "db-migrate"
  role_arn        = aws_iam_role.db_migrate.arn
  tags            = var.tags
}
