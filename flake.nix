{
  description = "The Nixarr Media Server Nixos Module";

  inputs = {
    nixpkgs.url = "github:nixos/nixpkgs/nixpkgs-unstable";
    nixpkgs-sonarr.url = "github:nixos/nixpkgs/328abff1f7a707dc8da8e802f724f025521793ea";

    vpnconfinement.url = "github:Maroka-chan/VPN-Confinement";
  };

  outputs = {
    nixpkgs,
    nixpkgs-sonarr,
    vpnconfinement,
    ...
  } @ inputs: let
    # Systems supported
    supportedSystems = [
      "x86_64-linux" # 64-bit Intel/AMD Linux
      "aarch64-linux" # 64-bit ARM Linux
      "x86_64-darwin" # 64-bit Intel macOS
      "aarch64-darwin" # 64-bit ARM macOS
    ];

    # Helper to provide system-specific attributes
    forAllSystems = f:
      nixpkgs.lib.genAttrs supportedSystems (system:
        f {
          pkgs = import nixpkgs {inherit system;};
        });
  in {
    nixosModules = {
      default = {
        imports = [./nixarr vpnconfinement.nixosModules.default];
        config._module.args = {inherit nixpkgs-sonarr;};
      };
    };

    devShells = forAllSystems ({pkgs}: {
      default = pkgs.mkShell {
        packages = with pkgs; [
          alejandra
          nixd
        ];
      };
    });

    packages = forAllSystems ({pkgs}: {
      default = pkgs.callPackage ./mkDocs.nix {inherit inputs;};
    });

    formatter = forAllSystems ({pkgs}: pkgs.alejandra);
  };
}
