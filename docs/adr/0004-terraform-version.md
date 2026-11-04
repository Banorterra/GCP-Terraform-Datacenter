# ADR 0004: Terraform version and licence

- Status: Proposed (needs sign-off; this is not legal advice)
- Date: 2026-11-03
- Deciders: Cloud architect, project lead

## Context
The spec requires Terraform >= 1.9 and `hashicorp/google` 6.x. The example foundation pins Terraform
1.5.7 everywhere (its docs call it the last version before HashiCorp's licence change) and warns that
mixing versions between manual and pipeline runs causes state-snapshot lock errors. `terraform test` with
`mock_provider` needs a version newer than 1.5.

## Options
| Option | Pros | Cons |
|---|---|---|
| Terraform 1.5.7 | Last MPL-licensed release, what the example tests | Fails the spec (>= 1.9), no `mock_provider` |
| Terraform >= 1.9 | Meets the spec, `mock_provider` unit tests | BUSL licence: the client should confirm it is fine for their use |
| OpenTofu | Open-source licence | Not what the spec names; provider/tooling parity must be checked |

## Decision
Terraform >= 1.9, one exact version in `.terraform-version`, used by the pipeline and by anyone running a stage by hand.

## Why
The spec is explicit and the unit-test strategy depends on it.

## Consequences
- Choose the exact version after checking current releases; `.terraform-version` currently holds a placeholder.
- Raise the question of licence with the client before the first deploy.
