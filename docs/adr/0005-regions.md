# ADR 0005: Regions

- Status: Proposed (the client confirms)
- Date: 2026-11-03
- Deciders: Client counterpart, cloud architect

## Context
The spec proposes us-central1 (primary) and us-east4 (DR) for latency to Mexico and service coverage, and says
northamerica-south1 (Queretaro) is evaluated if there are data-residency requirements. RPO <= 15 min and
RTO <= 4 h apply. The example foundation defaults its second region to us-west1.

## Options
| Option | Pros | Cons |
|---|---|---|
| us-central1 + us-east4 (spec) | Full service catalogue, low latency | Data leaves Mexico |
| northamerica-south1 + another region | Data stays in Mexico for the primary | Check service availability for every product in scope first |

## Decision
Keep the spec's pair as the default in code (`primary_region`, `dr_region`) until the client answers.

## Consequences
- Every region is a variable, so changing it later is a tfvars change plus review of service availability.
- The state bucket and its KMS key live in the primary region only; decide whether state needs its own DR copy.
- The org policy for allowed regions (stage 1) must list both regions.
