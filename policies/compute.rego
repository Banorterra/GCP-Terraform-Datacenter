package main

import rego.v1

# Spec: VMs must be Shielded VMs and must not have public IPs.

vm_types := {"google_compute_instance", "google_compute_instance_template"}

shielded(after) if {
	some cfg in after.shielded_instance_config
	cfg.enable_secure_boot == true
	cfg.enable_vtpm == true
	cfg.enable_integrity_monitoring == true
}

deny contains msg if {
	some rc in input.resource_changes
	rc.type in vm_types
	after := rc.change.after
	after != null
	not shielded(after)
	msg := sprintf("%s: Shielded VM (secure boot, vTPM, integrity monitoring) is required", [rc.address])
}

deny contains msg if {
	some rc in input.resource_changes
	rc.type in vm_types
	after := rc.change.after
	after != null
	some nic in after.network_interface
	count(nic.access_config) > 0
	msg := sprintf("%s: public IP (access_config) is not allowed", [rc.address])
}
