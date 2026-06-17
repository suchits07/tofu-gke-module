output "cluster_name" {
  description = "GKE cluster name."
  value       = google_container_cluster.this.name
}

output "endpoint" {
  description = "GKE control-plane endpoint (no scheme)."
  value       = google_container_cluster.this.endpoint
}

output "ca_certificate" {
  description = "Base64-encoded cluster CA cert (PEM)."
  value       = google_container_cluster.this.master_auth[0].cluster_ca_certificate
  sensitive   = true
}

output "bearer_token" {
  description = "Bearer token for the devtron-deployer ServiceAccount."
  value       = kubernetes_secret.devtron_deployer_token.data["token"]
  sensitive   = true
}

output "kubeconfig" {
  description = "Base64-encoded kubeconfig YAML using bearer_token."
  sensitive   = true
  value = base64encode(yamlencode({
    apiVersion = "v1"
    kind       = "Config"
    clusters = [{
      name = google_container_cluster.this.name
      cluster = {
        "certificate-authority-data" = google_container_cluster.this.master_auth[0].cluster_ca_certificate
        server                       = "https://${google_container_cluster.this.endpoint}"
      }
    }]
    users = [{
      name = "devtron-deployer"
      user = {
        token = kubernetes_secret.devtron_deployer_token.data["token"]
      }
    }]
    contexts = [{
      name = google_container_cluster.this.name
      context = {
        cluster = google_container_cluster.this.name
        user    = "devtron-deployer"
      }
    }]
    "current-context" = google_container_cluster.this.name
  }))
}
