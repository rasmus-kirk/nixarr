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
  };

  outputs = {
    nixpkgs,
    vpnconfinement,
    submerger,
    ...
  } @ inputs:
    let
      # Systems supported
      supportedSystems = [
        "x86_64-linux" # 64-bit Intel/AMD Linux
        "aarch64-linux" # 64-bit ARM Linux
        "x86_64-darwin" # 64-bit Intel macOS
        "aarch64-darwin" # 64-bit ARM macOS
      ];

      # Helper to provide system-specific attributes
      forAllSystems = f: nixpkgs.lib.genAttrs supportedSystems (system: f {
        pkgs = import nixpkgs { inherit system; };
      });
    in {
      nixosModules = rec {
        nixarr = import ./nixarr submerger vpnconfinement;
        imports = [ vpnconfinement.nixosModules.default ];
        default = nixarr;
      };

      devShells = forAllSystems ({ pkgs } : {
        default = pkgs.mkShell {
          packages = with pkgs; [
            alejandra
          ];
        };
      });

      packages = forAllSystems ({ pkgs } : {
        default = pkgs.mkShell rec {
          docs = pkgs.callPackage ./mkDocs.nix {inherit inputs;};
          default = docs;
        };
      });

      formatters = forAllSystems ({ pkgs } : {
        default = pkgs.alejandra;
      });
    };
}
