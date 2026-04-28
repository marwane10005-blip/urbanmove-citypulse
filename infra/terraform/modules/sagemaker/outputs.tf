output "sagemaker_exec_role_arn" {
  value       = aws_iam_role.sagemaker_exec.arn
  description = "Execution role ARN for SageMaker training jobs"
}

output "glue_role_arn" {
  value       = aws_iam_role.glue.arn
  description = "Glue service role ARN"
}

output "state_machine_arn" {
  value       = aws_sfn_state_machine.ml_pipeline.arn
  description = "Step Functions state machine ARN for the daily ML pipeline"
}

output "schedule_rule_name" {
  value       = aws_cloudwatch_event_rule.daily.name
  description = "EventBridge rule name driving the daily schedule"
}

output "glue_job_name" {
  value       = length(aws_glue_job.etl) > 0 ? aws_glue_job.etl[0].name : null
  description = "Glue job name — null when enable_glue_job=false. (script path: s3://<lake>/jobs/etl.py — upload before first run)"
}

output "endpoint_name" {
  value       = length(aws_sagemaker_endpoint.eta) > 0 ? aws_sagemaker_endpoint.eta[0].name : null
  description = "SageMaker inference endpoint name (null when demo_mode=false)"
}
