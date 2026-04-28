output "bucket_id" {
  value       = aws_s3_bucket.lake.id
  description = "Bucket name (equal to var.name)"
}

output "bucket_arn" {
  value       = aws_s3_bucket.lake.arn
  description = "Bucket ARN"
}

output "bucket_domain_name" {
  value       = aws_s3_bucket.lake.bucket_regional_domain_name
  description = "Regional domain name for VPC endpoint / CloudFront origin use"
}

output "kms_key_id" {
  value       = aws_kms_key.lake.key_id
  description = "KMS CMK ID used for bucket encryption"
}

output "kms_key_arn" {
  value       = aws_kms_key.lake.arn
  description = "KMS CMK ARN used for bucket encryption"
}

output "kms_alias" {
  value       = aws_kms_alias.lake.name
  description = "Human-friendly KMS alias"
}
