variable "staging_namespace" {
  description = "Kubernetes namespace used for the KijaniKiosk staging environment."
  type        = string
  default     = "kijani-staging"

  validation {
    condition     = var.staging_namespace == "kijani-staging"
    error_message = "The capstone staging namespace must be named kijani-staging."
  }
}

variable "kubeconfig_path" {
  description = "Path to the kubeconfig used by Terraform."
  type        = string
  default     = "~/.kube/config"
}

variable "kube_context" {
  description = "Kubernetes context used for the capstone environment."
  type        = string
  default     = "minikube"
}
