package main

import rego.v1

# Spec: GCP ranges must not overlap the on-premises network (stage 3 README, "Checks to add").
# Rejects any subnet (primary or secondary range) that intersects an on-prem range.
#
# onprem_cidrs is the SANDBOX plan (cidr_plan.onprem.block in 3-networks/shared). Replace it with the client's
# signed IP plan when it exists, and keep both in sync.
onprem_cidrs := {"10.200.0.0/16"}

# The simulated datacenter (3-networks/envs/shared) lives inside the on-prem range on purpose. It is a second VPC
# inside net-hub, not its own project, so it is matched by its subnet name (<prefix>-c-onprem-subnet-<region>),
# which is known at plan time (the network ID is not, for a new VPC).
exempt(after) if contains(object.get(after, "name", ""), "-onprem-subnet-")

subnet_ranges(after) := ranges if {
	primary := {after.ip_cidr_range | is_string(after.ip_cidr_range)}
	secondary := {r.ip_cidr_range | some r in object.get(after, "secondary_ip_range", []); is_string(r.ip_cidr_range)}
	ranges := primary | secondary
}

deny contains msg if {
	some rc in input.resource_changes
	rc.type == "google_compute_subnetwork"
	after := rc.change.after
	after != null
	not exempt(after)
	some cidr in subnet_ranges(after)
	some onprem in onprem_cidrs
	net.cidr_intersects(cidr, onprem)
	msg := sprintf("%s: range %s overlaps the on-prem range %s", [rc.address, cidr, onprem])
}
