{ config, lib, pkgs, ... }:
let
  cfg = config.homelab.k3sAgent;

  # A drain-scoped ServiceAccount (drain/cordon/uncordon on this node only)
  # must exist on the cluster already - it's a one-time kubectl-apply step,
  # not something this flake can create (see hosts/k3s-agent-hml/README.md).
  # TLS verification is skipped rather than shipping a cluster CA cert: the
  # transport is already Tailscale (authenticated, encrypted WireGuard),
  # so this is a reduced-severity concession, not equivalent to skipping
  # TLS on an open, internet-facing endpoint.
  kubectlArgs = "--server=${cfg.serverAddr} --token=$(cat ${config.sops.secrets."k3s-drain-token".path}) --insecure-skip-tls-verify=true";
in
{
  config = lib.mkIf cfg.enable {
    sops.secrets."k3s-drain-token" = {
      owner = "root";
      mode = "0400";
    };

    # Best-effort: proceed with the reboot even if drain fails or times
    # out (e.g. a PodDisruptionBudget blocks eviction) rather than
    # blocking the machine from rebooting indefinitely.
    systemd.services.k3s-drain-before-reboot = {
      description = "Drain this k3s node before reboot";
      before = [ "reboot.target" ];
      wantedBy = [ "reboot.target" ];
      after = [ "k3s.service" ];
      serviceConfig.Type = "oneshot";
      script = ''
        ${pkgs.kubectl}/bin/kubectl ${kubectlArgs} drain ${config.networking.hostName} \
          --ignore-daemonsets --delete-emptydir-data --timeout=60s || true
      '';
    };

    systemd.services.k3s-uncordon-after-boot = {
      description = "Uncordon this k3s node once it has rejoined the cluster";
      after = [ "k3s.service" ];
      wantedBy = [ "multi-user.target" ];
      serviceConfig.Type = "oneshot";
      script = ''
        for _ in $(seq 1 30); do
          ${pkgs.kubectl}/bin/kubectl ${kubectlArgs} uncordon ${config.networking.hostName} && exit 0
          sleep 2
        done
        exit 0
      '';
    };
  };
}
