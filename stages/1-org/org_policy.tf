# Organization policies, Org Policy v2 (google_org_policy_policy).
# Scope is the organization: every folder/project inherits unless explicitly overridden.
# Policies take effect on apply (no dry-run).

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
    "compute.requireShieldedVm"                       = "VMs must be Shielded VMs (spec; also checked by policies/compute.rego)."
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

# Domain restricted sharing: IAM roles can only go to principals of our organization. Blocks, for example,
# granting a role to a personal Gmail account or to allUsers. Allowed:
#   - our Cloud Identity customer (users and groups @banorterra.com), read from the organization;
#   - the organization principal set: service accounts, service agents and workload identity pools
#     (the GitHub pool of stage 0) that belong to resources in this organization.
# Organizations created after May 2024 already have this constraint enforced by default; managing it here
# makes it visible in code and adds the principal set so service agents (e.g. SCC's) can still be granted roles.
# Not retroactive: existing bindings stay, new IAM changes are checked.
data "google_organization" "org" {
  organization = "organizations/${var.org_id}"
}

resource "google_org_policy_policy" "allowed_policy_member_domains" {
  name   = "${local.org_policy_parent}/policies/iam.allowedPolicyMemberDomains"
  parent = local.org_policy_parent

  spec {
    inherit_from_parent = false

    rules {
      values {
        allowed_values = [
          "is:${data.google_organization.org.directory_customer_id}",
          "is:principalSet://iam.googleapis.com/organizations/${var.org_id}",
        ]
      }
    }
  }
}
