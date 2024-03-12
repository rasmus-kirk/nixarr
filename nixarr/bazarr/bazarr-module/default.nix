{
  config,
  pkgs,
  lib,
  ...
}:
with lib; let
  cfg = config.util-nixarr.services.bazarr;
in {
  options = {
    util-nixarr.services.bazarr = {
      enable = mkEnableOption "bazarr, a subtitle manager for Sonarr and Radarr";

      openFirewall = mkOption {
        type = types.bool;
        default = false;
        description = "Open ports in the firewall for the bazarr web interface.";
      };

      listenPort = mkOption {
        type = types.port;
        default = 6767;
        description = "Port on which the bazarr web interface should listen";
      };

      dataDir = mkOption {
        type = types.path;
        default = "/var/lib/bazarr";
        description = "State directory for bazarr";
      };

      user = mkOption {
        type = types.str;
        default = "bazarr";
        description = "User account under which bazarr runs.";
      };

      group = mkOption {
        type = types.str;
        default = "bazarr";
        description = "Group under which bazarr runs.";
      };
    };
  };

  config = mkIf cfg.enable {
    systemd.tmpfiles.rules = [
      "d '${cfg.dataDir}' 0700 bazarr root - -"
    ];

    systemd.services.bazarr = {
      description = "bazarr";
      after = ["network.target"];
      wantedBy = ["multi-user.target"];

      serviceConfig = {
        Type = "simple";
        User = cfg.user;
        Group = cfg.group;
        SyslogIdentifier = "bazarr";
        ExecStart = pkgs.writeShellScript "start-bazarr" ''
          ${pkgs.bazarr}/bin/bazarr \
            --config '${cfg.dataDir}' \
            --port ${toString cfg.listenPort} \
            --no-update True
        '';
        Restart = "on-failure";
      };
    };

    networking.firewall = mkIf cfg.openFirewall {
      allowedTCPPorts = [cfg.listenPort];
    };

    users.users = mkIf (cfg.user == "bazarr") {
      bazarr = {
        isSystemUser = true;
        group = cfg.group;
      };
    };

    users.groups = mkIf (cfg.group == "bazarr") {
      bazarr = {};
    };
  };
}
