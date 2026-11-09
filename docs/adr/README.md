# Architecture Decision Records

One file per decision: options considered, the choice, and why (the landing-zone guide's Step 6).
Copy `0000-template.md`, number it, and add it to the index.

| ADR | Decision | Status |
|---|---|---|
| [0001](0001-foundation-base.md) | Build on the example foundation + CFT modules | Proposed |
| [0002](0002-network-topology.md) | Hub-and-spoke on Shared VPC, no spoke-to-spoke | Accepted (spec) |
| [0003](0003-ci-cd-tool.md) | GitHub Actions with Workload Identity Federation | Proposed (client chooses) |
| [0004](0004-terraform-version.md) | Terraform version and licence | Proposed |
| [0005](0005-regions.md) | northamerica-south1 (Queretaro) primary, us-south1 (Dallas) DR | Accepted |

Statuses: Proposed (needs a sign-off) / Accepted / Superseded by NNNN.
