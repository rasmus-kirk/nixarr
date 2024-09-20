{
  description = "The Nixarr Media Server Nixos Module";

  nixConfig = {
    extra-substituters = ["https://nix-community.cachix.org"];
    extra-trusted-public-keys = ["nix-community.cachix.org-1:mB9FSh9qf2dCimDSUo8Zy7bkq5CX+/rkCWyvRCYg3Fs="];
  };

  inputs = {
    nixpkgs.url = "github:nixos/nixpkgs/nixpkgs-unstable";

    vpnconfinement.url = "github:Maroka-chan/VPN-Confinement";
    vpnconfinement.inputs.nixpkgs.follows = "nixpkgs";

    submerger.url = "github:rasmus-kirk/submerger";
    submerger.inputs.nixpkgs.follows = "nixpkgs";

    # Flake stuff
    flake-parts.url = "github:hercules-ci/flake-parts";
    flake-parts.inputs.nixpkgs-lib.follows = "nixpkgs";

    flake-root.url = "github:srid/flake-root";

    devshell.url = "github:numtide/devshell";
    devshell.inputs.nixpkgs.follows = "nixpkgs";

    treefmt-nix.url = "github:numtide/treefmt-nix";
    treefmt-nix.inputs.nixpkgs.follows = "nixpkgs";
  };

  outputs = {
    flake-parts,
    vpnconfinement,
    submerger,
    ...
  } @ inputs:
    flake-parts.lib.mkFlake {
      inherit inputs;
    } {
      imports = with inputs; [
        flake-root.flakeModule
        treefmt-nix.flakeModule
        devshell.flakeModule
      ];
      systems = [
        "x86_64-linux"
      ];

      flake = {
        nixosModules = rec {
          nixarr = import ./nixarr submerger vpnconfinement;
          imports = [ vpnconfinement.nixosModules.default ];
          default = nixarr;
        };
      };

      perSystem = {
        config,
        pkgs,
        ...
      }: {
        treefmt.config = {
          inherit (config.flake-root) projectRootFile;
          package = pkgs.treefmt;

          programs = {
            alejandra.enable = true;
            deadnix.enable = true;
          };
        };

        packages = rec {
          docs = pkgs.callPackage ./mkDocs.nix {inherit inputs;};
          default = docs;
        };

        devshells.default = {
          name = "Rasmus Kirk";

          commands = [
            {
              category = "Tools";
              name = "fmt";
              help = "Format the source tree";
              command = "nix fmt";
            }
          ];
        };
      };
    };
}
