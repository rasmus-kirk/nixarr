{
  config,
  lib,
  pkgs,
  ...
}: let
  inherit
    (lib)
    genAttrs
    literalExpression
    mkIf
    mkOption
    types
    ;

  inherit
    (pkgs.writers)
    writeJSON
    ;

  nixarr-utils = import ../utils.nix {inherit config lib pkgs;};
  inherit
    (nixarr-utils)
    arrServiceNames
    mkArrLocalUrl
    ;

  cfg = config.nixarr;

  nixarr-py-config = genAttrs arrServiceNames (serviceName: {
    base_url = mkArrLocalUrl serviceName;
    api_key_file = "${cfg.stateDir}/secrets/${serviceName}.api-key";
  });

  nixarr-py-json = writeJSON "nixarr-py.json" nixarr-py-config;

  package = pkgs.callPackage ./. {};
in {
  options.nixarr.nixarr-py = {
    package = mkOption {
      type = types.package;
      default = package;
      defaultText = literalExpression "pkgs.callPackage ./. {}";
      description = "The nixarr-py package.";
    };
  };

  config = mkIf cfg.enable {
    environment.etc."nixarr/nixarr-py.json".source = nixarr-py-json;
  };
}
