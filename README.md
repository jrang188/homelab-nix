# homelab-nix

NixOS host configurations for the homelab, as a Nix flake. Structured
multi-host-ready (`hosts/<name>/` per machine, shared `modules/`) even
though there's currently one host:

- **`k3s-agent-hml`** — a physical mini PC joining an existing
  3-control-plane k3s cluster on Hetzner (provisioned separately by
  `../opentofu-infra`) as a k3s agent, over Tailscale. See
  [`docs/adr/`](docs/adr/) for why it's built the way it is, and
  [`CONTEXT.md`](CONTEXT.md) for the vocabulary used throughout.

## Using this flake

```
nix flake check --all-systems        # evaluate everything; builds+runs the
                                      # VM tests if a Linux builder exists
nix flake check --no-build --all-systems   # eval only, no builds - works
                                            # without a Linux builder
```

This repo's own dev machine has no Linux builder configured, so the VM
tests (`tests/vm/`) only actually run in CI
([`.github/workflows/ci.yml`](.github/workflows/ci.yml)) — check results
with `gh run list` / `gh run view` after pushing. `nix eval` still verifies
config wiring locally without building, e.g.:

```
nix eval .#nixosConfigurations.k3s-agent-hml.config.system.autoUpgrade.dates
nix eval .#checks.x86_64-linux.services-active.drvPath
```

**Edit a host's secrets** (sops-nix, age key derived from that host's own
SSH host key):

```
sops hosts/<host>/secrets.yaml
```

**Install a host** (partitions via disko, installs from this flake in one
shot):

```
nix run github:nix-community/nixos-anywhere -- \
  --flake .#<hostname> root@<installer-ip>
```

**Add another host**: create `hosts/<name>/`, add a matching
`nixosConfigurations.<name>` in `flake.nix`. Note `flake.nix` currently
hardcodes `system = "x86_64-linux"` once, shared across
`nixosConfigurations` and `checks` — a host on a different architecture
needs that generalized first.

See [`CLAUDE.md`](CLAUDE.md) / [`AGENTS.md`](AGENTS.md) for the fuller
architecture notes (secrets flow, the kured replacement, the cluster
networking constraint) aimed at coding agents working in this repo.

## Next steps for k3s-agent-hml

Not live yet. In order:

1. **Physical install** — fill in the placeholders (`REPLACE_ME`/`TODO` in
   `hosts/k3s-agent-hml/`: real disk ID, control-plane Tailscale hostname,
   your SSH key), then run the install command above.
2. **Create its secrets** — `hosts/k3s-agent-hml/secrets.yaml` doesn't
   exist yet; it needs the host's real SSH key, which only exists after
   step 1.
3. **One-time cluster-side setup** — a drain-scoped ServiceAccount for the
   reboot hook, created directly on the cluster.
4. **Companion change in `../opentofu-infra`** — advertise the Hetzner
   private network over Tailscale
   ([ADR 0001](docs/adr/0001-tailscale-subnet-routes-for-home-agent-pod-network.md)),
   or this node's own pods can't reach cluster-hosted services even though
   the node itself joins fine.

Full checklist with exact commands/manifests:
[`hosts/k3s-agent-hml/README.md`](hosts/k3s-agent-hml/README.md).
