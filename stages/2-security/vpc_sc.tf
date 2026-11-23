# VPC Service Controls: a perimeter around the prod projects (spec: "perímetro para proyectos de prod con
# datos sensibles"). Inside it, the restricted APIs (Storage, BigQuery, Cloud SQL, GKE...) only answer
# requests that come from inside the perimeter or from the access level below. In AWS terms it is close to
# VPC endpoint policies plus an SCP with aws:SourceVpc / aws:PrincipalArn conditions on S3 and RDS.
#
# Dry-run by default (var.vpc_sc_enforce = false): violations are only logged (Logging, "VPC Service
# Controls" audit logs), nothing is blocked. Read those logs before enforcing, or the pipeline and Google
# service agents can be cut off.
#
# Projects: stage 2 puts the prod network host project in; stage 4 adds the prod service projects with
# google_access_context_manager_service_perimeter_(dry_run_)resource. That is why the perimeter ignores
# changes to its resource lists.

locals {
  access_policy_id = var.access_policy_id != "" ? var.access_policy_id : google_access_context_manager_access_policy.org[0].name
  perimeter_name   = "accessPolicies/${local.access_policy_id}/servicePerimeters/${var.project_prefix}_prod_perimeter"
  access_level     = "accessPolicies/${local.access_policy_id}/accessLevels/${var.project_prefix}_pipeline"

  perimeter_projects = {
    prod-net-host = local.org.net_host_project_numbers["prod"]
  }
}

# The organization can only have one organization-level access policy. If one already exists, set
# var.access_policy_id to its number instead of creating it (gcloud access-context-manager policies list
# --organization=<org_id>).
resource "google_access_context_manager_access_policy" "org" {
  count = var.access_policy_id == "" ? 1 : 0

  parent = "organizations/${var.org_id}"
  title  = "${var.project_prefix}-org-access-policy"
}

# Who may reach the restricted APIs of the perimeter from outside it: the pipeline (apply and plan SAs).
resource "google_access_context_manager_access_level" "pipeline" {
  parent = "accessPolicies/${local.access_policy_id}"
  name   = local.access_level
  title  = "${var.project_prefix}-pipeline"

  basic {
    conditions {
      members = concat(
        [for sa in values(local.pipeline_sa) : "serviceAccount:${sa}"],
        [for sa in values(local.plan_sa) : "serviceAccount:${sa}"],
      )
    }
  }
}

resource "google_access_context_manager_service_perimeter" "prod" {
  parent         = "accessPolicies/${local.access_policy_id}"
  name           = local.perimeter_name
  title          = "${var.project_prefix}-prod-perimeter"
  description    = "Prod projects with sensitive data. Dry-run unless vpc_sc_enforce = true."
  perimeter_type = "PERIMETER_TYPE_REGULAR"

  # The dry-run config (spec) is always set; the enforced config (status) only when vpc_sc_enforce = true.
  use_explicit_dry_run_spec = true

  spec {
    restricted_services = var.vpc_sc_restricted_services
    access_levels       = [google_access_context_manager_access_level.pipeline.name]
  }

  dynamic "status" {
    for_each = var.vpc_sc_enforce ? [1] : []
    content {
      restricted_services = var.vpc_sc_restricted_services
      access_levels       = [google_access_context_manager_access_level.pipeline.name]
    }
  }

  lifecycle {
    ignore_changes = [spec[0].resources, status[0].resources]
  }
}

resource "google_access_context_manager_service_perimeter_dry_run_resource" "prod" {
  for_each = local.perimeter_projects

  perimeter_name = google_access_context_manager_service_perimeter.prod.name
  resource       = "projects/${each.value}"
}

resource "google_access_context_manager_service_perimeter_resource" "prod" {
  for_each = var.vpc_sc_enforce ? local.perimeter_projects : {}

  perimeter_name = google_access_context_manager_service_perimeter.prod.name
  resource       = "projects/${each.value}"
}
