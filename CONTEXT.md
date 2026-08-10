# Domain glossary

## Control plane

A Hetzner Cloud server running `k3s` with `role = server`, provisioned by
`../opentofu-infra` (the `kube-hetzner` module). There are 3, forming an
HA cluster over embedded etcd. Reachable only via Tailscale (public
SSH/API are closed). Auto-upgrades OS and k3s unattended; reboots are
coordinated by `kured`, which only runs on the control planes' transactional
OS (openSUSE Leap Micro) — not applicable to NixOS hosts.

## Agent node

A `k3s` node with `role = agent`: joins an existing cluster, runs
workloads, does not participate in etcd/control-plane duties. The
Hetzner cluster currently has zero agent nodes (`agent_nodepools = []`);
`k3s-agent-hml` is the first.

## Home node

`k3s-agent-hml` — the physical mini PC running NixOS, joined to the
Hetzner cluster as a k3s agent over Tailscale. Distinguished from the
control planes by: unmanaged physical hardware (not cloud-provisioned),
consumer-grade network reliability/bandwidth, and no kured-based upgrade
coordination (see [[0002]]). Tainted
(`node-role.kubernetes.io/home=true:NoSchedule`) so only workloads that
explicitly tolerate a home node get scheduled there.

## Flannel node-ip

The address each node registers with k3s/flannel for pod-network (CNI)
routing — distinct from the node's Tailscale IP or any address used for
kubectl/API access. Control planes register their Hetzner private-network
IP (`eth1`); the home node registers its Tailscale IP. See
[ADR 0001](docs/adr/0001-tailscale-subnet-routes-for-home-agent-pod-network.md)
for why the home node also needs a Tailscale-advertised route to the
control planes' flannel node-ips, not just the reverse.

## Join token / auth key

Two distinct secrets, both delivered via sops-nix, never in git plaintext:
- **k3s token** — lets an agent register with a control plane's server API.
- **Tailscale auth key** — lets a device join the tailnet. The home node
  uses a reusable, non-ephemeral key (matching the control planes'
  convention) and a dedicated ACL tag (`tag:k8s-home-agent`), not the
  user's personal Tailscale identity.

## Related repositories

- [homelab-k8s](https://github.com/jrang188/homelab-k8s) — Helm chart repository
  defining cluster workloads and services.
- [opentofu-infra](https://github.com/jrang188/opentofu-infra) — OpenTofu/Terraform
  code provisioning the Hetzner k3s control planes using the `kube-hetzner` module.
