# tofu-gke-module

OpenTofu module that provisions a GKE Autopilot cluster on GCP and prepares it for Devtron to deploy workloads onto.

Owned by Atlan Foundation Platform. Consumed by [tofu-controller](https://flux-iac.github.io/tofu-controller/) via the `terraform-cr` Helm chart in [suchits07/devtron-charts](https://github.com/suchits07/devtron-charts).

## What it creates

- 1× GKE Autopilot cluster (`google_container_cluster`) in the target project + region
  - Workload Identity enabled (`<project>.svc.id.goog` pool)
  - Release channel configurable (default `REGULAR`)
  - Private nodes, public control-plane endpoint by default
- 1× `ServiceAccount` `devtron-deployer` in `kube-system` on the new cluster
- 1× `ClusterRoleBinding` granting `cluster-admin` to the SA
- 1× `Secret` of type `kubernetes.io/service-account-token` containing the bearer token

## Inputs

| Name | Type | Default | Required |
|---|---|---|---|
| `customer_name` | string | — | yes |
| `project_id` | string | `atlanai-dev` | no |
| `region` | string | `us-central1` | no |
| `cluster_name` | string | `<customer>-gke` | no |
| `release_channel` | string | `REGULAR` | no |
| `network` | string | `default` | no |
| `subnetwork` | string | `default` | no |
| `enable_private_endpoint` | bool | `false` | no |
| `master_authorized_networks` | list(object) | `[]` | no |
| `labels` | map(string) | `{}` | no |
| `deletion_protection` | bool | `false` | no |

## Outputs

| Name | Sensitive | Notes |
|---|---|---|
| `cluster_name` | no | Final cluster name |
| `endpoint` | no | Control plane IP (no scheme) |
| `ca_certificate` | yes | Base64 PEM |
| `bearer_token` | yes | Devtron-deployer SA token |
| `kubeconfig` | yes | Base64 YAML, ready to drop into `~/.kube/config` |

## State backend

Designed for GCS backend, configured at runtime by tofu-controller via `backendConfig.customConfiguration`:

```hcl
backend "gcs" {
  bucket = "atlan-tf-state"
  prefix = "customers/<customer>"
}
```

The `backend.tf` in this module is intentionally empty (`backend "gcs" {}`) — tofu-controller injects the config at runtime.

## Auth

tofu-controller runner pod uses Workload Identity:
- K8s SA: `flux-system/tf-runner`
- Annotated with `iam.gke.io/gcp-service-account: tf-runner@atlanai-dev.iam.gserviceaccount.com`
- Bound to `roles/container.admin`, `roles/iam.serviceAccountUser`, `roles/compute.networkUser`, `roles/storage.objectAdmin` (scoped to `atlan-tf-state`)

## Local testing

```bash
export GOOGLE_APPLICATION_CREDENTIALS=~/path/to/key.json

tofu init \
  -backend-config="bucket=atlan-tf-state" \
  -backend-config="prefix=customers/test"

tofu plan \
  -var customer_name=test \
  -var project_id=atlanai-dev

tofu apply \
  -var customer_name=test \
  -var project_id=atlanai-dev
```

## Caveats

- GKE Autopilot enforces resource floors on pods — runner pod cost is non-zero even when idle
- `deletion_protection` is `false` by default for dev/test convenience; flip to `true` for any production customer
- Bearer-token auth in v1 (see ADR-002); WIF migration in v2
