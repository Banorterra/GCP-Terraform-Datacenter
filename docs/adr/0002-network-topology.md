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
