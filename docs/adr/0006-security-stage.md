# ADR 0006: Security stage (KMS, secrets, VPC-SC)

- Status: Proposed
- Date: 2026-11-22
- Deciders: Project lead, security engineer

## Context
The spec puts Cloud KMS (90-day rotation), Secret Manager ("no plain-text secrets in Terraform") and a VPC Service
Controls perimeter for prod projects with sensitive data in stage 2. The team has 300 USD of credit and decided
that stages 0-2 stay applied, so stage 2 must be cheap to keep running and still destroyable.

## Options
| Option | Pros | Cons |
|---|---|---|
| Secret values typed in by hand in the console | Nothing in the state | Manual step (the spec forbids them outside stage 0) |
| `random_password` + `secret_data` | Simple | The value sits in the plan and the state |
| Ephemeral `random_password` + write-only `secret_data_wo` | Value never in plan or state; no manual step | Needs Terraform >= 1.11; Terraform cannot detect drift of the value |
| VPC-SC enforced from day one | Real protection | Can cut off the pipeline and Google service agents before we see the violations |
| VPC-SC dry-run, enforce by variable | Violations only logged until reviewed | No protection until enforced |
| KMS HSM keys | Hardware-backed | 1-2.50 USD per key version per month |

## Decision
Software KMS keys in both regions, generated secrets with ephemeral + write-only values, VPC-SC perimeter in
dry-run (`vpc_sc_enforce = false`) around the prod projects.

## Why
It meets every spec item for under 1 USD a month, keeps secrets out of the state, and follows the spec's own
advice to start the perimeter in dry-run.

## Consequences
- Key ring names carry a random suffix: GCP never deletes key rings, so a destroy plus apply would otherwise fail.
- Stage 4 must add prod service projects to the perimeter and grant service agents on the CMEK keys.
- Before the demo, read the VPC-SC dry-run logs and decide whether to enforce.
