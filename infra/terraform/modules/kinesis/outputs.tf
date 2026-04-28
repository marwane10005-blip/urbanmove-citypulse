output "stream_name" {
  value       = aws_kinesis_stream.telemetry.name
  description = "Kinesis Data Stream name"
}

output "stream_arn" {
  value       = aws_kinesis_stream.telemetry.arn
  description = "Kinesis Data Stream ARN"
}

output "leases_table_name" {
  value       = aws_dynamodb_table.leases.name
  description = "DynamoDB table backing stream-processor shard leases"
}

output "leases_table_arn" {
  value       = aws_dynamodb_table.leases.arn
  description = "DynamoDB table ARN for IAM policies"
}

output "firehose_name" {
  value       = aws_kinesis_firehose_delivery_stream.lake.name
  description = "Firehose delivery stream name"
}

output "firehose_arn" {
  value       = aws_kinesis_firehose_delivery_stream.lake.arn
  description = "Firehose delivery stream ARN"
}

output "firehose_role_arn" {
  value       = aws_iam_role.firehose.arn
  description = "IAM role assumed by Firehose (reuse if attaching extra policies externally)"
}
