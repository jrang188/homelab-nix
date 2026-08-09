{ lib, ... }:
{
  # Placeholder. Regenerate against the real hardware after nixos-anywhere
  # installs this host, e.g.:
  #   nixos-generate-config --no-filesystems --root /mnt
  # then copy the resulting hardware-configuration.nix here (filesystems are
  # handled declaratively by disko.nix instead of nixos-generate-config's
  # output, so --no-filesystems avoids conflicting mount definitions).
  boot.initrd.availableKernelModules = [ "xhci_pci" "ahci" "nvme" "usbhid" "sd_mod" ];
  boot.initrd.kernelModules = [ ];
  boot.kernelModules = [ "kvm-intel" ];
  boot.extraModulePackages = [ ];

  nixpkgs.hostPlatform = lib.mkDefault "x86_64-linux";
  hardware.cpu.intel.updateMicrocode = lib.mkDefault true;
}
