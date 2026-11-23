# ADR 0007: Spread projects over several free-trial billing accounts

- Status: Proposed
- Date: 2026-11-23
- Deciders: Equipo 6 (Jesús Cedillo, Hervey Navarro, Adrián Güereque)

## Context
The spec asks for at least 11 projects: the seed, net-hub, logging, security and backup in common, and a
spoke network project plus at least one service project in each of dev, qa and prod. We also have a CI/CD
project from stage 0. The spec assumes a company with normal billing.

We run on free-trial billing accounts. Google lets a new free-trial account link only 3 projects. The
first stage 1 apply failed with "Cloud billing quota exceeded" on 6 projects. Google's answer to a quota
increase request was to make a 50 USD payment first.

## Options
| Option | Pros | Cons |
|---|---|---|
| Pay 50 USD to raise the quota | One billing account, no code change | Real money for a school project; the payment is only a credit for future charges, which the free credit already covers |
| One free-trial account per team member (3 x 3 projects) | No extra cost; 900 USD of credit instead of 300 | Projects and budgets spread over several accounts; each owner must grant the Terraform service accounts access |
| Merge projects (fewer than the spec asks for) | Fits in one account | Breaks the spec's resource hierarchy |

## Decision
Each team member brings a free-trial billing account. `var.extra_billing_accounts` lists them and
`var.project_billing` assigns each project to an account, or to `"none"` when the project only needs
free APIs (CI/CD with Workload Identity, backup until DR is built, the qa service project).

## Why
It keeps the spec's hierarchy without paying, and the projects without billing still exist in the
right folders. Billing is a single project attribute, so moving a project between accounts later is an
in-place change.

## Consequences
- One total budget per billing account, in that account's currency, and one budget per project on the
  account that pays for it.
- Each account owner grants `sa-terraform-org` Billing Account User and Billing Account Costs Manager,
  and `sa-terraform-plan-org` Billing Account Viewer. Stage 0 only grants these on the main account.
- Projects marked `"none"` can only enable free APIs; a stage that needs a paid API there must assign the
  project to an account first.
- At the end, each owner closes their own billing account.
