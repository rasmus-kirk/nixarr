{
  config,
  pkgs,
  lib,
  ...
}:
with lib; let
  cfg = config.util-nixarr.services.jellyseerr;
in {
  options = {
    util-nixarr.services.jellyseerr = {
      enable = mkEnableOption "Jellyseerr";

      package = mkPackageOption pkgs "jellyseerr" {};

      user = mkOption {
        type = types.str;
        default = "jellyseerr";
        description = "User account under which Jellyseerr runs.";
      };

      group = mkOption {
        type = types.str;
        default = "jellyseerr";
        description = "Group under which Jellyseerr runs.";
      };

      configDir = mkOption {
        type = types.str;
        default = "/var/lib/jellyseerr";
        description = "The directory where Jellyseerr stores its config data.";
      };

      port = lib.mkOption {
        type = lib.types.port;
        default = 5055;
        description = ''The port which the Jellyseerr web UI should listen to.'';
      };

      openFirewall = mkOption {
        type = types.bool;
        default = false;
        description = "Open ports in the firewall for the Jellyseerr web interface.";
      };
    };
  };

  config = mkIf cfg.enable {
    systemd.tmpfiles.rules = [
      "d '${cfg.configDir}' 0700 ${cfg.user} ${cfg.group} - -"
    ];

    systemd.services.jellyseerr = {
      description = "Jellyseerr, a requests manager for Jellyfin";
      after = ["network.target"];
      wantedBy = ["multi-user.target"];
      environment = {
        PORT = toString cfg.port;
        CONFIG_DIRECTORY = cfg.configDir;
      };

      serviceConfig = {
        Type = "exec";
        StateDirectory = "jellyseerr";
        DynamicUser = false;
        User = cfg.user;
        Group = cfg.group;
        ExecStart = lib.getExe cfg.package;
        Restart = "on-failure";
        # ProtectHome = true;
        # ProtectSystem = "strict";
        # PrivateTmp = true;
        # PrivateDevices = true;
        # ProtectHostname = true;
        # ProtectClock = true;
        # ProtectKernelTunables = true;
        # ProtectKernelModules = true;
        # ProtectKernelLogs = true;
        # ProtectControlGroups = true;
        # NoNewPrivileges = true;
        # RestrictRealtime = true;
        # RestrictSUIDSGID = true;
        # RemoveIPC = true;
        # PrivateMounts = true;
      };
    };

    networking.firewall = mkIf cfg.openFirewall {
      allowedTCPPorts = [5055];
    };

    users.users = mkIf (cfg.user == "jellyseerr") {
      jellyseerr = {
        group = cfg.group;
        home = cfg.configDir;
        uid = 294;
      };
    };

    users.groups = mkIf (cfg.group == "jellyseerr") {
      jellyseerr = {};
    };
  };
}
