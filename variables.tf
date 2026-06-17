variable "customer_name" {
  description = "Slug for the customer (lowercase, digits, hyphen). Used in resource names and labels."
  type        = string

  validation {
    condition     = can(regex("^[a-z][a-z0-9-]{1,29}$", var.customer_name))
    error_message = "customer_name must match ^[a-z][a-z0-9-]{1,29}$ (3-30 chars, lowercase, digits, hyphens; start with letter)."
  }
}

variable "project_id" {
  description = "GCP project ID hosting the GKE cluster."
  type        = string
  default     = "atlanai-dev"
}

variable "region" {
  description = "GCP region for the GKE Autopilot cluster."
  type        = string
  default     = "us-central1"
}

variable "cluster_name" {
  description = "GKE cluster name. Defaults to <customer_name>-gke if empty."
  type        = string
  default     = ""
}

variable "release_channel" {
  description = "GKE release channel."
  type        = string
  default     = "REGULAR"

  validation {
    condition     = contains(["RAPID", "REGULAR", "STABLE"], var.release_channel)
    error_message = "release_channel must be RAPID, REGULAR, or STABLE."
  }
}

variable "network" {
  description = "VPC network to attach the cluster to. 'default' uses the project default VPC."
  type        = string
  default     = "default"
}

variable "subnetwork" {
  description = "Subnetwork. 'default' uses the default subnet in var.region."
  type        = string
  default     = "default"
}

variable "enable_private_endpoint" {
  description = "Use private endpoint for control plane. False = public endpoint with auth."
  type        = bool
  default     = false
}

variable "master_authorized_networks" {
  description = "CIDR ranges allowed to reach the control plane endpoint. Empty = open (with auth)."
  type = list(object({
    cidr_block   = string
    display_name = string
  }))
  default = []
}

variable "labels" {
  description = "Additional labels applied to the cluster."
  type        = map(string)
  default     = {}
}

variable "deletion_protection" {
  description = "Block accidental cluster deletion. Set false for dev/test."
  type        = bool
  default     = false
}
