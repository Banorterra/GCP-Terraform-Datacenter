# Mandatory labels (spec): env, app, owner, cost_center, managed_by = "terraform".
# env and managed_by (and owner/cost_center from var.labels) are applied to every resource by the
# provider; each resource adds its own `app` label. policies/labels.rego enforces this on the plan.
provider "google" {
  region = var.primary_region

  default_labels = merge(var.labels, {
    env        = var.environment
    managed_by = "terraform"
  })
}

provider "google-beta" {
  region = var.primary_region

  default_labels = merge(var.labels, {
    env        = var.environment
    managed_by = "terraform"
  })
}
