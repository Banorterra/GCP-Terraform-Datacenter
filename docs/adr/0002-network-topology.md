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
  `modules/network-spoke`). Edges only reach the center. `preset_topology` can only be set when the hub is created.
- **One root per environment.** `3-networks/envs/shared` (hub VPC, HA VPN, NCC hub, DNS hub, onprem-sim) and
  `envs/{dev,qa,prod}`, which all call `modules/network-spoke`: a Shared VPC host VPC in the environment's
  `net-host` project, one subnet (Private Google Access, 50% flow logs, GKE secondary ranges), Cloud NAT, the NCC
  spoke, DNS and base firewall rules. CIDRs come from `cidr_plan` in `envs/shared` (sandbox plan until the client
  signs one); `policies/network.rego` rejects any subnet that overlaps on-prem.
- **Simulated on-prem.** There is no client router in the sandbox, so `envs/shared` builds a separate VPC in the
  `c-onprem-sim` project with its own HA VPN gateway and Cloud Router (BGP, ASN 64513) and a small VM that answers
  DNS (`banorterra.local.`) and HTTP. Swapping it for the real datacenter means replacing the peer side of the
  tunnels with the client's gateway (`peer_external_gateway`) and its ASN.
- **DNS.** The hub owns `gcp.banorterra.internal.` and a forwarding zone for `banorterra.local.` that sends queries
  to on-prem over the VPN. Each environment has its own private zone (`<env>.gcp.banorterra.internal.`) and peering
  zones to the hub for both domains. Forwarded queries come from Cloud DNS's range `35.199.192.0/19`: the hub's
  Cloud Router must advertise it to on-prem and the on-prem firewall must allow it on port 53.
- **Sprint 4 gate.** `enable_gate_vm` in an environment root creates a test VM that resolves the on-prem host,
  pings it and fetches it over HTTP, and prints the result to its serial console (stage 3 README).

### Still open
- On-prem routes reaching the environment spokes: confirm on the first apply. If the routes the hub VPC learns over
  BGP do not reach the edge spokes, attach the HA VPN tunnels to the hub as a hybrid spoke.
- Hierarchical firewall policies and secure tags (spec: allow by secure tag). Today the rules are VPC firewall rules
  with network tags. Secure tags need `roles/resourcemanager.tagAdmin` for a stage account, a stage 0 change.
