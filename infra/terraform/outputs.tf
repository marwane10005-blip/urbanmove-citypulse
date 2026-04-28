output "account_id" {
  value = data.aws_caller_identity.current.account_id
}

output "region" {
  value = var.aws_region
}

output "prod_vpc_id" {
  value       = module.network_prod.vpc_id
  description = "VPC ID of the Production App VPC"
}

output "ml_vpc_id" {
  value       = module.network_ml.vpc_id
  description = "VPC ID of the Machine Learning VPC"
}

output "prod_private_subnet_ids" {
  value = module.network_prod.private_subnet_ids
}

output "prod_public_subnet_ids" {
  value = module.network_prod.public_subnet_ids
}

output "dashboard_url" {
  value       = "https://dashboard.${var.environment}.urbanmove.local"
  description = "Primary dashboard URL — populated once the Amplify/EKS stack is up"
}

output "ecr_repository_urls" {
  value       = module.ecr.repository_urls
  description = "Map of service name → ECR repository URL"
}

output "lake_bucket" {
  value       = module.s3_lake.bucket_id
  description = "Data lake S3 bucket name"
}

output "lake_kms_key_arn" {
  value       = module.s3_lake.kms_key_arn
  description = "KMS CMK ARN guarding the data lake"
}

output "kinesis_stream_name" {
  value       = module.kinesis.stream_name
  description = "Telemetry Kinesis Data Stream name"
}

output "kinesis_leases_table" {
  value       = module.kinesis.leases_table_name
  description = "DynamoDB table backing stream-processor KCL leases"
}

output "iot_endpoint" {
  value       = module.iot.endpoint_data_ats
  description = "IoT Core MQTT endpoint devices connect to"
}

output "iot_device_policy" {
  value       = module.iot.device_policy_name
  description = "IoT policy attached to device certs at provisioning time"
}

output "cognito_user_pool_id" {
  value       = module.cognito.user_pool_id
  description = "Cognito User Pool ID (FastAPI services validate JWTs against this pool's JWKS)"
}

output "cognito_dashboard_client_id" {
  value       = module.cognito.dashboard_client_id
  description = "Cognito app client ID the Next.js dashboard uses"
}

output "cognito_issuer" {
  value       = module.cognito.user_pool_endpoint
  description = "JWT issuer URL"
}

output "db_secret_arn" {
  value       = module.secrets.db_secret_arn
  description = "Secrets Manager ARN holding Aurora master credentials"
}

output "aurora_endpoint" {
  value       = module.aurora.cluster_endpoint
  description = "Aurora writer endpoint (read/write)"
}

output "aurora_reader_endpoint" {
  value       = module.aurora.cluster_reader_endpoint
  description = "Aurora reader endpoint (round-robin across readers)"
}

output "aurora_database_name" {
  value       = module.aurora.database_name
  description = "Default Aurora database name"
}

output "aurora_security_group_id" {
  value       = module.aurora.security_group_id
  description = "SG ID to reference from EKS node security groups"
}

output "eks_cluster_name" {
  value       = module.eks.cluster_name
  description = "EKS cluster name (`aws eks update-kubeconfig --name <this>`)"
}

output "eks_cluster_endpoint" {
  value       = module.eks.cluster_endpoint
  description = "Kubernetes API server URL"
}

output "eks_oidc_provider_arn" {
  value       = module.eks.oidc_provider_arn
  description = "OIDC provider ARN (IRSA trust-policy scope)"
}

output "alerts_topic_arn" {
  value       = module.observability.alerts_topic_arn
  description = "SNS topic ARN for all urbanmove alerts"
}

output "cloudwatch_dashboard" {
  value       = module.observability.dashboard_name
  description = "CloudWatch dashboard name — open via the Console"
}

output "ml_pipeline_state_machine_arn" {
  value       = module.sagemaker.state_machine_arn
  description = "Step Functions ARN for the daily ML pipeline"
}

output "ml_glue_job_name" {
  value       = module.sagemaker.glue_job_name
  description = "Glue ETL job name (upload the PySpark script to s3:
}

output "sagemaker_exec_role_arn" {
  value       = module.sagemaker.sagemaker_exec_role_arn
  description = "Execution role the SageMaker training jobs assume"
}

output "sagemaker_endpoint_name" {
  value       = module.sagemaker.endpoint_name
  description = "SageMaker inference endpoint name (null when demo_mode=false)"
}

output "redis_endpoint" {
  value       = module.redis.endpoint
  description = "Redis primary endpoint (null when expensive_on=false)"
}

output "waf_web_acl_arn" {
  value       = module.security.waf_web_acl_arn
  description = "Regional WAF WebACL ARN — attach to ALB Ingress in a follow-up apply once the ALB ARN is known"
}

output "guardduty_detector_id" {
  value       = module.security.guardduty_detector_id
  description = "GuardDuty detector ID"
}
