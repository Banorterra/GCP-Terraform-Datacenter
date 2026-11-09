# Stage 5: workloads

Reference: `terraform-example-foundation/5-app-infra` only deploys one sample Compute Engine instance,
so this stage is mostly new code. One root per environment, state prefix `5-workloads/<env>`, runs as `sa-terraform-workloads`.

## Creates (from the spec's component table)
- GKE: private nodes, regional in prod, Workload Identity, Binary Authorization.
- Compute Engine MIG: hardened images, Shielded VM, autoscaling and autohealing.
- Cloud SQL: private IP, HA in prod, CMEK, replica in the DR region.
- Cloud Storage (CMEK, versioning, lifecycle rules), Filestore, Memorystore.
- External HTTPS load balancer with managed certificates and Cloud Armor (OWASP rules); internal load balancer for internal services.
- Backup and DR Service: daily policy, 30-day retention, DR region us-south1 (Dallas).

## Notes
- Check Backup and DR resource coverage in the pinned `google` provider before choosing a module; it may need a small custom module.
- Dev and qa should be switched off outside working hours (cost control in the spec).
- Acceptance: the DR drill restores Cloud SQL and a GKE workload in the DR region within the 4 h RTO.
