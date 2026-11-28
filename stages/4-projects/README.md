# Stage 4: projects

Reference: `terraform-example-foundation/4-projects` (standard projects attached to the Shared VPC). One root per
environment, state prefix `4-projects/<env>`, runs as `sa-terraform-projects`. Uses `modules/app-project` (ADR 0009).

## Creates (per environment)
- One application project per entry of `apps` (today one: `bnt-<env>-app-xxxx`), in the environment folder, with a
  random suffix so the stage can be destroyed and created again.
- Attaches it to the Shared VPC of `3-networks/<env>` and lets the GKE and Google APIs agents use the subnet.
- The roles `sa-terraform-workloads` needs in the project (stage 5 gets them here, not at organization level), and
  Network User on the host project.
- CMEK: the service agents can use the stage 2 keys (storage, sql, gke) in both regions.
- prod only: the project joins the VPC-SC perimeter of stage 2.
- `grp-devops` can see the project (read only).

## Reads
| From | Outputs |
|---|---|
| `1-org` | `folder_ids` |
| `2-security` | `kms_key_ids`, `vpc_sc_perimeter_name`, `vpc_sc_enforced` |
| `3-networks/<env>` | `host_project_id`, `subnet_self_link` |

Apply order: the `3-networks/<env>` root of the same environment first. Without its state this root cannot plan, so
PR plans fail until stage 3 is applied.

## Before the first apply
- Billing: each environment's account is in `app_billing_account` (dev: Jesús's account; qa and prod: Hervey's,
  still to create). Its owner grants `sa-terraform-projects` the role Billing Account User on it (ADR 0007).
- Stage 1 enables `container` and `servicenetworking` on the net-host projects (GKE and private IP in a Shared VPC).

## Adding an application
One entry in `apps` in `terraform.auto.tfvars` of each environment, then a PR. Each new project takes a billing slot.
