{
  config,
  lib,
  pkgs,
  ...
}:
with lib; let
  cfg = config.nixarr;

  # Helper to create API key extraction for a service
  mkApiKeyExtractor = serviceName: serviceConfig: {
    description = "Extract ${serviceName} API key";
    after = ["${serviceName}.service"];
    requires = ["${serviceName}.service"];

    serviceConfig = {
      Type = "oneshot";
      RemainAfterExit = true;
      # Use DynamicUser if the parent service does
      DynamicUser = serviceConfig.serviceConfig.DynamicUser or false;
      # Only set User if not using DynamicUser
      ${
        if !(serviceConfig.serviceConfig.DynamicUser or false)
        then "User"
        else null
      } =
        serviceConfig.user or null;
      Group = "${serviceName}-api";
      UMask = "0027"; # Results in 0640 permissions

      ExecStartPre = [
        "${pkgs.coreutils}/bin/mkdir -p ${cfg.stateDir}/api-keys"
        "${pkgs.coreutils}/bin/chown root:${serviceName}-api ${cfg.stateDir}/api-keys"
        "${pkgs.coreutils}/bin/chmod 750 ${cfg.stateDir}/api-keys"
        # Wait for config file to exist
        "${pkgs.bash}/bin/bash -c 'while [ ! -f ${serviceConfig.stateDir}/config.xml ]; do sleep 1; done'"
      ];

      ExecStart = pkgs.writeShellScript "extract-${serviceName}-api-key" ''
        ${pkgs.dasel}/bin/dasel -f "${serviceConfig.stateDir}/config.xml" \
          -s ".Config.ApiKey" | tr -d '\n\r' > "${cfg.stateDir}/api-keys/${serviceName}.key"
        chown $USER:${serviceName}-api "${cfg.stateDir}/api-keys/${serviceName}.key"
      '';
    };
  };
in {
  config = mkIf cfg.enable {
    # Create per-service API key groups
    users.groups = mkMerge [
      (mkIf cfg.sonarr.enable {sonarr-api = {};})
      (mkIf cfg.radarr.enable {radarr-api = {};})
      (mkIf cfg.lidarr.enable {lidarr-api = {};})
      (mkIf cfg.readarr.enable {readarr-api = {};})
      (mkIf cfg.prowlarr.enable {prowlarr-api = {};})
    ];

    # Add services that need API keys to their respective groups
    users.users = mkMerge [
      # Static users
      (mkIf cfg.transmission.enable {
        transmission.extraGroups = optional cfg.prowlarr.enable "prowlarr-api";
      })
      (mkIf cfg.transmission.privateTrackers.cross-seed.enable {
        cross-seed.extraGroups = optional cfg.prowlarr.enable "prowlarr-api";
      })
    ];

    # Add api groups to services with DynamicUser
    systemd.services = mkMerge [
      (mkIf cfg.sonarr.enable {sonarr.serviceConfig.SupplementaryGroups = ["sonarr-api"];})
      (mkIf cfg.radarr.enable {radarr.serviceConfig.SupplementaryGroups = ["radarr-api"];})
      (mkIf cfg.lidarr.enable {lidarr.serviceConfig.SupplementaryGroups = ["lidarr-api"];})
      (mkIf cfg.readarr.enable {readarr.serviceConfig.SupplementaryGroups = ["readarr-api"];})
      (mkIf cfg.prowlarr.enable {prowlarr.serviceConfig.SupplementaryGroups = ["prowlarr-api"];})
      (mkIf cfg.recyclarr.enable {
        recyclarr.serviceConfig.SupplementaryGroups =
          (optional cfg.sonarr.enable "sonarr-api")
          ++ (optional cfg.radarr.enable "radarr-api");
      })

      # Create API key extractors for enabled services
      (mkIf cfg.sonarr.enable {"sonarr-api-key" = mkApiKeyExtractor "sonarr" cfg.sonarr;})
      (mkIf cfg.radarr.enable {"radarr-api-key" = mkApiKeyExtractor "radarr" cfg.radarr;})
      (mkIf cfg.lidarr.enable {"lidarr-api-key" = mkApiKeyExtractor "lidarr" cfg.lidarr;})
      (mkIf cfg.readarr.enable {"readarr-api-key" = mkApiKeyExtractor "readarr" cfg.readarr;})
      (mkIf cfg.prowlarr.enable {"prowlarr-api-key" = mkApiKeyExtractor "prowlarr" cfg.prowlarr;})
    ];

    # Create the api-keys directory
    systemd.tmpfiles.rules = [
      "d ${cfg.stateDir}/api-keys 0750 root root - -"
    ];
  };
}
