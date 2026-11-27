package main

import rego.v1

# Run with: conftest verify --policy policies

subnet(address, name, primary, secondary) := {
	"address": address,
	"type": "google_compute_subnetwork",
	"change": {"after": {
		"name": name,
		"ip_cidr_range": primary,
		"secondary_ip_range": [{"range_name": "r", "ip_cidr_range": c} | some c in secondary],
	}},
}

test_spoke_subnet_clear_of_onprem_passes if {
	count(deny) == 0 with input as {"resource_changes": [subnet("a", "bnt-dev-subnet-northamerica-south1", "10.10.0.0/24", ["10.10.64.0/18"])]}
}

test_primary_range_overlapping_onprem_is_denied if {
	count(deny) == 1 with input as {"resource_changes": [subnet("a", "bnt-dev-subnet-northamerica-south1", "10.200.5.0/24", [])]}
}

test_secondary_range_overlapping_onprem_is_denied if {
	count(deny) == 1 with input as {"resource_changes": [subnet("a", "bnt-prod-subnet-northamerica-south1", "10.30.0.0/24", ["10.200.0.0/18"])]}
}

test_onprem_sim_subnet_is_exempt if {
	count(deny) == 0 with input as {"resource_changes": [subnet("a", "bnt-c-onprem-subnet-northamerica-south1", "10.200.1.0/24", [])]}
}

test_hub_subnet_overlapping_onprem_is_denied if {
	count(deny) == 1 with input as {"resource_changes": [subnet("a", "bnt-c-hub-subnet-northamerica-south1", "10.200.9.0/24", [])]}
}

test_deleted_subnet_is_ignored if {
	count(deny) == 0 with input as {"resource_changes": [{"address": "a", "type": "google_compute_subnetwork", "change": {"after": null}}]}
}
