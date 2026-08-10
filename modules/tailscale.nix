{ config, lib, ... }:
{
  services.tailscale = {
    enable = true;
    authKeyFile = config.sops.secrets."tailscale-authkey".path;
    extraUpFlags = [
      # Tag naming convention (shared with ../opentofu-infra): tag:k8s-<role>
      # or tag:k8s-<role>-<location>. Requires tag:k8s-agent-home to be owned
      # in the Tailnet ACL's tagOwners before this applies cleanly.
      "--advertise-tags=tag:k8s-agent-home"
      # MagicDNS must stay accepted (default) - homelab.k3sAgent.serverAddr
      # is a .ts.net hostname, and control planes get re-provisioned with
      # new hostnames periodically (already happened once), so this can't
      # be swapped for a raw IP either.
      "--accept-routes"
      "--ssh"
    ];
  };

  # tailscaled-autoconnect.service is the unit that actually runs `tailscale
  # up` using authKeyFile; anything binding to a Tailscale IP should order
  # after it (per services.tailscale.authKeyFile's own documentation).
  networking.firewall.trustedInterfaces = [ "tailscale0" ];
  networking.firewall.checkReversePath = "loose";
}
