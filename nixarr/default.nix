vpnconfinement: {...}: {
  imports = [
    vpnconfinement.nixosModules.default
    ./nixarr.nix
  ];
}
