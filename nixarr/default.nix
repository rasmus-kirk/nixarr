sub-merge: vpnconfinement: { pkgs, ... }: {
  imports = [
    vpnconfinement.nixosModules.default
    ./nixarr.nix
  ];

  config.environment.systemPackages = [ sub-merge.packages."${pkgs.system}".default ];
}
