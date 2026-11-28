# Module: app-project

One application (service) project, attached to the Shared VPC of its environment and ready for stage 5:

- The project, in the environment folder, with a random 4-character suffix in its ID (`bnt-dev-app-a1b2`). GCP
  keeps a deleted project ID reserved for 30 days, so without the suffix the stage could not be destroyed and
  created again the same week.
- Its APIs, attached as a Shared VPC service project of the host project of stage 3.
- `roles/compute.networkUser` on the subnet for the Google APIs agent and the GKE agent, and on the host project
  for the stage 5 account (Cloud SQL, Filestore and Memorystore with private IP attach to the VPC, not a subnet).
- GKE in a Shared VPC: its agent gets Host Service Agent User (and, by default, Security Admin for the health check
  firewall rules) in the host project.
- The stage 5 account (`sa-terraform-workloads`) gets only the roles its components need, in this project.
- CMEK: each service agent can use the stage 2 key of its purpose (storage, sql, gke).
- prod: the project joins the VPC-SC perimeter (dry-run, and enforced too when stage 2 enforces it).

AWS analogy: a workload account of AWS Organizations that receives a subnet shared through RAM from the network
account. The VPC, routes and firewall stay in the host project; this project only puts resources in the subnet.

Why not `terraform-google-modules/project-factory`, as stage 1 does: the Shared VPC part of that module hides
which account gets which role, and this module is what the team explains in the review. It is small enough to
read in one sitting and its tests run offline with mock providers.

Example: [examples/basic](examples/basic). Tests: `terraform test` from this folder (mock providers).

## Inputs (main ones)

| Name | Description |
|---|---|
| `name` | Display name, `<prefix>-<env>-<app>`; the ID adds the suffix |
| `folder_id`, `billing_account` | Where the project lives and who pays for it |
| `apis` | APIs to enable (compute is always on) |
| `host_project_id`, `subnet_self_link` | Outputs of `3-networks/<env>` |
| `workloads_sa`, `workloads_roles` | The stage 5 account and its roles here |
| `viewer_groups` | Groups with read-only access |
| `cmek_keys` | Key IDs by purpose (storage, sql, gke) from stage 2 |
| `vpc_sc_perimeter_name`, `vpc_sc_enforced` | prod only |

## Outputs

| Name | Description |
|---|---|
| `project_id` | ID with its suffix, read by stage 5 |
| `project_number` | Number of the project |
| `service_agents` | Google service agents of the project |
