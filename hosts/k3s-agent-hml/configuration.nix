{ lib, pkgs, ... }:
{
  imports = [
    ./disko.nix
    ./hardware-configuration.nix
    ../../modules/secrets.nix
    ../../modules/tailscale.nix
    ../../modules/k3s-agent.nix
    ../../modules/gvisor.nix
    ../../modules/auto-upgrade.nix
    ../../modules/drain-hook.nix
  ];

  homelab.k3sAgent = {
    enable = true;
    serverAddr = "https://k3s-control-plane-iws.tail8255cc.ts.net:6443";
  };

  # Companion to the cluster-side gVisor `RuntimeClass` (homelab-k8s,
  # ADR-0003 there). This module is what makes the `runsc` handler resolve
  # to a working runtime on this node. See modules/gvisor.nix.
  homelab.gvisor.enable = true;

  boot.loader.systemd-boot.enable = true;
  boot.loader.efi.canTouchEfiVariables = true;

  networking = {
    hostName = "k3s-agent-hml";
    useDHCP = lib.mkDefault true;
    firewall.enable = true;
  };

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
    "ssh-ed25519 AAAAC3NzaC1lZDI1NTE5AAAAIGy4mAWMh9Ts5qlE2ollxo4CtHGKdtSQ91z6xcXRUcj5"
  ];

  environment.systemPackages = [
    pkgs.git
    pkgs.kubectl
  ];

  nix.settings.experimental-features = [
    "nix-command"
    "flakes"
  ];

  time.timeZone = "America/Vancouver";

  system.stateVersion = "25.05";
}
