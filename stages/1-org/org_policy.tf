# Organization policies, Org Policy v2 (google_org_policy_policy).
# Scope is the organization: every folder/project inherits unless explicitly overridden.
# Dry-run is off; policies take effect on apply. Flip var.org_policy_dry_run = true to stage
# a change without enforcement first.

locals {
  org_policy_parent = "organizations/${var.org_id}"

  # Resource Locations allowlist (spec: only our two regions). The constraint matches the
  # in:<value_group> syntax Google uses for multi-region/regional selectors, plus the exact
  # region names so VM/GKE/GCS resources in us-south1 and northamerica-south1 are allowed.
  allowed_locations = [
    "in:${var.primary_region}-locations",
    "in:${var.dr_region}-locations",
  ]

  boolean_enforce_true = {
    # No service account keys on disk (spec hard requirement).
    "iam.disableServiceAccountKeyCreation" = "No SA JSON keys may be created."
    "iam.disableServiceAccountKeyUpload"   = "No external SA keys may be uploaded."

    # No external IPs on Compute VMs (spec hard requirement). Enforced via a separate list
    # policy below (compute.vmExternalIpAccess is a LIST constraint, not boolean).

    # Harden defaults.
    "compute.requireOsLogin"                          = "SSH to VMs only via OS Login."
    "compute.skipDefaultNetworkCreation"              = "New projects do not get a default VPC."
    "compute.disableSerialPortAccess"                 = "No serial console access."
    "compute.disableNestedVirtualization"             = "No nested virtualization on Compute."
    "iam.automaticIamGrantsForDefaultServiceAccounts" = "Default compute SA does not get Editor automatically."
    "storage.uniformBucketLevelAccess"                = "All new GCS buckets use uniform IAM."
    "storage.publicAccessPrevention"                  = "All GCS buckets block public access."
    "sql.restrictPublicIp"                            = "Cloud SQL instances have no public IP."
    "sql.restrictAuthorizedNetworks"                  = "Cloud SQL has no authorized networks."
  }
}

resource "google_org_policy_policy" "boolean_enforce" {
  for_each = local.boolean_enforce_true

  name   = "${local.org_policy_parent}/policies/${each.key}"
  parent = local.org_policy_parent

  spec {
    inherit_from_parent = false

    rules {
      enforce = "TRUE"
    }
  }
}

resource "google_org_policy_policy" "resource_locations" {
  name   = "${local.org_policy_parent}/policies/gcp.resourceLocations"
  parent = local.org_policy_parent

  spec {
    inherit_from_parent = false

    rules {
      values {
        allowed_values = local.allowed_locations
      }
    }
  }
}

# No external IPs on VMs: deny all for compute.vmExternalIpAccess (list constraint).
resource "google_org_policy_policy" "vm_external_ip" {
  name   = "${local.org_policy_parent}/policies/compute.vmExternalIpAccess"
  parent = local.org_policy_parent

  spec {
    inherit_from_parent = false

    rules {
      deny_all = "TRUE"
    }
  }
}
