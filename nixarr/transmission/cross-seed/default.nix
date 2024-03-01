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
  cross-seedPkg = import ../../../pkgs/cross-seed { inherit (pkgs) stdenv lib fetchFromGitHub; };
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
    systemd.tmpfiles.rules = [
      "d '${cfg.dataDir}' 0700 ${cfg.user} ${cfg.group} - -"
    ];

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
        ExecStart = "${getExe cross-seedPkg} daemon";
        Restart = "on-failure";
      };
    };

    users.users = mkIf (cfg.user == "cross-seed") {
      cross-seed = {
        isSystemUser = true;
        group = cfg.group;
      };
    };

    users.groups = mkIf (cfg.group == "cross-seed") {};
  };
}
