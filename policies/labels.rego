package main

import rego.v1

# Spec: every resource must carry env, app, owner, cost_center and managed_by = "terraform".
# Run with: conftest test tfplan.json --policy policies
#
# Known limit: if a label value is computed (unknown at plan time) the label can look missing.
# Treat such a finding as "verify", not as a hard failure, until we see it in practice.

required_labels := {"env", "app", "owner", "cost_center", "managed_by"}

labelled_types := {
	"google_project",
	"google_compute_instance",
	"google_compute_instance_template",
	"google_compute_disk",
	"google_storage_bucket",
	"google_sql_database_instance",
	"google_container_cluster",
	"google_redis_instance",
	"google_filestore_instance",
	"google_cloud_run_v2_service",
}

as_object(x) := x if is_object(x)

as_object(x) := {} if not is_object(x)

# Provider default_labels show up in terraform_labels, resource labels in labels.
effective_labels(after) := object.union(
	as_object(object.get(after, "labels", {})),
	as_object(object.get(after, "terraform_labels", {})),
)

deny contains msg if {
	some rc in input.resource_changes
	rc.type in labelled_types
	after := rc.change.after
	after != null
	present := {k | some k, _ in effective_labels(after)}
	missing := required_labels - present
	count(missing) > 0
	msg := sprintf("%s: missing required labels %v", [rc.address, sort(missing)])
}

deny contains msg if {
	some rc in input.resource_changes
	rc.type in labelled_types
	after := rc.change.after
	after != null
	labels := effective_labels(after)
	labels.managed_by != "terraform"
	msg := sprintf("%s: label managed_by must be \"terraform\"", [rc.address])
}
