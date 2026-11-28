# ADR 0009: Own module for application projects, with a random ID suffix

- Status: Proposed
- Date: 2026-11-28
- Deciders: Equipo 6 (Jesús Cedillo, Hervey Navarro, Adrián Güereque)

## Context
Stage 4 creates the application projects of each environment as Shared VPC service projects and gives stage 5
what it needs. The spec asks for a `project-factory` module. Stage 4 is destroyed and created again during tests
(destroy.yml), and GCP keeps a deleted project ID reserved for 30 days.

## Options
| Option | Pros | Cons |
|---|---|---|
| terraform-google-modules/project-factory with its Shared VPC inputs | Official, used in stage 1 | Hides which account gets which role in the host project; tests need the registry |
| Own module `modules/app-project` | Every grant is visible and explained; offline tests with mock providers | We maintain it |

For the ID: fixed (`bnt-dev-app`) or with a random suffix (`bnt-dev-app-a1b2`).

## Decision
Own module, with a random 4-character suffix in the project ID. Stage 5 reads the ID from the stage 4 state.

## Why
The grants are the part of stage 4 the team must explain (who may use the shared subnet, what stage 5 may do).
The suffix lets destroy.yml remove the stage and the next apply create it again right away.

## Consequences
- Stage 5 never writes project IDs by hand: it reads `app_project_ids` from `4-projects/<env>`.
- Each destroy and apply makes a new project ID; logs and metrics of the old one stay in its (deleted) project.
- A deleted project may still count against the billing account's project limit for a while. If an apply after
  a destroy fails with a billing quota error, wait or unlink the deleted project in the billing console.
