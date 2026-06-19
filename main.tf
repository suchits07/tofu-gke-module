locals {
  cluster_name_effective = var.cluster_name != "" ? var.cluster_name : "${var.customer_name}-gke"

  labels = merge(
    {
      managed-by    = "tofu-controller"
      customer      = var.customer_name
      provisioned   = "onboard-customer-job"
    },
    var.labels,
  )
}

provider "google" {
  project = var.project_id
  region  = var.region
}

resource "google_container_cluster" "this" {
  name     = local.cluster_name_effective
  location = var.region
  project  = var.project_id

  enable_autopilot    = true
  deletion_protection = var.deletion_protection

  network    = var.network
  subnetwork = var.subnetwork

  release_channel {
    channel = var.release_channel
  }

  private_cluster_config {
    enable_private_nodes    = true
    enable_private_endpoint = var.enable_private_endpoint
    master_ipv4_cidr_block  = ""
  }

  dynamic "master_authorized_networks_config" {
    for_each = length(var.master_authorized_networks) > 0 ? [1] : []
    content {
      dynamic "cidr_blocks" {
        for_each = var.master_authorized_networks
        content {
          cidr_block   = cidr_blocks.value.cidr_block
          display_name = cidr_blocks.value.display_name
        }
      }
    }
  }

  workload_identity_config {
    workload_pool = "${var.project_id}.svc.id.goog"
  }

  resource_labels = local.labels

  lifecycle {
    ignore_changes = [
      node_pool,
      initial_node_count,
    ]
  }
}

# Devtron deployer SA inside the customer cluster
provider "kubernetes" {
  host                   = "https://${google_container_cluster.this.endpoint}"
  cluster_ca_certificate = base64decode(google_container_cluster.this.master_auth[0].cluster_ca_certificate)
  token                  = data.google_client_config.this.access_token
}

data "google_client_config" "this" {}

resource "kubernetes_service_account" "devtron_deployer" {
  metadata {
    name      = "devtron-deployer"
    namespace = "default"
  }
  depends_on = [google_container_cluster.this]
}

resource "kubernetes_cluster_role_binding" "devtron_deployer" {
  metadata {
    name = "devtron-deployer"
  }
  role_ref {
    api_group = "rbac.authorization.k8s.io"
    kind      = "ClusterRole"
    name      = "cluster-admin"
  }
  subject {
    kind      = "ServiceAccount"
    name      = kubernetes_service_account.devtron_deployer.metadata[0].name
    namespace = kubernetes_service_account.devtron_deployer.metadata[0].namespace
  }
}

resource "kubernetes_secret" "devtron_deployer_token" {
  metadata {
    name      = "devtron-deployer-token"
    namespace = "default"
    annotations = {
      "kubernetes.io/service-account.name" = kubernetes_service_account.devtron_deployer.metadata[0].name
    }
  }
  type                           = "kubernetes.io/service-account-token"
  wait_for_service_account_token = true
}
