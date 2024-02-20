{
  description = "Kirk nix modules";

  nixConfig = {
    extra-substituters = ["https://nix-community.cachix.org"];
    extra-trusted-public-keys = ["nix-community.cachix.org-1:mB9FSh9qf2dCimDSUo8Zy7bkq5CX+/rkCWyvRCYg3Fs="];
  };

  inputs = {
    #nixpkgs.url = "github:nixos/nixpkgs/22.11";
    nixpkgs.url = "github:nixos/nixpkgs/nixpkgs-unstable";
    nixpkgs-flood.url = "github:3JlOy-PYCCKUi/nixpkgs/flood-module";
    #nixpkgs-unstable.url = "github:nixos/nixpkgs/nixpkgs-unstable";

    home-manager.url = "github:nix-community/home-manager";

    flake-parts = {
      url = "github:hercules-ci/flake-parts";
      inputs.nixpkgs-lib.follows = "nixpkgs";
    };
    flake-root.url = "github:srid/flake-root";

    devshell = {
      url = "github:numtide/devshell";
      inputs.nixpkgs.follows = "nixpkgs";
    };
    treefmt-nix = {
      url = "github:numtide/treefmt-nix";
      inputs.nixpkgs.follows = "nixpkgs";
    };
  };

  outputs = inputs @ {flake-parts, ...}:
    flake-parts.lib.mkFlake {
      inherit inputs;
    }
    rec {
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
          kirk = import ./nixos;
          default = kirk;
        };
        homeManagerModules = rec {
          kirk = import ./home-manager;
          default = kirk;
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

        packages = {
          docs = pkgs.callPackage ./mkDocs.nix { inherit inputs; };
          hugo = pkgs.callPackage ./mkHugo.nix { inherit inputs; };
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

  #  outputs = {
  #    self,
  #    }: {
  #    nixosModules.kirk = import ./nixos;
  #    nixosModules.default = self.nixosModules.kirk;
  #
  #    homeManagerModules.kirk = import ./home-manager;
  #    homeManagerModules.default = self.homeManagerModules.kirk;
  #
  #    # TODO: Find a way to generate documentation from modules using the same
  #    #       tools as nixos. See ./mkDocs.nix
  #
  #    #packages.x86_64-linux.mkdocs = {};
  #    #defaultPackage.x86_64-linux = self.packages.x86_64-linux.report;
  #  };
}
