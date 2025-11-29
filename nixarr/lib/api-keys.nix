{
  config,
  lib,
  pkgs,
  ...
}:
with lib; let
  cfg = config.nixarr;

  serviceCfgFile = {
    bazarr = "${cfg.bazarr.stateDir}/config/config.yaml";
    jellyseerr = "${cfg.jellyseerr.stateDir}/settings.json";
    lidarr = "${cfg.lidarr.stateDir}/config.xml";
    prowlarr = "${cfg.prowlarr.stateDir}/config.xml";
    radarr = "${cfg.radarr.stateDir}/config.xml";
    readarr-audiobook = "${cfg.readarr-audiobook.stateDir}/config.xml";
    readarr = "${cfg.readarr.stateDir}/config.xml";
    sabnzbd = "${cfg.sabnzbd.stateDir}/sabnzbd.ini";
    sonarr = "${cfg.sonarr.stateDir}/config.xml";
    transmission = "${cfg.transmission.stateDir}/.config/transmission-daemon/settings.json";
  };

  printServiceApiKey = let
    yq = getExe' pkgs.yq "yq";
    xq = getExe' pkgs.yq "xq";
    grep = getExe pkgs.gnugrep;
    sed = getExe pkgs.gnused;
  in {
    bazarr = pkgs.writeShellScript "print-bazarr-api-key" ''
      ${yq} -r .auth.apiKey '${serviceCfgFile.bazarr}'
    '';
    jellyseerr = pkgs.writeShellScript "print-jellyseerr-api-key" ''
      ${yq} -r .main.apiKey '${serviceCfgFile.jellyseerr}'
    '';
    lidarr = pkgs.writeShellScript "print-lidarr-api-key" ''
      ${xq} -r .Config.ApiKey '${serviceCfgFile.lidarr}'
    '';
    prowlarr = pkgs.writeShellScript "print-prowlarr-api-key" ''
      ${xq} -r .Config.ApiKey '${serviceCfgFile.prowlarr}'
    '';
    radarr = pkgs.writeShellScript "print-radarr-api-key" ''
      ${xq} -r .Config.ApiKey '${serviceCfgFile.radarr}'
    '';
    readarr-audiobook = pkgs.writeShellScript "print-readarr-audiobook-api-key" ''
      ${xq} -r .Config.ApiKey '${serviceCfgFile.readarr-audiobook}'
    '';
    readarr = pkgs.writeShellScript "print-readarr-api-key" ''
      ${xq} -r .Config.ApiKey '${serviceCfgFile.readarr}'
    '';
    sabnzbd = pkgs.writeShellScript "print-sabnzbd-api-key" ''
      ${grep} api_key '${serviceCfgFile.sabnzbd}' | ${sed} 's/^api_key.*= *//g'
    '';
    sonarr = pkgs.writeShellScript "print-sonarr-api-key" ''
      ${xq} -r .Config.ApiKey '${serviceCfgFile.sonarr}'
    '';
    transmission = pkgs.writeShellScript "print-transmission-api-key" ''
      ${yq} -r .["rpc-password"] '${serviceCfgFile.transmission}'
    '';
  };

  servicesWithApiKeys = builtins.attrNames printServiceApiKey;

  # Helper to create API key extraction for a service
  mkApiKeyExtractor = serviceName: {
    description = "Extract ${serviceName} API key";
    after = ["${serviceName}.service"];
    requires = ["${serviceName}.service"];

    serviceConfig = {
      Type = "oneshot";
      RemainAfterExit = true;
      Group = "${serviceName}-api";
      UMask = "0027"; # Results in 0640 permissions

      ExecStartPre = [
        (pkgs.writeShellScript "wait-for-${serviceName}-config" ''
          while [ ! -f '${serviceCfgFile.${serviceName}}' ]; do sleep 1; done
        '')
      ];

      ExecStart = pkgs.writeShellScript "extract-${serviceName}-api-key" ''
        ${printServiceApiKey.${serviceName}} > '${cfg.stateDir}/secrets/${serviceName}.api-key'
      '';
    };
  };
in {
  config = mkIf cfg.enable {
    # Create per-service API key groups
    users.groups = mkMerge (
      builtins.map
      (serviceName: mkIf cfg.${serviceName}.enable {"${serviceName}-api" = {};})
      servicesWithApiKeys
    );

    systemd.services = mkMerge (
      # Create API key extractors for enabled services
      builtins.map
      (serviceName: mkIf cfg.${serviceName}.enable {"${serviceName}-api-key" = mkApiKeyExtractor serviceName;})
      servicesWithApiKeys
    );

    # Create the api-keys directory
    systemd.tmpfiles.rules = [
      # Needs to be world-executable for members of the `*-api` groups to access
      # the files inside.
      "d ${cfg.stateDir}/secrets 0701 root root - -"
    ];
  };
}
