{
  config,
  lib,
  pkgs,
  ...
}: let
  inherit
    (lib)
    concatMapStringsSep
    filter
    getExe
    isString
    mkOption
    pipe
    split
    toSentenceCase
    types
    ;

  inherit
    (pkgs)
    writeShellApplication
    ;

  mkArrLocalUrl = service: let
    port = config.nixarr.${service}.port;
    urlBase = config.services.${service}.settings.server.urlBase or "";
  in "http://127.0.0.1:${toString port}${urlBase}";

  # Turns `readarr` into `Readarr` and `readarr-audiobook` into
  # `Readarr-Audiobook`.
  toKebabSentenceCase = str:
    pipe str [
      (split "-")
      (filter isString)
      (concatMapStringsSep "-" toSentenceCase)
    ];

  secretFileType = types.submodule {
    options = {
      secret = mkOption {
        type = types.pathWith {
          inStore = false; # Secret files should not be in the Nix store
          absolute = true;
        };
        description = ''
          Path to a file containing a secret value. Must be readable by the
          relevant service user or group!
        '';
      };
    };
  };

  arrCfgType = with types; attrsOf (oneOf [str bool int secretFileType (listOf int) (listOf str)]);

  # Use submodule merge semantics for the fields attribute of *arr config
  # options. This lets us provide partial defaults.
  arrFieldsType = types.submodule {freeformType = arrCfgType;};

  waitForArrService = {
    service,
    max-secs-per-attempt ? 5,
    secs-between-attempts ? 5,
  }: let
    url = mkArrLocalUrl service;
  in
    getExe (writeShellApplication {
      name = "wait-for-${service}";
      runtimeInputs = [pkgs.curl];
      text = ''
        while ! curl \
            --silent \
            --fail \
            --max-time ${toString max-secs-per-attempt} \
            --output /dev/null \
            '${url}'; do
          echo "Waiting for ${service} at '${url}'..."
          sleep ${toString secs-between-attempts}
        done
        echo "${service} is available at '${url}'"
      '';
    });
in {
  inherit
    arrCfgType
    arrFieldsType
    mkArrLocalUrl
    secretFileType
    toKebabSentenceCase
    waitForArrService
    ;
}
