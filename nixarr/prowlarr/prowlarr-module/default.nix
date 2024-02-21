{ config, pkgs, lib, ... }:

with lib;

let
  cfg = config.util.services.prowlarr;
in
{
  options = {
    util.services.prowlarr = {
      enable = mkEnableOption "Prowlarr";

      package = mkPackageOption pkgs "prowlarr" { };

      user = mkOption {
        type = types.str;
        default = "prowlarr";
        description = "User account under which Prowlarr runs.";
      };

      group = mkOption {
        type = types.str;
        default = "prowlarr";
        description = "Group under which Prowlarr runs.";
      };

      dataDir = mkOption {
        type = types.str;
        default = "/var/lib/prowlarr";
        description = "The directory where Prowlarr stores its data files.";
      };

      openFirewall = mkOption {
        type = types.bool;
        default = false;
        description = "Open ports in the firewall for the Prowlarr web interface.";
      };
    };
  };

  config = mkIf cfg.enable {
    systemd.tmpfiles.rules = [
      "d '${cfg.dataDir}' 0700 ${cfg.user} ${cfg.group} - -"
    ];

    systemd.services.prowlarr = {
      description = "Prowlarr";
      after = [ "network.target" ];
      wantedBy = [ "multi-user.target" ];

      serviceConfig = {
        Type = "simple";
        User = cfg.user;
        Group = cfg.group;
        ExecStart = "${lib.getExe cfg.package} -nobrowser -data=${cfg.dataDir}";
        Restart = "on-failure";
      };
    };

    networking.firewall = mkIf cfg.openFirewall {
      allowedTCPPorts = [ 9696 ];
    };

    users.users = mkIf (cfg.user == "prowlarr") {
      prowlarr = {
        group = cfg.group;
        home = cfg.dataDir;
        uid = 293;
      };
    };

    users.groups = mkIf (cfg.group == "prowlarr") {};
  };
}
