{
  config,
  pkgs,
  lib,
  ...
}:
with lib; let
  cfg = config.util-nixarr.services.cross-seed;
  globals = config.util-nixarr.globals;
  settingsFormat = pkgs.formats.json {};
  settingsFile = settingsFormat.generate "settings.json" cfg.settings;
  configJs = pkgs.writeText "config.js" ''
    // Loads a json.config
    "use strict";
    const fs = require('fs');

    const jsonPath = '${cfg.dataDir}/config.json'

    // Synchronously read the JSON-configuration file
    const configFileContent = fs.readFileSync(jsonPath, { encoding: 'utf8' });

    // Parse the JSON content into a JavaScript object
    let config = JSON.parse(configFileContent);

    // Export the configuration object
    module.exports = config;
  '';
in {
  options = {
    util-nixarr.services.cross-seed = {
      enable = mkEnableOption "cross-seed";

      settings = mkOption {
        type = types.attrs;
        default = {};
        example = ''
          {
            delay = 10;
          }
        '';
        description = "Settings for cross-seed";
      };

      dataDir = mkOption {
        type = types.path;
        default = "/var/lib/cross-seed";
        description = "The cross-seed dataDir";
      };

      credentialsFile = mkOption {
        type = types.path;
        default = "/run/secrets/cross-seed/credentialsFile.json";
        description = "Secret options to be merged into the cross-seed config";
      };

      user = mkOption {
        type = types.str;
        default = "cross-seed";
        description = "User account under which cross-seed runs.";
      };

      group = mkOption {
        type = types.str;
        default = "cross-seed";
        description = "Group under which cross-seed runs.";
      };
    };
  };

  config = mkIf cfg.enable {
    assertions = [
      {
        assertion = cfg.enable -> cfg.settings.outputDir != null;
        message = ''
          The settings.outputDir option must be set if cross-seed is enabled.
        '';
      }
      {
        assertion = cfg.enable -> cfg.settings.torrentDir != null;
        message = ''
          The settings.torrentDir option must be set if cross-seed is enabled.
        '';
      }
    ];

    systemd.tmpfiles.rules =
      [
        "d '${cfg.dataDir}' 0700 ${cfg.user} root - -"
      ]
      ++ (
        if cfg.settings.outputDir != null
        then ["d '${cfg.settings.outputDir}' 0755 ${cfg.user} ${cfg.group} - -"]
        else []
      );

    systemd.services.cross-seed = {
      description = "cross-seed";
      after = ["network.target"];
      wantedBy = ["multi-user.target"];

      environment.CONFIG_DIR = cfg.dataDir;

      serviceConfig = {
        # Run as root in case that the cfg.credentialsFile is not readable by cross-seed
        ExecStartPre = [
          (
            "+"
            + pkgs.writeShellScript "transmission-prestart" ''
              ${pkgs.jq}/bin/jq --slurp add ${settingsFile} '${cfg.credentialsFile}' |
              install -D -m 600 -o '${cfg.user}' /dev/stdin '${cfg.dataDir}/config.json'

              cp "${configJs}" "${cfg.dataDir}/config.js"
              chmod 600 "${cfg.dataDir}/config.js"
              chown "${cfg.user}:${cfg.group}" "${cfg.dataDir}/config.js"
            ''
          )
        ];
        Type = "simple";
        User = cfg.user;
        Group = cfg.group;
        ExecStart = "${pkgs.cross-seed}/bin/cross-seed daemon";
        Restart = "on-failure";
      };
    };

    users = {
      groups.${cfg.group}.gid = globals.gids.${cfg.group};
      users.${cfg.user} = {
        isSystemUser = true;
        group = cfg.group;
        uid = globals.uids.${cfg.user};
      };
    };
  };
}
