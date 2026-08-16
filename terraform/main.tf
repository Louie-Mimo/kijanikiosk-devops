terraform {
  required_version = ">= 1.5.0"

  required_providers {
    kubernetes = {
      source = "hashicorp/kubernetes"
    }
  }
}

provider "kubernetes" {
  config_path    = pathexpand(var.kubeconfig_path)
  config_context = var.kube_context
}

resource "kubernetes_namespace_v1" "kijani_staging" {
  metadata {
    name = var.staging_namespace

    labels = {
      "app.kubernetes.io/part-of"     = "kijanikiosk"
      "app.kubernetes.io/environment" = "staging"
      "managed-by"                    = "terraform"
    }
  }
}
