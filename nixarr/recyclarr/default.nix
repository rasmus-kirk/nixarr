{
  config,
  lib,
  pkgs,
  inputs,
  ...
}:
with lib; let
  cfg = config.nixarr.recyclarr;
  nixarr = config.nixarr;
  format = pkgs.formats.yaml {};

  # Generate configuration file from Nix attribute set if provided
  generatedConfigFile = format.generate "recyclarr-config.yml" cfg.configuration;

  # Determine which config file to use
  effectiveConfigFile =
    if cfg.configFile != null
    then cfg.configFile
    else generatedConfigFile;
in {
  options.nixarr.recyclarr = {
    enable = mkOption {
      type = types.bool;
      default = false;
      example = true;
      description = ''
        Whether or not to enable the Recyclarr service. This service does not need to be run behind a VPN.
      '';
    };

    package = mkPackageOption pkgs "recyclarr" {};

    schedule = lib.mkOption {
      type = lib.types.str;
      default = "daily";
      description = "When to run recyclarr in systemd calendar format.";
    };

    stateDir = mkOption {
      type = types.path;
      default = "${nixarr.stateDir}/recyclarr";
      defaultText = literalExpression ''"''${nixarr.stateDir}/recyclarr"'';
      example = "/nixarr/.state/recyclarr";
      description = "The location of the state directory for the Recyclarr service.";
    };

    configFile = mkOption {
      type = types.nullOr types.path;
      default = null;
      description = ''
        Path to the recyclarr YAML configuration file. See [Recyclarr's
        documentation](https://recyclarr.dev/wiki/yaml/config-reference)
        for more information.

        The API keys for Radarr and Sonarr can be referenced in the config
        file using the `RADARR_API_KEY` and `SONARR_API_KEY` environment
        variables (with macro `!env_var`).

        Note: You cannot set both `configFile` and `configuration` options.
      '';
      example = "./recyclarr.yaml";
    };

    configuration = mkOption {
      type = types.nullOr format.type;
      default = null;
      example = literalExpression ''
        {
          sonarr = {
            series = {
              base_url = "http://localhost:8989";
              api_key = "!env_var SONARR_API_KEY";
              quality_definition = {
                type = "series";
              };
              delete_old_custom_formats = true;
              custom_formats = [
                {
                  trash_ids = [
                    "85c61753df5da1fb2aab6f2a47426b09" # BR-DISK
                    "9c11cd3f07101cdba90a2d81cf0e56b4" # LQ
                  ];
                  assign_scores_to = [
                    {
                      name = "WEB-DL (1080p)";
                      score = -10000;
                    }
                  ];
                }
              ];
            };
          };
          radarr = {
            movies = {
              base_url = "http://localhost:7878";
              api_key = "!env_var RADARR_API_KEY";
              quality_definition = {
                type = "movie";
              };
              delete_old_custom_formats = true;
              custom_formats = [
                {
                  trash_ids = [
                    "570bc9ebecd92723d2d21500f4be314c" # Remaster
                    "eca37840c13c6ef2dd0262b141a5482f" # 4K Remaster
                  ];
                  assign_scores_to = [
                    {
                      name = "HD Bluray + WEB";
                      score = 25;
                    }
                  ];
                }
              ];
            };
          };
        }
      '';
      description = ''
        Recyclarr YAML configuration as a Nix attribute set. For detailed configuration options and examples,
        see the [official configuration reference](https://recyclarr.dev/wiki/yaml/config-reference/).

        The API keys for Radarr and Sonarr can be referenced using the `RADARR_API_KEY` and `SONARR_API_KEY`
        environment variables (with the string "!env_var RADARR_API_KEY").

        Note: You cannot set both `configFile` and `configuration` options.
      '';
    };
  };

  config = mkIf (nixarr.enable && cfg.enable) {
    assertions = [
      {
        assertion = cfg.enable -> (nixarr.radarr.enable || nixarr.sonarr.enable);
        message = ''
          The nixarr.recyclarr.enable option requires at least one of nixarr.radarr.enable
          or nixarr.sonarr.enable to be set, but neither was enabled.
        '';
      }
      {
        assertion = !(cfg.configFile != null && cfg.configuration != null);
        message = ''
          You cannot set both nixarr.recyclarr.configFile and nixarr.recyclarr.configuration.
          Please choose one method to configure Recyclarr.
        '';
      }
      {
        assertion = cfg.configFile != null || cfg.configuration != null;
        message = ''
          You must set either nixarr.recyclarr.configFile or nixarr.recyclarr.configuration.
        '';
      }
    ];

    services.recyclarr = {
      enable = true;
      package = cfg.package;
      schedule = cfg.schedule;
    };

    systemd.services.recyclarr = let
      apiKeyDeps =
        (optional nixarr.radarr.enable "radarr-api-key.service")
        ++ (optional nixarr.sonarr.enable "sonarr-api-key.service");
    in {
      after = apiKeyDeps;
      requires = apiKeyDeps;

      serviceConfig = {
        ExecStart = lib.mkForce (pkgs.writeShellScript "recyclarr-wrapper" ''
          ${optionalString nixarr.radarr.enable ''
            export RADARR_API_KEY=$(cat "${nixarr.stateDir}/api-keys/radarr.key")
          ''}
          ${optionalString nixarr.sonarr.enable ''
            export SONARR_API_KEY=$(cat "${nixarr.stateDir}/api-keys/sonarr.key")
          ''}
          exec ${lib.getExe cfg.package} sync --app-data ${cfg.stateDir} --config ${effectiveConfigFile}
        '');
        SupplementaryGroups =
          (optional nixarr.radarr.enable "radarr-api")
          ++ (optional nixarr.sonarr.enable "sonarr-api");
        ReadWritePaths = [cfg.stateDir];
      };
    };

    systemd.tmpfiles.rules = [
      "d '${cfg.stateDir}' 0750 ${config.services.recyclarr.user} root - -"
    ];
  };
}
