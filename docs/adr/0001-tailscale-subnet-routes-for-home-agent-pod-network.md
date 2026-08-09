# 1. Home agent needs Hetzner's private-network routes advertised over Tailscale

## Status

Accepted

## Context

The existing Hetzner k3s cluster (`../opentofu-infra`) runs flannel (vxlan
backend) bound to `eth1`, the Hetzner private network interface
(`kube-hetzner` module, `locals.tf:2535`, `flannel_iface = "eth1"`).
Tailscale there is management-plane only (SSH/kubectl access) — it was never
wired as flannel's transport.

`k3s-agent-hml` has no presence on Hetzner's private network; it only has a
Tailscale link to the control planes. If it registers a `tailscale0`-based
node-ip for flannel, the control planes (also Tailscale members) can reach
it, but it has no route back to the control planes' `10.x.x.x` flannel
node-ips. That's asymmetric pod-network connectivity: the home node's pods
would fail to reach ClusterIP services, CoreDNS, or anything else backed by
pods on the Hetzner side, while the reverse direction might work — the kind
of half-broken state that's confusing to debug after the fact rather than
failing loudly up front.

## Decision

Advertise each control plane's own private IP as a Tailscale subnet route
(`--advertise-routes=<private-ip>/32`), and have the home node accept routes
(`--accept-routes` in its `tailscale up` flags).

The `kube-hetzner` module already supports this per-node, off by default in
this repo: `tailscale_node_transport.auth.advertise_node_private_routes`,
currently forced to `false` in `../opentofu-infra/terraform/k3s/kube.tf:47`.
Flipping it to `true` makes each control plane advertise **only its own
`/32`** (`locals.tf:387`), not the shared subnet CIDR.

This is reboot-safe by construction, with no extra HA-subnet-router wiring
needed: when a control plane goes down for its kured-driven rolling
upgrade, its own `/32` route naturally drops — which is correct, since
nothing could reach that node while it's down regardless — while the other
two control planes keep advertising theirs, so the home node retains
connectivity to whichever control planes are currently up.

## Consequences

- Requires a companion change in `opentofu-infra`
  (`advertise_node_private_routes = true` in `terraform/k3s/kube.tf`,
  `tofu apply`) plus one-time manual approval of the 3 new routes in the
  Tailscale admin console. This is **not** part of the `homelab-nix` flake
  and must be applied there before `k3s-agent-hml` has full pod-network
  reachability to the cluster.
- Until that companion change lands, `k3s-agent-hml` can join the cluster
  and be reached by Hetzner-side pods, but its own pods cannot reliably
  reach cluster-hosted services (DNS, ClusterIPs, etc).
- If Hetzner-side node count grows significantly, revisit whether per-node
  `/32` routes should become a single subnet-CIDR advertisement instead
  (trades a bit of blast radius for less Terraform/ACL churn per node).
