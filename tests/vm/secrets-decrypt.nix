{ pkgs, sops-nix, disko }:
pkgs.testers.nixosTest {
  name = "secrets-decrypt";

  nodes.machine =
    { lib, ... }:
    {
      imports = [
        sops-nix.nixosModules.sops
        ../../modules/secrets.nix
      ];

      networking.hostName = "k3s-agent-hml-test";

      # Test-only: throwaway fixture key/file instead of the real host's
      # ssh-host-key-derived one (see modules/secrets.nix).
      sops.age.sshKeyPaths = lib.mkForce [ ];
      sops.age.keyFile = "/etc/test-age-key.txt";
      sops.defaultSopsFile = lib.mkForce ./fixtures/secrets.yaml;
      environment.etc."test-age-key.txt".source = ./fixtures/test-age-key.txt;
    };

  testScript = ''
    machine.wait_for_unit("multi-user.target")
    machine.wait_for_file("/run/secrets/tailscale-authkey")
    machine.wait_for_file("/run/secrets/k3s-token")

    authkey = machine.succeed("cat /run/secrets/tailscale-authkey").strip()
    assert authkey == "tskey-auth-test-dummy-not-real", f"unexpected authkey contents: {authkey!r}"

    token = machine.succeed("cat /run/secrets/k3s-token").strip()
    assert token == "K10test::server:dummytoken", f"unexpected token contents: {token!r}"

    perms = machine.succeed("stat -c '%a %U' /run/secrets/tailscale-authkey").strip()
    assert perms == "400 root", f"unexpected perms/owner: {perms!r}"

    perms_token = machine.succeed("stat -c '%a %U' /run/secrets/k3s-token").strip()
    assert perms_token == "400 root", f"unexpected perms/owner: {perms_token!r}"
  '';
}
