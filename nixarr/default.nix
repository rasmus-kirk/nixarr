{ submerger, pkgs, ... }: {
  imports = [
    ./nixarr.nix
  ];

  config.environment.systemPackages = [ submerger.packages."${pkgs.system}".default ];
}
