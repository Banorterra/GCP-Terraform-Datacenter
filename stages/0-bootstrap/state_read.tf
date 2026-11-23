# Read access to the state of EARLIER stages, so a stage can use terraform_remote_state on them.
#
# sa.tf gives each stage SA read/write on its own prefix only. From stage 2 on, every stage reads outputs
# of the stages before it (2 reads 1-org; 3 reads 1-2; 4 reads 1-3; 5 reads 1-4). These bindings add
# READ-ONLY access (objectViewer) to those earlier prefixes, for the stage SA (apply) and its plan SA
# (PR plans). Writing and locking stay limited to the stage's own prefix. Stage 0's state is never shared.

locals {
  stage_order = ["org", "security", "networks", "projects", "workloads"]

  # stage key => state prefixes of the stages before it (only stages that have earlier stages).
  upstream_prefixes = {
    for i, s in local.stage_order :
    s => [for u in slice(local.stage_order, 0, i) : local.state_prefix[u]]
    if i > 0
  }

  # Same two clauses as sa.tf (object name, and list requests by prefix), once per earlier prefix.
  upstream_condition = {
    for s, prefixes in local.upstream_prefixes :
    s => join(" || ", flatten([
      for p in prefixes : [
        "resource.name.startsWith(\"projects/_/buckets/${module.seed_bootstrap.gcs_bucket_tfstate}/objects/${p}/\")",
        "api.getAttribute(\"storage.googleapis.com/objectListPrefix\", \"\").startsWith(\"${p}/\")",
      ]
    ]))
  }
}

resource "google_storage_bucket_iam_member" "stage_upstream_state_read" {
  for_each = local.upstream_prefixes

  bucket = module.seed_bootstrap.gcs_bucket_tfstate
  role   = "roles/storage.objectViewer"
  member = "serviceAccount:${google_service_account.stage[each.key].email}"

  condition {
    title       = "upstream-state-read-${local.state_prefix[each.key]}"
    description = "Read-only access to the state of earlier stages: ${join(", ", each.value)}."
    expression  = local.upstream_condition[each.key]
  }
}

resource "google_storage_bucket_iam_member" "plan_upstream_state_read" {
  for_each = local.upstream_prefixes

  bucket = module.seed_bootstrap.gcs_bucket_tfstate
  role   = "roles/storage.objectViewer"
  member = "serviceAccount:${google_service_account.plan[each.key].email}"

  condition {
    title       = "plan-upstream-state-read-${local.state_prefix[each.key]}"
    description = "Read-only access to the state of earlier stages: ${join(", ", each.value)}."
    expression  = local.upstream_condition[each.key]
  }
}
