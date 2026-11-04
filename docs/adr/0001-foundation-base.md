# ADR 0001: Build on the example foundation and CFT modules

- Status: Proposed
- Date: 2026-11-03
- Deciders: Cloud architect, IaC engineers

## Context
The spec's stages (0-bootstrap ... 5-workloads) closely follow Google's `terraform-example-foundation`
(0-bootstrap, 1-org, 2-environments, 3-networks-*, 4-projects, 5-app-infra). The spec allows reusing
official modules (Cloud Foundation Fabric or terraform-google-modules) with pinned versions. The project
has 10 weeks and Sprint 3 (network) is already under way.

The example repo says it is meant to be forked and maintained, not referenced remotely, and it will
not support in-place upgrades between its versions.

## Options
| Option | Pros | Cons |
|---|---|---|
| Write every module from scratch | Full control, matches spec folder names exactly | Spends the schedule re-solving solved problems |
| Fork the example foundation as-is | Fastest start | Stage names, CI tool, branching and Terraform pin differ from the spec |
| Take its structure and proven module wiring, adapt to the spec, write custom modules only for gaps | Keeps the spec's contract, reuses tested role sets and module choices | We own the adaptation and its upgrades |

## Decision
Third option. Stage mapping and every deliberate deviation are listed in the root README.

## Why
Most of the spec is covered by the example (org, logging, SCC, networks, projects). The real custom
work is `hybrid-connectivity` defaults, `vpc-sc`, stage 5 workloads and `backup-dr`.

## Consequences
- Pin every upstream module version and review changes by PR.
- Do not try to merge upstream releases into this repo; compare and port by hand.
