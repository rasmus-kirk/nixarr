#submerger: vpnconfinement: { pkgs, ... }: {
vpnconfinement: { pkgs, ... }: {
  imports = [
    vpnconfinement.nixosModules.default
    ./nixarr.nix
  ];

  #config.environment.systemPackages = [ submerger.packages."${pkgs.system}".default ];
}
