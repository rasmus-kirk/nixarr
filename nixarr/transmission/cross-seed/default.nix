{
  config,
  pkgs,
  lib,
  ...
}:
with lib; let
  cfg = config.util-nixarr.services.cross-seed;
  settingsFormat = pkgs.formats.json {};
  settingsFile = settingsFormat.generate "settings.json" cfg.settings;
  cross-seedPkg = pkgs.callPackage ../../../pkgs/cross-seed {};
  configJs = pkgs.writeText "config.js" ''
    // Loads a json.config
    "use strict";
    const fs = require('fs');

    const jsonPath = '${cfg.dataDir}/config.json'

    // Synchronously read the JSON-configuration file
    const configFileContent = fs.readFileSync(jsonPath, { encoding: 'utf8' });

    // Parse the JSON content into a JavaScript object
    let config = JSON.parse(configFileContent);

    // Function to recursively replace null values with undefined
    /*
    function replaceNullWithUndefined(obj) {
      Object.keys(obj).forEach(key => {
        if (obj[key] === null) {
          obj[key] = undefined;
        } else if (typeof obj[key] === 'object') {
          replaceNullWithUndefined(obj[key]);
        }
      });
    }
    replaceNullWithUndefined(config);
    */

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
        description = "cross-seed config"; # TODO: todo
      };

      dataDir = mkOption {
        type = types.path;
        default = "/var/lib/cross-seed";
        description = "cross-seed dataDir"; # TODO: todo
      };

      credentialsFile = mkOption {
        type = types.path;
        default = "/run/secrets/cross-seed/credentialsFile.json";
        description = "cross-seed dataDir"; # TODO: todo
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
          The settings.outputDir must be set if cross-seed is enabled.
        '';
      }
    ];

    systemd.tmpfiles.rules = [
      "L+ '${cfg.dataDir}'/config.js - - - - ${configJs}"
      "d '${cfg.dataDir}' 0700 ${cfg.user} ${cfg.group} - -"
    ] ++ (
      if cfg.settings.outputDir != null then
        [ "d '${cfg.settings.outputDir}' 0755 ${cfg.user} ${cfg.group} - -" ]
      else []
    );

    systemd.services.cross-seed = {
      description = "cross-seed";
      after = ["network.target"];
      wantedBy = ["multi-user.target"];

      environment.CONFIG_DIR = cfg.dataDir;

      serviceConfig = {
        # Run as root in case that the cfg.credentialsFile is not readable by cross-seed
        ExecStartPre = [("+" + pkgs.writeShellScript "transmission-prestart" ''
          ${pkgs.jq}/bin/jq --slurp add ${settingsFile} '${cfg.credentialsFile}' |
          install -D -m 600 -o '${cfg.user}' /dev/stdin '${cfg.dataDir}/config.json'
        ''
        )];
        Type = "simple";
        User = cfg.user;
        Group = cfg.group;
        ExecStart = "${cross-seedPkg}/bin/cross-seed daemon";
        Restart = "on-failure";
      };
    };

    users.users = mkIf (cfg.user == "cross-seed") {
      cross-seed = {
        isSystemUser = true;
        group = cfg.group;
      };
    };

    users.groups = mkIf (cfg.group == "cross-seed") {
      cross-seed = { };
    };
  };
}
