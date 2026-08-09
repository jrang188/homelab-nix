{ config, lib, ... }:
{
  # netrc-format credentials so system.autoUpgrade can fetch this flake's
  # inputs from the private GitHub repo unattended.
  # Contents: "machine github.com\nlogin x-access-token\npassword <PAT>\n"
  sops.secrets."github-netrc" = {
    owner = "root";
    mode = "0400";
  };

  # homelab-nix is a private repo, so unattended fetches of this flake's
  # own source need auth. netrc-file keeps the token out of the
  # world-readable /etc/nix/nix.conf, unlike nix.settings.access-tokens.
  nix.settings.netrc-file = config.sops.secrets."github-netrc".path;

  system.autoUpgrade = {
    enable = true;
    flake = "github:jrang188/homelab-nix#${config.networking.hostName}";
    operation = "switch";
    dates = "Sun *-*-* 03:00:00";
    randomizedDelaySec = "30min";
    persistent = true;
    allowReboot = true;
  };
}
