{ lib, pkgs, ... }:
{
  imports = [
    ./disko.nix
    ./hardware-configuration.nix
    ../../modules/secrets.nix
    ../../modules/tailscale.nix
    ../../modules/k3s-agent.nix
    ../../modules/auto-upgrade.nix
    ../../modules/drain-hook.nix
  ];

  networking.hostName = "k3s-agent-hml";

  homelab.k3sAgent = {
    enable = true;
    # TODO: replace with a real control plane's Tailscale MagicDNS
    # hostname before first deploy (see ../../docs/adr for why any one
    # reachable control plane is enough - k3s's own agent load-balancer
    # discovers the others after first contact).
    serverAddr = "https://REPLACE_ME_CONTROL_PLANE.REPLACE_ME.ts.net:6443";
  };

  boot.loader.systemd-boot.enable = true;
  boot.loader.efi.canTouchEfiVariables = true;

  networking.useDHCP = lib.mkDefault true;
  networking.firewall.enable = true;

  services.openssh = {
    enable = true;
    settings = {
      PasswordAuthentication = false;
      PermitRootLogin = "prohibit-password";
    };
  };

  # TODO: replace with the real key(s) before first deploy - needed for
  # nixos-anywhere's initial install and any fallback access outside
  # Tailscale SSH (services.tailscale's --ssh flag, see ../../modules/tailscale.nix).
  users.users.root.openssh.authorizedKeys.keys = [
    "ssh-ed25519 AAAAREPLACEMEREPLACEMEREPLACEMEREPLACEMEREPLACEME replace-me@example.com"
  ];

  environment.systemPackages = [ pkgs.git pkgs.kubectl ];

  nix.settings.experimental-features = [ "nix-command" "flakes" ];

  time.timeZone = "America/Vancouver";

  system.stateVersion = "25.05";
}
