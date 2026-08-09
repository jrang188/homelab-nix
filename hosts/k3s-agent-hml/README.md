# k3s-agent-hml — first-install checklist

Placeholders that must be filled in with real values before this host can
actually be installed/deployed (search the repo for `REPLACE_ME` / `TODO`):

1. **`disko.nix`** — `disk.main.device`: boot the machine with any Linux
   installer, run `ls /dev/disk/by-id/` to find the real disk identifier.
2. **`configuration.nix`** — `homelab.k3sAgent.serverAddr`: any one control
   plane's Tailscale MagicDNS hostname (Tailscale admin console → Machines).
3. **`configuration.nix`** — `users.users.root.openssh.authorizedKeys.keys`:
   your real SSH public key, needed for `nixos-anywhere`'s install step and
   any fallback access outside Tailscale SSH.
4. **`hardware-configuration.nix`** — regenerate against real hardware after
   install (`nixos-generate-config --no-filesystems`), see the comment in
   that file.

## Secrets (not yet created — see ../../modules/secrets.nix)

`secrets.yaml` in this directory doesn't exist yet. Create it after the
above install completes and the host has a real SSH host key:

```
ssh-to-age -i /etc/ssh/ssh_host_ed25519_key.pub   # get the recipient
# add the resulting age1... key to .sops.yaml's k3s_agent_hml anchor,
# uncomment the matching creation_rules entry, then:
sops hosts/k3s-agent-hml/secrets.yaml
```

Required keys in that file:

- `tailscale-authkey` — reusable, non-ephemeral, from the same Tailscale
  account as the control planes.
- `k3s-token` — the join token from any control plane
  (`tofu output -raw kubeconfig`, or `cat /var/lib/rancher/k3s/server/node-token`
  on a control plane over SSH).
- `github-netrc` — `machine github.com\nlogin x-access-token\npassword <PAT>`,
  a token with read access to this repo, for unattended `system.autoUpgrade`.
- `k3s-drain-token` — bearer token for the drain-scoped ServiceAccount
  (see below).

## One-time cluster-side setup

`modules/drain-hook.nix` authenticates as a dedicated ServiceAccount scoped
to draining/cordoning only this node — it doesn't exist yet and must be
created once, directly against the cluster (not part of this flake):

```yaml
apiVersion: v1
kind: ServiceAccount
metadata:
  name: k3s-agent-hml-drain
  namespace: kube-system
---
apiVersion: rbac.authorization.k8s.io/v1
kind: ClusterRole
metadata:
  name: k3s-agent-hml-drain
rules:
  - apiGroups: [""]
    resources: ["nodes"]
    verbs: ["get", "patch"]
  - apiGroups: [""]
    resources: ["pods"]
    verbs: ["get", "list"]
  - apiGroups: [""]
    resources: ["pods/eviction"]
    verbs: ["create"]
---
apiVersion: rbac.authorization.k8s.io/v1
kind: ClusterRoleBinding
metadata:
  name: k3s-agent-hml-drain
roleRef:
  apiGroup: rbac.authorization.k8s.io
  kind: ClusterRole
  name: k3s-agent-hml-drain
subjects:
  - kind: ServiceAccount
    name: k3s-agent-hml-drain
    namespace: kube-system
```

Then extract its token (`kubectl create token k3s-agent-hml-drain -n
kube-system --duration=87600h` or a long-lived Secret-based token, per your
cluster's Kubernetes version) for the `k3s-drain-token` secret above.

Also see [ADR 0001](../../docs/adr/0001-tailscale-subnet-routes-for-home-agent-pod-network.md):
the control planes need `advertise_node_private_routes = true` in
`../opentofu-infra` for this node's own pods to reach cluster-hosted
services.

## Install

```
nix run github:nix-community/nixos-anywhere -- \
  --flake .#k3s-agent-hml root@<installer-ip>
```
