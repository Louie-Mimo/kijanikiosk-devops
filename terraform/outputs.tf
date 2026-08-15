output "staging_namespace" {
  description = "Terraform-managed staging namespace."
  value       = kubernetes_namespace_v1.kijani_staging.metadata[0].name
}

output "staging_environment" {
  description = "Environment label assigned to the staging namespace."
  value       = kubernetes_namespace_v1.kijani_staging.metadata[0].labels["app.kubernetes.io/environment"]
}

output "verification_command" {
  description = "Command for verifying the staging namespace."
  value       = "kubectl get namespace ${kubernetes_namespace_v1.kijani_staging.metadata[0].name} --show-labels"
}
