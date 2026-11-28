# ADR 0008: One common project for security, audit logs and backups

- Status: Proposed
- Date: 2026-11-28
- Deciders: Equipo 6 (Jesús Cedillo, Hervey Navarro, Adrián Güereque)

## Context
ADR 0007 spreads the projects over three free-trial billing accounts, 3 projects each: 9 slots. The
minimum that must be billed is the seed, CI/CD, net-hub, security and the three net-host projects (7),
plus stage 4's application projects. With logging billed too, only one application project fits, and
qa's network could not be applied. A quota increase needs a payment (ADR 0007), so it is not an option.

The logging project only holds the organization's audit bucket, and the backup project is empty until DR.

## Options
| Option | Pros | Cons |
|---|---|---|
| Keep logging and backup as their own projects | Matches the spec's hierarchy | One app project at most; qa without network |
| Put the audit bucket and the backup vaults in the security project | Frees one slot: dev, qa and prod networks plus app projects in dev and prod | One project holds keys, secrets, audit logs and backups |
| Merge security into logging | Same slot count | KMS key rings can never be deleted, so moving the keys is not possible |

## Decision
The security project (ID `bnt-c-security`, display name `bnt-c-security-logs-backup`) holds the KMS keys,
the secrets, the organization audit bucket and, in stage 5, the backup and DR vaults. There is no backup
project. The logging project is retired in two steps, because its audit bucket has a locked retention
policy and a lien on the project:
1. The organization sink writes to a new bucket in the security project; the old bucket stays.
2. When the old bucket's newest object is older than the retention period (1 day), the bucket and the
   logging project are deleted, which frees a billing slot.

## Why
It keeps every environment's network and gives dev and prod a complete Shared VPC service project, which
is what the demo has to show, without paying. Project IDs cannot change, so only the display name says
what the project holds now.

## Consequences
- In a real organization these stay separate projects, so that access to one workload does not give
  access to the others. In the sandbox, grant access per resource (key ring, secret, bucket) instead of per
  project wherever possible.
- Audit logs written before the switch stay in the old bucket until it is deleted (1 day).
