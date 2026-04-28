output "cluster_name" {
  value       = module.eks.cluster_name
  description = "EKS cluster name (use for `aws eks update-kubeconfig`)"
}

output "cluster_endpoint" {
  value       = module.eks.cluster_endpoint
  description = "Kubernetes API server URL"
}

output "cluster_certificate_authority_data" {
  value       = module.eks.cluster_certificate_authority_data
  description = "Base64 CA cert for kubeconfig generation"
  sensitive   = true
}

output "cluster_oidc_issuer_url" {
  value       = module.eks.cluster_oidc_issuer_url
  description = "OIDC issuer URL — used to trust-policy-scope IRSA roles"
}

output "oidc_provider_arn" {
  value       = module.eks.oidc_provider_arn
  description = "IAM OIDC provider ARN for IRSA"
}

output "node_security_group_id" {
  value       = module.eks.node_security_group_id
  description = "Primary SG attached to worker nodes — allow this into Aurora/Redis SGs"
}

output "cluster_security_group_id" {
  value       = module.eks.cluster_security_group_id
  description = "Cluster primary SG (control-plane-to-node)"
}
