# Modules

Reusable, stateless modules. Each one needs `README.md` (terraform-docs), `variables.tf` with descriptions and
validations, `outputs.tf`, an `examples/` folder and at least one `terraform test` (spec).

Where an official module exists, wrap it (pin the version) instead of rewriting it. Candidates below come from my
memory of the Cloud Foundation Toolkit registry: confirm each name and pick the version on the Terraform Registry
before pinning, and record the choice in an ADR.

| Spec module | Starting point |
|---|---|
| `project-factory` | terraform-google-modules/project-factory (stage 0 already pins `~> 18.0`) |
| `network-hub`, `network-spoke`, `firewall` | Example foundation `3-networks-hub-and-spoke` code + terraform-google-modules/network |
| `hybrid-connectivity` | terraform-google-modules/vpn (HA VPN), cloud-router |
| `gke` | terraform-google-modules/kubernetes-engine (private cluster submodule) |
| `compute-mig` | terraform-google-modules/vm (MIG submodule) |
| `cloud-sql` | terraform-google-modules/sql-db |
| `storage` | terraform-google-modules/cloud-storage |
| `kms` | terraform-google-modules/kms |
| `observability` | Example foundation log sinks + monitoring resources |
| `backup-dr` | Probably custom: check provider support for Backup and DR first |
| `vpc-sc` | Example foundation VPC-SC code, trimmed to the spec's perimeter |
