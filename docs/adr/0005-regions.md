# ADR 0005: Regions

- Status: Accepted
- Date: 2026-11-09 (first proposed 2026-11-03)
- Deciders: Project lead, cloud architect

## Context
The spec proposes us-central1 (primary) and us-east4 (DR) for latency to Mexico and service coverage, and says
northamerica-south1 (Queretaro) is evaluated if there are data-residency requirements. RPO <= 15 min and
RTO <= 4 h apply. The team's architecture diagrams (Phase 3) already place the platform in Queretaro with
DR in Dallas. The example foundation defaults its second region to us-west1.

## Options
| Option | Pros | Cons |
|---|---|---|
| us-central1 + us-east4 (spec default) | Full service catalogue, low latency | Data leaves Mexico; does not match our diagrams |
| northamerica-south1 (Queretaro) + us-south1 (Dallas) | Primary data stays in Mexico; matches the diagrams; Dallas is the closest US region for DR | Smaller service catalogue: check each product before using it |

## Decision
northamerica-south1 (Queretaro) as primary, us-south1 (Dallas) as DR. These are now the defaults of
`primary_region` and `dr_region` in every stage.

## Why
It keeps the primary copy of the data in Mexico and matches the diagrams already delivered.
Google's region pages (checked 2026-11-07) list both regions for the data services in scope:
[Cloud SQL](https://docs.cloud.google.com/sql/docs/postgres/region-availability-overview),
[Filestore](https://docs.cloud.google.com/filestore/docs/regions) and
[Memorystore for Redis](https://docs.cloud.google.com/memorystore/docs/redis/regions).

## Consequences
- Every region is a variable, so changing it later is a tfvars change plus a review of service availability.
- Before using any other product (GKE features, Backup and DR Service, Cloud IDS, Cloud Run), confirm it is offered in both regions.
- Cloud SQL in both regions does not support instances with 34 or more vCPUs, which is far above the spec's 4 vCPU tier.
- The state bucket and its KMS key live in the primary region only; decide whether state needs its own DR copy.
- The org policy for allowed regions (stage 1) must list both regions.
