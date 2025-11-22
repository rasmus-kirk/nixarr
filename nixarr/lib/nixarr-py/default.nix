{
  config,
  lib,
  pkgs,
  ...
}: let
  inherit
    (lib)
    concatStringsSep
    map
    pipe
    replaceString
    ;

  utils = import ../utils.nix {inherit config lib pkgs;};

  inherit
    (utils)
    toKebabSentenceCase
    mkArrLocalUrl
    ;

  mkClientPySrc = {
    service,
    app ? service,
  }: let
    service-Kebab = toKebabSentenceCase service;
    service_snake = replaceString "-" "_" service;
  in ''
    import ${app}

    def ${service_snake}_client() -> ${app}.ApiClient:
        """Create a ${service-Kebab} API client configured for use with Nixarr.

        Returns:
            ${app}.ApiClient: API client instance configured to connect to
            the local Nixarr ${service-Kebab} service.

        Example:
            >>> import ${app}
            >>> from nixarr.clients import ${service_snake}_client
            >>>
            >>> with ${service_snake}_client() as client:
            ...     api_info_client = ${app}.ApiInfoApi(client)
            ...     api_info = api_info_client.get_api()
        """
        with open(
          "${config.nixarr.stateDir}/api-keys/${service}.key",
          "r", encoding="utf-8"
        ) as f:
            api_key = f.read().strip()

        configuration = ${app}.Configuration(
            host="${mkArrLocalUrl service}",
            api_key={"X-Api-Key": api_key},
        )

        return ${app}.ApiClient(configuration)
  '';

  clientsPySrc = let
    args = [
      {service = "lidarr";}
      {service = "prowlarr";}
      {service = "radarr";}
      {service = "sonarr";}
      # These are blocked on https://github.com/rasmus-kirk/nixarr/pull/98
      # {service = "readarr";}
      # {
      #   service = "readarr-audiobook";
      #   app = "readarr";
      # }
    ];
    text = pipe args [
      (map mkClientPySrc)
      (concatStringsSep "\n")
    ];
  in
    pkgs.writeTextDir "nixarr/clients.py" text;

  nixarr-py = let
    inherit (pkgs.python3Packages) buildPythonPackage setuptools;
  in
    buildPythonPackage {
      pname = "nixarr";
      version = "0.1.0";
      pyproject = true;

      src = pkgs.symlinkJoin {
        name = "nixarr-py-src";
        paths = [
          ./.
          clientsPySrc
        ];
      };
      build-system = [setuptools];
      dependencies = pkgs.callPackage ./python-deps.nix {};
    };
in
  nixarr-py
