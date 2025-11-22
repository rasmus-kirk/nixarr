{
  config,
  lib,
  ...
}: let
  inherit
    (lib)
    types
    mkOption
    pipe
    split
    filter
    isString
    concatMapStringsSep
    toSentenceCase
    ;

  mkArrLocalUrl = service: let
    server =
      if (config ? services && config.services ? ${service} && config.services.${service} ? settings && config.services.${service}.settings ? server)
      then config.services.${service}.settings.server
      else {port = 0;};
  in "http://127.0.0.1:${toString server.port}${server.urlBase or ""}";

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
in {
  inherit
    mkArrLocalUrl
    toKebabSentenceCase
    secretFileType
    arrCfgType
    ;
}
