# gcp-datacenter

Terraform repository for the GCP "datacenter" (landing zone) described in the project spec.
It adapts Google's [terraform-example-foundation](https://github.com/terraform-google-modules/terraform-example-foundation)
to the spec's stages, GitHub Actions pipeline and acceptance criteria.

> Status: skeleton. Stage 0 is written; stages 1-5 and the modules are scaffolding with READMEs.
> Stage 0 is applied. The GitHub Actions workflows (`.github/workflows/pr.yml` and `apply.yml`) are written but not yet proven on a real stage.

## Layout

```
modules/                reusable modules (see modules/README.md)
stages/_shared/         boilerplate copied into every root by scripts/sync-boilerplate.sh
stages/0-bootstrap/     seed + CI/CD projects, state bucket, stage service accounts, Workload Identity (manual, once)
stages/1-org/           folders, org policies, logging, SCC, budgets
stages/2-security/      KMS, Secret Manager, VPC Service Controls
stages/3-networks/      hub, spokes, DNS, HA VPN, firewall          envs/{dev,qa,prod}
stages/4-projects/      service projects per application            envs/{dev,qa,prod}
stages/5-workloads/     GKE, MIG, Cloud SQL, storage, LB, backup    envs/{dev,qa,prod}
policies/               Conftest (OPA) rules run on every plan
scripts/                changed-roots.sh (which roots a PR touches), sync-boilerplate.sh
.github/workflows/      pr.yml (fmt, validate, plan + policy check, plan comment), apply.yml (after merge: plan every root, approve per environment, apply the saved plan)
docs/adr/               architecture decision records
```

## How the spec maps to the example foundation

| Spec stage | Example stage | What changes |
|---|---|---|
| 0-bootstrap | 0-bootstrap | Same CFT bootstrap module. GitHub Actions + Workload Identity instead of Cloud Build + Cloud Source Repositories; stage accounts are org, security, networks, projects, workloads; state access limited per stage prefix |
| 1-org | 1-org | `common` holds the hub; `qa` instead of `nonproduction`; add allowed-regions policy and a locked-retention log bucket |
| 2-security | parts of 1-org and 2-environments (KMS, secrets), VPC-SC from 3-networks | Grouped into one stage |
| 3-networks | 3-networks-hub-and-spoke | HA VPN first, spoke-to-spoke off, deny-all firewall, 50 % flow logs |
| 4-projects | 4-projects | One service project per application per environment |
| 5-workloads | 5-app-infra (a single sample VM) | Mostly new code |

## Deliberate differences from the example

| Topic | Example | Here | Why |
|---|---|---|---|
| Terraform | 1.5.7 pinned | >= 1.9 (`.terraform-version`) | Spec requirement, `mock_provider` tests. See ADR 0004 |
| CI/CD | Cloud Build default | GitHub Actions + WIF | Cloud Source Repositories is closed to new customers. ADR 0003 |
| Repos | One repo per stage | One repo, stages as folders | Spec layout |
| Branching | `development`, `nonproduction`, `production` branches | Trunk (`main`) + GitHub environments `shared`, `dev`, `qa`, `prod` | Spec flow: dev auto-applies, prod needs two reviewers |
| State access | Object admin on the whole seed project | Object admin only on the stage's own prefix (IAM condition) | Spec: only each stage's account touches its prefix |
| GitHub secrets | Terraform writes GitHub secrets using a token | Outputs print non-secret values; you set repository variables | No token in state |
| Naming | `prj-b-seed`, `fldr-...` | `<prefix>-b-seed`, plain folder names | Spec convention. Note the example caps the prefix at 3 characters (project IDs max 30) |

## First run (sandbox organization, never the client's)

1. Create the admin groups and give the person who runs stage 0 the roles listed in the example's 0-bootstrap README:
   organization admin, org policy admin, project creator and folder creator on the organization, billing admin on the billing account,
   Security Center admin. Enable `cloudresourcemanager`, `cloudbilling`, `iam`, `cloudkms` and `servicenetworking` on the project your credentials use.
2. `cd stages/0-bootstrap`, copy `terraform.tfvars.example` to `terraform.tfvars`, then `terraform init`, `plan`, `apply` with local state.
3. Rename `backend.tf.example` to `backend.tf` and run `terraform init -migrate-state -backend-config="bucket=$(terraform output -raw state_bucket)"`.
4. In GitHub: create repository variables from `terraform output github_repository_variables`, plus `ORG_ID` and `BILLING_ACCOUNT`
   (optional: `CONFTEST_VERSION`, default 0.56.0);
   create environments `shared`, `dev`, `qa`, `prod` (required reviewers with "prevent self-review" on `shared` and `prod`, deployment branch `main`); protect `main`; add CODEOWNERS per stage.
   Optional variables: `INFRACOST_ENABLED` (+ secret `INFRACOST_API_KEY`), `DRIFT_ENABLED`.
5. Edit `stages/_shared/*` if needed, then run `scripts/sync-boilerplate.sh`. Open the first PR and watch `pr.yml`.
6. For each stage root: `terraform init -backend-config="bucket=<state bucket>"`.

## Not verified

I could not run Terraform, OPA/Conftest, tflint or a formatter where this was written (tool downloads are blocked there).
Only syntax of the `.tf`, `.yml` and `.sh` files was parsed, and `scripts/changed-roots.sh` was tested on a throwaway repo. So expect to fix things on first contact:

- Run `terraform fmt -recursive` once; I aligned attributes by hand and CI fails on any difference.
- `terraform init` in stage 0 will show whether `provider ~> 6.0` fits the three pinned modules (`bootstrap ~> 13.0`, `project-factory ~> 18.0`, `github-actions-runners//gh-oidc ~> 5.1`, versions taken from the example). Module input and output names (for example `labels` on project-factory) come from the example's usage or from memory.
- Written from memory, check against provider docs: the IAM condition for per-prefix state access (including the list-request clause), `default_labels` in the provider block, the `roles/billing.costsManager` role.
- The Rego policies were never executed. Test them with `conftest verify` or against a real plan JSON before relying on the "blocks a public bucket" acceptance test.
- `.terraform-version` (1.9.8) is a placeholder: check current releases first. GitHub Actions are pinned by major tag, not commit SHA.
- Plan jobs on PRs use the same service account as apply jobs. Only this repository can use them, but a read-only plan account would be safer.
- Stage role sets are a starting point copied from the example; tighten them in the sandbox.

## Schedule note

As of 2026-11-03 the project is in Sprint 3 (network). The critical path is the client's signed IP plan and a working HA VPN:
Sprint 4 cannot start until a prod VM reaches an on-prem host by private IP and resolves its DNS.
