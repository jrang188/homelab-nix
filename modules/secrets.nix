{ config, lib, ... }:
{
  # Defaults for the real host: the age key is derived from the machine's
  # own SSH host key (sops-nix does this internally, no separate
  # ssh-to-age step needed at runtime), and the encrypted file lives
  # alongside the host's own configuration. VM tests override both to
  # point at a throwaway fixture key/file instead.
  sops.defaultSopsFile = lib.mkDefault ../hosts/${config.networking.hostName}/secrets.yaml;
  sops.age.sshKeyPaths = lib.mkDefault [ "/etc/ssh/ssh_host_ed25519_key" ];

  sops.secrets."tailscale-authkey" = {
    owner = "root";
    mode = "0400";
  };
  sops.secrets."k3s-token" = {
    owner = "root";
    mode = "0400";
  };
}
