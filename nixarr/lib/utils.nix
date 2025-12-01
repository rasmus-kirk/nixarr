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
    server = config.services.${service}.settings.server;
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

  # Use submodule merge semantics for the fields attribute of *arr config
  # options. This lets us provide partial defaults.
  arrFieldsType = types.submodule {freeformType = arrCfgType;};
in {
  inherit
    arrCfgType
    arrFieldsType
    mkArrLocalUrl
    secretFileType
    toKebabSentenceCase
    ;
}
