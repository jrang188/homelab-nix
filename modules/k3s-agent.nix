{ config, lib, pkgs, ... }:
let
  cfg = config.homelab.k3sAgent;
in
{
  options.homelab.k3sAgent = {
    enable = lib.mkEnableOption "this host as a k3s agent joining the homelab cluster";

    serverAddr = lib.mkOption {
      type = lib.types.str;
      example = "https://cp-1.tailxxxxx.ts.net:6443";
      description = ''
        The k3s server to connect to. k3s's own client-side agent
        load-balancer discovers the other control planes after first
        contact, so any one reachable control plane's address works here.
      '';
    };

    nodeTaints = lib.mkOption {
      type = lib.types.listOf lib.types.str;
      default = [ "node-role.kubernetes.io/home=true:NoSchedule" ];
      description = "k3s node-taint entries applied at agent startup.";
    };

    nodeLabels = lib.mkOption {
      type = lib.types.listOf lib.types.str;
      default = [ "topology.kubernetes.io/zone=home" ];
      description = "k3s node-label entries applied at agent startup.";
    };
  };

  config = lib.mkIf cfg.enable {
    # The Tailscale IP isn't known until tailscaled has actually connected,
    # so it can't be baked into services.k3s.extraFlags at eval time. This
    # generates a k3s config file with the resolved IP just before k3s
    # starts. Bounded wait + graceful fallback (rather than a hard
    # dependency on tailscale login succeeding) so k3s still comes up if
    # Tailscale is ever slow/unreachable at boot - it'll just fall back to
    # k3s's own default node-ip detection until the next restart.
    systemd.services.k3s-agent-config = {
      description = "Generate k3s agent config with the runtime Tailscale IP";
      after = [ "tailscaled.service" ];
      wants = [ "tailscaled.service" ];
      before = [ "k3s.service" ];
      wantedBy = [ "k3s.service" ];
      serviceConfig.Type = "oneshot";
      serviceConfig.RemainAfterExit = true;
      script = ''
        set -uo pipefail

        node_ip=""
        for _ in $(seq 1 30); do
          node_ip="$(${pkgs.tailscale}/bin/tailscale ip -4 2>/dev/null || true)"
          [ -n "$node_ip" ] && break
          sleep 1
        done

        mkdir -p /run/k3s
        {
          if [ -n "$node_ip" ]; then
            echo "node-ip: \"$node_ip\""
            echo "flannel-iface: tailscale0"
          else
            echo "# no Tailscale IP available yet; falling back to k3s defaults" >&2
          fi
          echo "node-taint:"
          ${lib.concatMapStringsSep "\n" (t: ''echo "  - \"${t}\""'') cfg.nodeTaints}
          echo "node-label:"
          ${lib.concatMapStringsSep "\n" (l: ''echo "  - \"${l}\""'') cfg.nodeLabels}
        } > /run/k3s/config.yaml

        exit 0
      '';
    };

    services.k3s = {
      enable = true;
      role = "agent";
      serverAddr = cfg.serverAddr;
      tokenFile = config.sops.secrets."k3s-token".path;
      configPath = "/run/k3s/config.yaml";
    };

    systemd.services.k3s = {
      after = [ "k3s-agent-config.service" ];
      wants = [ "k3s-agent-config.service" ];
    };
  };
}
