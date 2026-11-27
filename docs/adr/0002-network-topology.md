# ADR 0002: Hub-and-spoke on Shared VPC, no spoke-to-spoke traffic

- Status: Accepted (it is what the spec asks for)
- Date: 2026-11-03
- Deciders: Cloud architect, network engineer

## Context
Google's landing-zone guide recommends Shared VPC per environment for most cases, and hub-and-spoke
with appliances when Layer 7 inspection is needed. The spec asks for hub-and-spoke: one hub project
holds networking and connectivity, on-premises and Internet traffic enter only through the hub, and
environments have no public IPs and no direct connectivity to each other. It also lists Cloud Armor and
Cloud IDS (managed services, not appliances).

## Options
| Option | Pros | Cons |
|---|---|---|
| Shared VPC per environment (guide default) | Simplest | Each environment would need its own on-prem connectivity |
| Hub-and-spoke, no appliances | One place for VPN/DNS, isolation between spokes | No Layer 7 inspection |
| Hub-and-spoke with appliances (NVAs) | Layer 7 inspection, controlled spoke-to-spoke | Extra cost and operations; must manage the appliances |

## Decision
Hub-and-spoke without appliances, implemented from the example foundation's `3-networks-hub-and-spoke`
(Network Connectivity Center hub, Shared VPC host project per environment, global DNS hub).
Spoke-to-spoke transitivity stays off.

## Why
Matches the spec's isolation rule and keeps one HA VPN pair in the hub. Managed Cloud Armor and Cloud IDS
cover the perimeter requirements without running appliances.

## Consequences
- If the client later needs Layer 7 inspection or cross-environment traffic, revisit: the example supports
  it through its transitivity option with NVAs in the hub, and its default rule for that raises SCC findings
  until tightened.
- The spec says "no critical or high SCC findings": check each default firewall rule from the example against that.

## Update 2026-11-27: how it is built (PRs #16 and #19)
- **NCC hub in STAR topology.** With the default MESH, every VPC spoke exchanges subnet routes with every other one,
  so dev, qa and prod would reach each other. The hub uses `preset_topology = "STAR"`: the hub VPC is a spoke in the
  `center` group, and each environment VPC is a spoke in the `edge` group (`ncc_spoke_group` in
  `modules/network-spoke`, by default the `ncc_edge_group` output of `envs/shared`). The two HA VPN tunnels are a
  hybrid spoke in the `center` group, so the edges import the on-prem routes. Edges only reach the center. `preset_topology` can only be set when the hub is created.
- **One root per environment.** `3-networks/envs/shared` (hub VPC, HA VPN, NCC hub, DNS hub, simulated on-prem) and
  `envs/{dev,qa,prod}`, which all call `modules/network-spoke`: a Shared VPC host VPC in the environment's
  `net-host` project, one subnet (Private Google Access, 50% flow logs, GKE secondary ranges), Cloud NAT, the NCC
  spoke, DNS and base firewall rules. CIDRs come from `cidr_plan` in `envs/shared`, the plan of the team's diagrams
  (hub 10.0.0.0/22, prod 10.10.0.0/16, dev 10.20.0.0/16, qa 10.30.0.0/16, on-prem 172.16.0.0/16) until the client
  signs one; `policies/network.rego` rejects any subnet that overlaps on-prem.
- **Simulated on-prem.** There is no client router in the sandbox, so `envs/shared` builds a second VPC inside
  `net-hub` (not its own project: free-trial billing accounts link only 3 projects, ADR 0007) with its own HA VPN
  gateway and Cloud Router (BGP, ASN 64513) and a small VM that answers
  DNS (`banorterra.local.`) and HTTP, with Cloud NAT so its startup script can install packages. Swapping it for the real datacenter means replacing the peer side of the
  tunnels with the client's gateway (`peer_external_gateway`) and its ASN.
- **DNS.** The hub owns `gcp.banorterra.internal.` and a forwarding zone for `banorterra.local.` that sends queries
  to on-prem over the VPN. Each environment has its own private zone (`<env>.gcp.banorterra.internal.`) and peering
  zones to the hub for both domains. Forwarded queries come from Cloud DNS's range `35.199.192.0/19`: the hub's
  Cloud Router advertises it to on-prem, together with the dev, qa and prod blocks, and the on-prem firewall allows
  it on port 53.
- **Sprint 4 gate.** `enable_gate_vm` in an environment root creates a test VM that resolves the on-prem host,
  pings it and fetches it over HTTP, and prints the result to its serial console (stage 3 README).

### Still open
- On-prem routes reaching the environment spokes through the VPN hybrid spoke: confirm on the first apply.
- The environment spokes are created in the hub's project and link a VPC of another project (`<env>-net-host`).
  NCC documents the other direction (spoke in the VPC's project, accepted by the hub admin); confirm with dev first.
- Hierarchical firewall policies and secure tags (spec: allow by secure tag). Today the rules are VPC firewall rules
  with network tags. Secure tags need `roles/resourcemanager.tagAdmin` for a stage account, a stage 0 change.
