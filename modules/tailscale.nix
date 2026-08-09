{ config, lib, ... }:
{
  services.tailscale = {
    enable = true;
    authKeyFile = config.sops.secrets."tailscale-authkey".path;
    extraUpFlags = [
      "--advertise-tags=tag:k8s-home-agent"
      "--accept-dns=false"
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
