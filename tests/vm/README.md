# VM tests

`nixosTest` checks, run via `nix flake check` on `x86_64-linux`. This repo's
development machine (Apple Silicon Mac, no Linux builder configured) can't
build/run these locally — they run in CI (`.github/workflows/ci.yml`) on a
Linux runner instead. `nix eval .#checks.x86_64-linux.<name>.drvPath` still
works locally and catches wiring/eval errors without needing to build.

- **services-active.nix** — boots `modules/tailscale.nix` +
  `modules/k3s-agent.nix` together, asserts `tailscaled.service` and
  `k3s.service` both reach `active`, and that the generated
  `/run/k3s/config.yaml` has the expected taint/label. `serverAddr` points
  at an unreachable address on purpose: a real join to the actual Hetzner
  cluster isn't reachable from an isolated test VM. That part is a manual
  smoke test after the real host is installed.
- **secrets-decrypt.nix** — boots `modules/secrets.nix` with a throwaway
  age key (`fixtures/test-age-key.txt`, safe to commit — it only decrypts
  `fixtures/secrets.yaml`, which holds dummy values), asserts the decrypted
  secrets exist at `/run/secrets/*` with the expected contents and `0400
  root` permissions.

Neither test exercises the real Tailscale auth key or k3s join token —
those stay in `hosts/k3s-agent-hml/secrets.yaml` (not yet created; see that
directory's notes), encrypted to the real host's own age key once it
exists.
