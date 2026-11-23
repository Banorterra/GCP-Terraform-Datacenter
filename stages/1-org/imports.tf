# Policies Google already created in the organization.
#
# Organizations created after May 2024 come with "secure by default" policies. Four of them use the
# same constraints we manage, so creating them failed with 409 "already exists" on the first apply.
# These import blocks adopt the existing policies into the state; after that Terraform manages
# them with our spec (they enforce the same thing, so the import does not weaken anything).
#
# The blocks can stay: once imported, Terraform ignores them.

locals {
  preexisting_boolean_policies = toset([
    "iam.automaticIamGrantsForDefaultServiceAccounts",
    "iam.disableServiceAccountKeyUpload",
    "storage.uniformBucketLevelAccess",
  ])
}

import {
  for_each = local.preexisting_boolean_policies
  to       = google_org_policy_policy.boolean_enforce[each.value]
  id       = "organizations/${var.org_id}/policies/${each.value}"
}

import {
  to = google_org_policy_policy.allowed_policy_member_domains
  id = "organizations/${var.org_id}/policies/iam.allowedPolicyMemberDomains"
}
