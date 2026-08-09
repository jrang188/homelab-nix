# Agent skills

This file provides guidance to any coding agent when working with code in this repository.

## What this repo is

A Nix flake defining NixOS host configurations for the user's homelab.
Currently one host, `k3s-agent-hml`: a physical mini PC joining an existing
3-control-plane k3s cluster on Hetzner (provisioned separately by
`../opentofu-infra`, the `kube-hetzner` Terraform/OpenTofu module) as a k3s
agent over Tailscale. The repo is structured multi-host-ready
(`hosts/<name>/`, shared `modules/`) since more hosts are expected.

## Commands

- `nix flake check --all-systems` — evaluates everything and, if a Linux
  builder is available, builds+runs the two VM tests.
- **No Linux builder exists on the primary dev machine** (Apple Silicon Mac,
  no `nix.linux-builder`/remote builder configured) — `nix eval` verifies
  wiring/option values without building, but the VM tests only actually
  execute in CI.
  - Eval a config value without building:
    `nix eval .#nixosConfigurations.k3s-agent-hml.config.<path>`
    (e.g. `.config.system.autoUpgrade.dates`).
  - Eval-check a VM test derivation without running it:
    `nix eval .#checks.x86_64-linux.<services-active|secrets-decrypt>.drvPath`.
  - `nix flake check --no-build --all-systems` — full eval pass, no builds;
    catches wiring/type errors even without a builder.
- CI (`.github/workflows/ci.yml`) runs `nix flake check --all-systems` on
  every push — this is where the VM tests actually turn green/red. Check
  with `gh run list` / `gh run view` after pushing.
- Edit a host's secrets: `sops hosts/<host>/secrets.yaml` (needs that host's
  real age key registered in `.sops.yaml` first). `k3s-agent-hml`'s real
  secrets file doesn't exist yet — chicken-and-egg, it needs the host's own
  SSH key, which only exists after install — see
  `hosts/k3s-agent-hml/README.md` for the full first-install checklist.
- Install a host: `nix run github:nix-community/nixos-anywhere -- --flake
  .#<hostname> root@<installer-ip>`.

## Architecture

### Secrets flow (sops-nix)

Each host's age key is derived from its own SSH host key at activation
(`sops.age.sshKeyPaths`, set in `modules/secrets.nix`) — no separately
managed age keys for real hosts. VM tests can't use a real host key (it
doesn't exist at eval time), so they override `sops.age.keyFile` /
`sops.defaultSopsFile` to a throwaway, committed-in-the-clear test key
(`tests/vm/fixtures/test-age-key.txt`) that only decrypts the dummy fixture
(`tests/vm/fixtures/secrets.yaml`).

Every module that declares `sops.secrets.<name>` must have that key present
in whatever sops file is in play for a given eval. A mismatch (secret
declared but absent from the file) fails hard at NixOS **activation**, not
at eval time — `nix eval`/`nix flake check --no-build` won't catch it, only
an actual VM boot will. Declare each secret in the module that consumes it
(see `modules/auto-upgrade.nix`'s `github-netrc`, `modules/drain-hook.nix`'s
`k3s-drain-token`) rather than centralizing unrelated secrets in
`modules/secrets.nix`, or a VM test importing one module but not another
will fail this way.

`homelab-nix` is a private GitHub repo, so `system.autoUpgrade`'s unattended
`nixos-rebuild switch --flake github:...` needs auth — that's what
`github-netrc` (in `modules/auto-upgrade.nix`) is for.

### The kured replacement

The Hetzner cluster uses `kured` for reboot coordination, which depends on
its control planes' transactional-update OS — not applicable to NixOS. Here
that's two independent pieces instead (`docs/adr/0002`):
`system.autoUpgrade` (pull-based, weekly) drives the upgrade/reboot cycle,
and a separate systemd hook (`modules/drain-hook.nix`) does `kubectl
drain`/`uncordon` around the reboot. It authenticates with a dedicated,
least-privilege ServiceAccount token (not the admin kubeconfig) that must be
created once, directly on the cluster — that setup step lives in
`hosts/k3s-agent-hml/README.md`, not in this flake's own apply.

### Cluster networking constraint

The Hetzner cluster's flannel CNI is bound to Hetzner's private network
interface, not Tailscale — Tailscale there is management-only (SSH/kubectl).
A home-joined node's pods can't reach cluster-hosted services until the
control planes advertise their private-network routes over Tailscale, a
companion change that lives in the separate `../opentofu-infra` repo and
isn't applied by anything here (`docs/adr/0001`). Read that ADR before
assuming a home node has full pod-network connectivity.

### Adding another host

`flake.nix` currently hardcodes `system = "x86_64-linux"` once, shared
across `nixosConfigurations` and `checks` — a second host on a different
architecture (e.g. aarch64) needs that generalized, not just a new
`hosts/<name>/` directory.

### Domain docs / ADRs / issue tracking

`CONTEXT.md` (glossary) and `docs/adr/` capture non-obvious decisions
(secret scoping, the networking constraint above) per the conventions in
`docs/agents/domain.md` — read both before cross-cutting changes. Issue
tracking and triage conventions (GitHub Issues via `gh`) are in `AGENTS.md`
and `docs/agents/`.

### Issue tracker

Issues live in this repo's GitHub Issues. See `docs/agents/issue-tracker.md`.

### Triage labels

Five canonical labels with default names. See `docs/agents/triage-labels.md`.

### Domain docs

Single-context layout: `CONTEXT.md` + `docs/adr/` at repo root. See `docs/agents/domain.md`.
