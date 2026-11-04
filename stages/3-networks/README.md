# Stage 3: networks

Reference: `terraform-example-foundation/3-networks-hub-and-spoke` (Network Connectivity Center hub, Shared VPC per
environment, global DNS hub). One root per environment under `envs/`, state prefix `3-networks/<env>`, runs as `sa-terraform-networks`.
The hub itself (shared resources) needs its own root: add `envs/shared` when you start writing code (the example has one).

## Adapting the example
| Topic | Example foundation | This project |
|---|---|---|
| Environments | development, nonproduction, production (+ shared) | dev, qa, prod (+ shared for the hub) |
| On-prem link | Dedicated or Partner Interconnect; HA VPN is optional and disabled by default (`vpn.tf.example`) | HA VPN first (spec), 2 tunnels + BGP; Interconnect later |
| VPN pre-shared keys | Created by hand in Secret Manager, read by Terraform | Same: never in code or tfvars |
| Spoke-to-spoke | Off unless `enable_hub_and_spoke_transitivity = true` | Keep off (spec: no direct connectivity between environments) |
| Firewall | Hierarchical policies for IAP, load-balancer health checks, Windows KMS | Spec: deny all by default, allow by secure tag |
| Flow logs | see example defaults | 50 % sampling (spec) |
| Subnet and on-prem ranges | Example CIDRs | The client's signed IP plan; no overlap with on-prem |

## Checks to add
- A Conftest rule on the plan using `net.cidr_intersects` that rejects any subnet overlapping `onprem_cidrs`.
- Sprint rule: Sprint 4 (compute and data) does not start until this stage proves a prod VM reaches an on-prem host by private IP and resolves its DNS.
