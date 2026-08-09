{
  description = "homelab-nix: NixOS hosts for the homelab, including the k3s-agent-hml Hetzner-cluster agent node";

  inputs = {
    nixpkgs.url = "github:NixOS/nixpkgs/nixos-unstable";

    disko = {
      url = "github:nix-community/disko";
      inputs.nixpkgs.follows = "nixpkgs";
    };

    sops-nix = {
      url = "github:Mic92/sops-nix";
      inputs.nixpkgs.follows = "nixpkgs";
    };
  };

  outputs =
    { self, nixpkgs, disko, sops-nix }:
    let
      system = "x86_64-linux";
      pkgs = import nixpkgs { inherit system; };
    in
    {
      nixosConfigurations.k3s-agent-hml = nixpkgs.lib.nixosSystem {
        inherit system;
        modules = [
          disko.nixosModules.disko
          sops-nix.nixosModules.sops
          ./hosts/k3s-agent-hml/configuration.nix
        ];
      };

      checks.${system} = {
        services-active = import ./tests/vm/services-active.nix { inherit pkgs sops-nix disko; };
        secrets-decrypt = import ./tests/vm/secrets-decrypt.nix { inherit pkgs sops-nix disko; };
      };
    };
}
