{ pkgs, sops-nix, disko }:
pkgs.testers.nixosTest {
  name = "services-active";

  nodes.machine =
    { lib, ... }:
    {
      imports = [
        sops-nix.nixosModules.sops
        ../../modules/secrets.nix
        ../../modules/tailscale.nix
        ../../modules/k3s-agent.nix
        ../../modules/gvisor.nix
      ];

      networking.hostName = "k3s-agent-hml-test";

      homelab.k3sAgent = {
        enable = true;
        # Deliberately unreachable: this seam only verifies both services
        # reach "active" with the expected generated config, not a real
        # join to a live cluster (can't reach one from an isolated test
        # VM). See tests/vm/README.md.
        serverAddr = "https://127.0.0.1:16443";
      };

      homelab.gvisor.enable = true;

      # Test-only: throwaway fixture key/file instead of the real host's
      # ssh-host-key-derived one (see modules/secrets.nix).
      sops.age.sshKeyPaths = lib.mkForce [ ];
      sops.age.keyFile = "/etc/test-age-key.txt";
      sops.defaultSopsFile = lib.mkForce ./fixtures/secrets.yaml;
      environment.etc."test-age-key.txt".source = ./fixtures/test-age-key.txt;
    };

  testScript = ''
    machine.wait_for_unit("tailscaled.service")
    machine.wait_for_unit("k3s-agent-config.service")
    machine.wait_for_unit("k3s.service")

    config_yaml = machine.succeed("cat /run/k3s/config.yaml")
    assert "node-taint:" in config_yaml, "missing node-taint section"
    assert "node-role.kubernetes.io/home=true:NoSchedule" in config_yaml, "missing expected home taint"
    assert "node-label:" in config_yaml, "missing node-label section"
    assert "topology.kubernetes.io/zone=home" in config_yaml, "missing expected home label"

    k3s_state = machine.succeed("systemctl is-active k3s.service").strip()
    assert k3s_state == "active", f"k3s.service not active: {k3s_state!r}"

    ts_state = machine.succeed("systemctl is-active tailscaled.service").strip()
    assert ts_state == "active", f"tailscaled.service not active: {ts_state!r}"

    # gvisor: containerd must have the `runsc` runtime registered. The
    # handler name has to match the cluster-side RuntimeClass's `handler`
    # field exactly (homelab-k8s, ADR-0003 there).
    ctmpl = machine.succeed("cat /var/lib/rancher/k3s/agent/etc/containerd/config.toml.tmpl")
    assert 'runtimes."runsc"' in ctmpl, "runsc runtime not registered in containerd config template"
    assert 'io.containerd.runsc.v1' in ctmpl, "runsc runtime_type not set to gvisor's containerd shim type"

    # gvisor: pkgs.gvisor must provide the containerd shim at the path the
    # k3s unit's PATH points at (systemd.services.k3s.path in
    # modules/gvisor.nix). Check the exact store path rather than scanning
    # the whole store.
    machine.succeed("test -x ${pkgs.gvisor}/bin/containerd-shim-runsc-v1")
  '';
}
