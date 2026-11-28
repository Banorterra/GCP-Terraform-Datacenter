# Sprint 4 gate (spec): "a prod VM reaches an on-prem host by private IP and resolves its DNS". Off by default.
#
# At boot the VM resolves gate_target_host (Cloud DNS -> peering to the hub -> forwarding over the HA VPN), pings the
# address and fetches http://<host>/, and prints one GATE: line per check to the serial console and to
# /var/log/gate-test.log. No package installs: getent, ping and curl ship with the Debian image. No external IP and
# no service account: the VM only needs the network.

resource "google_compute_instance" "gate" {
  count = var.enable_gate_vm ? 1 : 0

  project      = var.project_id
  name         = "${local.name}-gate-vm"
  machine_type = var.gate_vm_machine_type
  zone         = "${var.region}-a"

  boot_disk {
    initialize_params {
      image = "projects/debian-cloud/global/images/family/debian-12"
      size  = 10
      type  = "pd-balanced"
    }
  }

  network_interface {
    subnetwork = google_compute_subnetwork.primary.id
  }

  shielded_instance_config {
    enable_secure_boot          = true
    enable_vtpm                 = true
    enable_integrity_monitoring = true
  }

  metadata = {
    enable-oslogin = "TRUE"
  }

  metadata_startup_script = <<-EOT
    #!/bin/bash
    host="${var.gate_target_host}"
    {
      ip="$(getent hosts "$host" | awk '{print $1}')"
      if [[ -n "$ip" ]]; then echo "GATE dns:  OK   $host -> $ip"; else echo "GATE dns:  FAIL $host"; fi
      if [[ -n "$ip" ]] && ping -c3 -W2 "$ip" > /dev/null; then echo "GATE ping: OK   $ip"; else echo "GATE ping: FAIL"; fi
      code="$(curl -s -m5 -o /dev/null -w '%%{http_code}' "http://$host/")"
      if [[ "$code" == "200" ]]; then echo "GATE http: OK   200"; else echo "GATE http: FAIL $code"; fi
    } | tee /var/log/gate-test.log /dev/ttyS0
  EOT

  labels = merge(var.labels, { app = "gate-test" })

  tags = ["ssh", "allow-onprem"]

  lifecycle {
    precondition {
      condition     = var.gate_target_host != ""
      error_message = "gate_target_host is required when enable_gate_vm is true."
    }
  }
}
