# Stage 1: org

Reference: `terraform-example-foundation/1-org`. Runs from the pipeline as `sa-terraform-org`, state prefix `1-org`.
Reads stage 0 through `terraform_remote_state` (bucket from `var.state_bucket`, prefix `0-bootstrap`).

## Creates
- Folders `common`, `dev`, `qa`, `prod` (the bootstrap folder comes from stage 0).
- Projects in `common`: `net-hub`, `logging`, `security` (KMS, Secret Manager, SCC), `backup`.
- One network host project per environment folder (the spoke Shared VPC host); stage 3 builds the networks in them.
- Organization policies, organization-level log sinks, Security Command Center notifications, budgets with alerts.

## Adapting the example
| Topic | Example foundation | This project |
|---|---|---|
| Folders | `common`, `network`, `development`, `nonproduction`, `production` | `common` holds the hub; `qa` replaces `nonproduction`; no separate `network` folder |
| Boolean org policies | nested virtualization off, serial port off, skip default network, require OS Login, Cloud SQL no public IP and no authorized networks, no SA key creation or upload, no automatic IAM grants for default SAs, uniform bucket access, public access prevention (and a few more) | Start from the same list: it already covers the spec's "no SA keys" and public-bucket rules |
| External IPs on VMs | `compute.vmExternalIpAccess` denied for all | Same: spec says no public IPs |
| Allowed regions | I did not find a `gcp.resourceLocations` policy in the file I read | Add it: spec requires allowed regions (primary and DR) |
| Log sinks | Logging bucket with linked BigQuery dataset, 30-day retention for audit logs | Add a Cloud Storage sink with a locked retention policy, as the spec requires |
| SCC | Pub/Sub notification of all new findings | Same; the SCC Premium/Enterprise tier is billed separately |
| Billing export | BigQuery dataset created, export enabled by hand | Same limitation: document it as a manual step in the runbook |

## Next
Write the code (`main.tf`, `org_policy.tf`, `logging.tf`, `scc.tf`, `budgets.tf`), run it in the sandbox org, then check that a second plan shows zero changes.
