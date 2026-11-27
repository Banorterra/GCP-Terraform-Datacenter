# Module: network-spoke

The network of one environment (dev, qa or prod) in the hub-and-spoke landing zone:

- a custom-mode VPC in the environment's `net-host` project, marked as **Shared VPC host** (stage 4 attaches the
  app projects as service projects);
- one subnet with **Private Google Access**, **flow logs at 50%** and optional secondary ranges (GKE pods/services);
- **Cloud Router + Cloud NAT**, because VMs have no external IPs (org policy);
- an **NCC VPC spoke** on the hub of `3-networks/shared`. With a STAR hub, pass the `edge` group in
  `ncc_spoke_group` so environments only reach the hub (and on-prem through it), never each other;
- **DNS**: a private zone for the environment, plus peering zones to the hub VPC for the names it resolves
  (`gcp.banorterra.internal.` and the on-prem domain it forwards over the HA VPN);
- **firewall**: allow inside the subnet, IAP SSH to VMs tagged `ssh`, ICMP/80/443 from on-prem to VMs tagged
  `allow-onprem`, and an explicit deny-all.

AWS analogy: a VPC shared with RAM to the workload accounts, attached to a Transit Gateway, with a NAT gateway.

Example: [examples/basic](examples/basic). Tests: `terraform test` from this folder (mock provider).

## Inputs

| Name | Description | Default |
|---|---|---|
| `project_id` | Network host project of the environment | required |
| `env` | `dev`, `qa` or `prod` | required |
| `prefix` | Company prefix used in names | required |
| `region` | Region of the subnet, router and NAT | required |
| `subnet_cidr` | Primary range of the subnet | required |
| `secondary_ranges` | Secondary ranges by name | `{}` |
| `flow_logs_sampling` | Fraction of flow logs sampled | `0.5` |
| `ncc_hub_id` | ID of the NCC hub | required |
| `ncc_spoke_group` | NCC group of the spoke (`edge` for a STAR hub) | `null` |
| `hub_network_id` | Hub VPC, target of the DNS peering | required |
| `dns_zone` | Private zone of the environment | required |
| `peered_dns_zones` | Domains resolved by the hub VPC | `[]` |
| `onprem_cidrs` | On-prem ranges allowed in to `allow-onprem` VMs | `[]` |
| `iap_source_range` | IAP TCP forwarding range | `35.235.240.0/20` |
| `labels` | Labels for DNS zones and the NCC spoke | `{}` |

## Outputs

`network_id`, `network_self_link`, `network_name`, `subnet_self_link`, `subnet_cidr`, `secondary_range_names`,
`host_project_id`, `ncc_spoke_id`, `dns_zone_name`.

Regenerate these tables with `terraform-docs markdown table --output-file README.md .` once terraform-docs is set up
(the kms module's README shows the format).
