output "guardduty_detector_id" {
  value       = var.enable_guardduty ? aws_guardduty_detector.this[0].id : null
  description = "GuardDuty detector ID (null when disabled)"
}

output "security_hub_enabled" {
  value       = var.enable_security_hub
  description = "Whether Security Hub is on"
}

output "macie_account_id" {
  value       = var.enable_macie ? aws_macie2_account.this[0].id : null
  description = "Macie account ID (null when disabled)"
}

output "waf_web_acl_arn" {
  value       = var.enable_waf ? aws_wafv2_web_acl.alb[0].arn : null
  description = "Regional WAF WebACL ARN — attach to ALB in the root composition once the ALB exists"
}

output "waf_web_acl_id" {
  value       = var.enable_waf ? aws_wafv2_web_acl.alb[0].id : null
  description = "WAF WebACL ID (for CloudWatch metric dimensions)"
}
