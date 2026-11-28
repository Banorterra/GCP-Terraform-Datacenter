# gcp-datacenter

Terraform repository for the GCP "datacenter" (landing zone) described in the project spec.
It adapts Google's [terraform-example-foundation](https://github.com/terraform-google-modules/terraform-example-foundation)
to the spec's stages, GitHub Actions pipeline and acceptance criteria.

## Status (2026-11-27)

| Stage | State | Open work |
|---|---|---|
| 0-bootstrap | Applied (by hand, once) | Secure tags for the firewall need `roles/resourcemanager.tagAdmin` for a stage account (team decision) |
| 1-org | Applied by the pipeline (#20: read-only access for people, VPC-SC Policy Denied logs) | #23: networking APIs in `net-hub` and VM permission for the networks account |
| 2-security | Applied by the pipeline | VPC-SC perimeter in dry-run; review its violations before enforcing (ADR 0006). #24: the networks plan account reads the VPN key |
| 3-networks | In review: hub and simulated on-prem in #16 (`envs/shared`, needs #23 and #24 first), spokes in #19 (`envs/{dev,qa,prod}`, draft), CIDR policy in #21 | Billing for `qa-net-host` and `prod-net-host`; then apply the hub, the spokes and run the Sprint 4 gate |
| 4-projects | Draft (`envs/{dev,qa,prod}`, `modules/app-project`) | Apply stage 3 and the billing of each environment first |
| 5-workloads | Scaffolding | Starts after the Sprint 4 gate |

The pipeline is in use: PRs plan every touched root with read-only accounts (new roots against an empty state), and a
merge to `main` applies stage by stage in series, each root after its environment's reviewers approve the saved plan.

## Layout

```
modules/                reusable modules (see modules/README.md): kms; network-spoke (in #19); app-project
stages/_shared/         boilerplate copied into every root by scripts/sync-boilerplate.sh
stages/0-bootstrap/     seed + CI/CD projects, state bucket, stage service accounts, Workload Identity (manual, once)
stages/1-org/           folders, org policies, logging, SCC, budgets
stages/2-security/      KMS, Secret Manager, VPC Service Controls
stages/3-networks/      hub, spokes, DNS, HA VPN, firewall          envs/{shared,dev,qa,prod}
stages/4-projects/      service projects per application            envs/{dev,qa,prod}
stages/5-workloads/     GKE, MIG, Cloud SQL, storage, LB, backup    envs/{dev,qa,prod}
policies/               Conftest (OPA) rules run on every plan
scripts/                changed-roots.sh (which roots a PR touches), sync-boilerplate.sh
.github/workflows/      pr.yml (fmt, validate, plan + policy check, plan comment)
                        apply.yml (after merge or by hand: stage by stage in series, plan, approve per environment, apply the saved plan; uses terraform-group.yml)
                        destroy.yml (by hand only: destroy one stage or stages 5-4-3 of one environment, with confirmation and approval)
docs/adr/               architecture decision records
```

## How the spec maps to the example foundation

| Spec stage | Example stage | What changes |
|---|---|---|
| 0-bootstrap | 0-bootstrap | Same CFT bootstrap module. GitHub Actions + Workload Identity instead of Cloud Build + Cloud Source Repositories; stage accounts are org, security, networks, projects, workloads; state access limited per stage prefix |
| 1-org | 1-org | `common` holds the hub; `qa` instead of `nonproduction`; add allowed-regions policy and a locked-retention log bucket |
| 2-security | parts of 1-org and 2-environments (KMS, secrets), VPC-SC from 3-networks | Grouped into one stage |
| 3-networks | 3-networks-hub-and-spoke | NCC hub in STAR topology (no spoke-to-spoke), HA VPN first, simulated on-prem as a second VPC in `net-hub`, deny-all firewall, 50 % flow logs. ADR 0002 |
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

## Known limits and things to verify

- PR plans use read-only plan service accounts (`TF_PLAN_SA_*`, `stages/0-bootstrap/plan_sa.tf`). The stage service
  accounts that can change things only work from jobs on `main`.
- Stage role sets are a starting point copied from the example; tighten them in the sandbox.
- Sandbox values: free-trial billing accounts link only 3 projects each (ADR 0007), audit logs are kept 1 day
  (locked), folders and projects can be destroyed. A real organization changes these (see each stage's README).
- The CIDR plan in `3-networks/envs/shared` and `policies/network.rego` is a sandbox plan, not the client's signed one.
- Not yet proven against GCP: on-prem routes reaching the environment spokes through the NCC hub. The HA VPN tunnels
  are a hybrid spoke in the hub's center group, and the hub router advertises the spoke blocks to on-prem (ADR 0002).
- GitHub Actions are pinned by major tag, not commit SHA. Policy tests: `conftest verify --policy policies`.

## Schedule note

As of 2026-11-27 the project is in Sprint 5 (operation and DR), with delivery on 2026-12-03. The network (Sprint 3)
is the critical path: Sprint 4 cannot start until a prod VM reaches an on-prem host by private IP and resolves its
DNS. The stage 3 README explains the gate VM that runs this check.
