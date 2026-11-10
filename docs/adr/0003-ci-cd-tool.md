# ADR 0003: GitHub Actions with Workload Identity Federation

- Status: Proposed (the spec leaves the choice to the client)
- Date: 2026-11-03
- Deciders: Client counterpart, cloud architect

## Context
The spec allows GitHub Actions or Cloud Build, with no JSON keys and one service account per stage.
The example foundation's default path is Cloud Build, but it depends on Cloud Source Repositories,
which is no longer available to new customers (organizations that never used it cannot enable it).
The example also documents GitHub Actions, GitLab and Terraform Cloud paths.

## Options
| Option | Pros | Cons |
|---|---|---|
| Cloud Build + Cloud Source Repositories | Default in the example | Not available for new organizations |
| GitHub Actions + WIF | Works in any org, PR comments and environments with required reviewers fit the spec flow | Needs GitHub; approvals live in GitHub settings |
| Terraform Cloud / GitLab | Documented by the example | Extra platform or less maintained guidance |

## Decision
GitHub Actions, authenticating with Workload Identity Federation. The pool only trusts this repository.

## Why
Meets the spec flow (PR checks, plan comment, dev auto-apply, protected prod) without depending on a closed service.

## Consequences
- Branch protection, CODEOWNERS and the `shared`, `dev`, `qa`, `prod` environments (two reviewers on prod) are set up in GitHub.
- PR plans use read-only plan service accounts; the stage service accounts are bound in Workload Identity to `refs/heads/main` only.
