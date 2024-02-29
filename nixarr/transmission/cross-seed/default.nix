{
  config,
  pkgs,
  lib,
  ...
}:
with lib; let
  cfg = config.util-nixarr.services.prowlarr;
  #settingsFormat = pkgs.formats.json {};
  #settingsFile = settingsFormat.generate "settings.json" cfg.settings;
  cross-seedPkg = import ../../../pkgs/cross-seed { inherit (pkgs) stdenv lib fetchFromGitHub; };
in {
  options = {
    util-nixarr.services.prowlarr = {
      enable = mkEnableOption "cross-seed";

      configFile = mkOption {
        type = with types; nullOr path;
        default = null;
        example = "/var/lib/secrets/cross-seed/settings.js";
        description = "";
      };

      dataDir = mkOption {
        type = types.path;
        default = "/var/lib/cross-seed";
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

    systemd.services.prowlarr = {
      description = "cross-seed";
      after = ["network.target"];
      wantedBy = ["multi-user.target"];

      environment.CONFIG_DIR = cfg.dataDir;

      serviceConfig = {
        ExecStartPre = [("+" + pkgs.writeShellScript "transmission-prestart" ''
          mv ${cfg.configFile} ${cfg.dataDir}
        '')];
        Type = "simple";
        User = cfg.user;
        Group = cfg.group;
        ExecStart = "${getExe cross-seedPkg} daemon";
        Restart = "on-failure";
      };
    };

    users.users = mkIf (cfg.user == "cross-seed") {
      cross-seed = {
        group = cfg.group;
      };
    };

    users.groups = mkIf (cfg.group == "cross-seed") {};
  };
}
