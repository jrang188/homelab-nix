# 2. system.autoUpgrade + a custom drain/uncordon hook replaces kured

## Status

Accepted

## Context

The Hetzner control planes use `kured` to coordinate reboots after
unattended OS/k3s upgrades: it cordons/drains a node, reboots it, then
uncordons once healthy, one node at a time across the cluster. `kured`
watches for a reboot-required marker file that's specific to how the
control planes' transactional-update OS (openSUSE Leap Micro) signals a
pending reboot — a mechanism that doesn't exist on NixOS, which has its
own upgrade/reboot model (`nixos-rebuild switch`/`boot` + `reboot`).

Without kured, an unattended NixOS upgrade that changes the kernel or a
systemd-adjacent package still needs the node to reboot, and workloads
running on it still need to not be force-killed mid-reboot.

## Decision

Two independent NixOS-native pieces stand in for kured:

- `system.autoUpgrade` (pull-based, weekly, `allowReboot = true`) drives
  the actual upgrade-and-reboot cycle — NixOS's own equivalent of the
  control planes' "automatically_upgrade_os/kubernetes" behavior.
- A small systemd hook (`Before=reboot.target`) runs `kubectl drain
  --ignore-daemonsets` before the reboot actually happens, and a
  post-boot service runs `kubectl uncordon` once `k3s-agent` is back and
  healthy. It authenticates with a drain-scoped ServiceAccount token
  (least privilege — not the admin kubeconfig), stored via sops-nix.

k3s itself is left to drift passively with whatever version
`nixos-unstable` ships, rather than pinning/overlaying to shadow the
control planes' `k3s_channel = "stable"` version — Kubernetes tolerates a
few minor versions of agent-behind-server skew, and this node doesn't
need to track the server precisely to be useful.

## Consequences

- Drain is best-effort: if it times out (e.g. a PodDisruptionBudget
  blocks eviction), the reboot proceeds anyway rather than blocking
  indefinitely. This node isn't critical enough to justify a stuck
  upgrade pipeline.
- k3s version skew between this node and the control planes is
  unmanaged and will drift over time. Acceptable per this project's
  explicit "doesn't have to be perfect" bar; revisit if skew ever causes
  a real incompatibility.
- The reboot window (weekly, low-traffic) is not otherwise coordinated
  with the control planes' own kured-driven reboot schedule — the two
  systems don't know about each other. Fine for a single agent node;
  would need real coordination if more home nodes are added later.
