package main

import rego.v1

# Spec acceptance criterion: the pipeline blocks a PR that creates a public bucket.

public_members := {"allUsers", "allAuthenticatedUsers"}

deny contains msg if {
	some rc in input.resource_changes
	rc.type == "google_storage_bucket_iam_member"
	rc.change.after.member in public_members
	msg := sprintf("%s: bucket IAM grants access to %s", [rc.address, rc.change.after.member])
}

deny contains msg if {
	some rc in input.resource_changes
	rc.type == "google_storage_bucket_iam_binding"
	some m in rc.change.after.members
	m in public_members
	msg := sprintf("%s: bucket IAM binding includes %s", [rc.address, m])
}

deny contains msg if {
	some rc in input.resource_changes
	rc.type == "google_storage_bucket"
	after := rc.change.after
	after != null
	after.public_access_prevention != "enforced"
	msg := sprintf("%s: public_access_prevention must be \"enforced\"", [rc.address])
}

deny contains msg if {
	some rc in input.resource_changes
	rc.type == "google_storage_bucket"
	after := rc.change.after
	after != null
	after.uniform_bucket_level_access != true
	msg := sprintf("%s: uniform_bucket_level_access must be true", [rc.address])
}
