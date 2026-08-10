{ config, lib, ... }:
{
  # nix.conf access-tokens format, so system.autoUpgrade can fetch this
  # flake's inputs (and the flake source itself) from the private GitHub
  # repo unattended. Contents: "access-tokens = github.com=<PAT>\n"
  #
  # Nix's github: fetcher hits multiple GitHub hostnames (api.github.com
  # for ref resolution, github.com/codeload.github.com for the archive
  # download) and netrc's exact-hostname matching doesn't reliably cover
  # all of them - access-tokens is what the fetcher is actually built
  # around, and handles this internally. Included via `!include` (nix.conf
  # syntax, parsed at nix-invocation time) rather than
  # nix.settings.access-tokens so the token stays out of the
  # world-readable /etc/nix/nix.conf and out of the Nix store.
  sops.secrets."github-access-tokens" = {
    owner = "root";
    mode = "0400";
  };

  nix.extraOptions = "!include ${config.sops.secrets."github-access-tokens".path}";

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
