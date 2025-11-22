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
    jellyfin = "${cfg.jellyfin.stateDir}/config/system.xml";
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
    jellyfin = let
      sqlite = getExe pkgs.sqlite;
    in pkgs.writeShellScript "print-jellyfin-api-key" ''
      DB_PATH="${cfg.jellyfin.stateDir}/data/data/jellyfin.db"
      
      # Wait for database file to exist AND be readable
      # We check that the file exists and has non-zero size to ensure Jellyfin created it
      RETRIES=60
      while [ $RETRIES -gt 0 ]; do
        if [ -f "$DB_PATH" ] && [ -s "$DB_PATH" ]; then
          break
        fi
        sleep 1
        RETRIES=$((RETRIES - 1))
      done
      
      if [ ! -f "$DB_PATH" ] || [ ! -s "$DB_PATH" ]; then
        echo "Database file not found or empty: $DB_PATH" >&2
        exit 1
      fi
      
      # Wait for database to be initialized with ApiKeys table
      # Use -readonly mode to prevent sqlite from creating the DB if it somehow doesn't exist
      RETRIES=60
      while [ $RETRIES -gt 0 ]; do
        # Try to query the ApiKeys table in read-only mode
        if ${sqlite} -readonly "$DB_PATH" "SELECT COUNT(*) FROM ApiKeys;" >/dev/null 2>&1; then
          break
        fi
        sleep 1
        RETRIES=$((RETRIES - 1))
      done
      
      if [ $RETRIES -eq 0 ]; then
        echo "Database not initialized or ApiKeys table not found" >&2
        exit 1
      fi
      
      # Check if an API key already exists
      EXISTING_KEY=$(${sqlite} "$DB_PATH" "SELECT AccessToken FROM ApiKeys WHERE Name = 'Nixarr' LIMIT 1;" 2>/dev/null || echo "")
      
      if [ -n "$EXISTING_KEY" ]; then
        echo "$EXISTING_KEY"
        exit 0
      fi
      
      # Generate a new API key
      API_KEY=$(head -c 32 /dev/urandom | base64 | tr -d '/+=' | head -c 32)
      TIMESTAMP=$(date -u +"%Y-%m-%d %H:%M:%S")
      
      # Insert the API key into the database
      ${sqlite} "$DB_PATH" "INSERT INTO ApiKeys (DateCreated, DateLastActivity, Name, AccessToken) VALUES ('$TIMESTAMP', '$TIMESTAMP', 'Nixarr', '$API_KEY');"
      
      echo "$API_KEY"
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
        ${printServiceApiKey.${serviceName}} > '${cfg.stateDir}/api-keys/${serviceName}.key'
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
      "d ${cfg.stateDir}/api-keys 0701 root root - -"
    ];
  };
}
