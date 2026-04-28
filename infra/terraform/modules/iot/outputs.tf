output "thing_type_name" {
  value       = aws_iot_thing_type.vehicle.name
  description = "IoT Thing Type devices register as"
}

output "device_policy_name" {
  value       = aws_iot_policy.device.name
  description = "IoT policy attached to device certificates at provisioning time"
}

output "rule_name" {
  value       = aws_iot_topic_rule.ingest.name
  description = "IoT Rule forwarding MQTT → Kinesis"
}

output "rule_role_arn" {
  value       = aws_iam_role.iot_rule.arn
  description = "IAM role the IoT Rule assumes"
}

output "endpoint_data_ats" {
  value       = data.aws_iot_endpoint.data_ats.endpoint_address
  description = "IoT Core data endpoint (ATS) — devices connect here via MQTT"
}
