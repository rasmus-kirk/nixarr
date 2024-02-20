{
  config,
  lib,
  ...
}:
with lib; let
  cfg = config.servarr.lidarr;
  dnsServers = config.lib.vpn.dnsServers;
  servarr = config.servarr;
in {
  options.servarr.lidarr = {
    enable = mkOption {
      type = types.bool;
      default = false;
      description = lib.mdDoc "Enable lidarr";
    };

    stateDir = mkOption {
      type = types.path;
      default = "${servarr.stateDir}/servarr/lidarr";
      description = lib.mdDoc "The state directory for lidarr";
    };

    useVpn = mkOption {
      type = types.bool;
      default = false;
      description = lib.mdDoc "Use VPN with prowlarr";
    };
  };

  config = mkIf cfg.enable {
    services.lidarr = {
      enable = cfg.enable;
      user = "lidarr";
      group = "media";
      dataDir = cfg.stateDir;
    };

    util.vpnnamespace.portMappings = [
      (
        mkIf cfg.useVpn {
          From = defaultPort;
          To = defaultPort;
        }
      )
    ];

    containers.lidarr = mkIf cfg.useVpn {
      autoStart = true;
      ephemeral = true;
      extraFlags = ["--network-namespace-path=/var/run/netns/wg"];

      bindMounts = {
        "${servarr.mediaDir}".isReadOnly = false;
        "${cfg.stateDir}".isReadOnly = false;
      };

      config = {
        users.groups.media = {
          gid = config.users.groups.media.gid;
        };
        users.users.lidarr = {
          uid = lib.mkForce config.users.users.lidarr.uid;
          isSystemUser = true;
          group = "media";
        };

        # Use systemd-resolved inside the container
        # Workaround for bug https://github.com/NixOS/nixpkgs/issues/162686
        networking.useHostResolvConf = lib.mkForce false;
        services.resolved.enable = true;
        networking.nameservers = dnsServers;

        services.lidarr = {
          enable = true;
          group = "media";
          dataDir = "${cfg.stateDir}";
        };

        system.stateVersion = "23.11";
      };
    };

    services.nginx = mkIf cfg.useVpn {
      enable = true;

      recommendedTlsSettings = true;
      recommendedOptimisation = true;
      recommendedGzipSettings = true;

      virtualHosts."127.0.0.1:${builtins.toString defaultPort}" = {
        listen = [
          {
            addr = "0.0.0.0";
            port = defaultPort;
          }
        ];
        locations."/" = {
          recommendedProxySettings = true;
          proxyWebsockets = true;
          proxyPass = "http://192.168.15.1:${builtins.toString defaultPort}";
        };
      };
    };
  };
}
