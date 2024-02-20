# TODO: Dir creation and file permissions in nix
{
  pkgs,
  config,
  lib,
  ...
}:
with lib; let
  cfg = config.kirk.servarr.radarr;
  defaultPort = 7878;
  servarr = config.kirk.servarr;
  dnsServers = config.kirk.vpnnamespace.dnsServers;
in {
  options.kirk.servarr.radarr = {
    enable = mkOption {
      type = types.bool;
      default = false;
      description = lib.mdDoc "Enable radarr";
    };

    stateDir = mkOption {
      type = types.path;
      default = "${servarr.stateDir}/servarr/radarr";
      description = lib.mdDoc "The state directory for radarr";
    };

    useVpn = mkOption {
      type = types.bool;
      default = false;
      description = lib.mdDoc "Use VPN with radarr";
    };
  };

  config = mkIf cfg.enable {
    services.radarr = mkIf (!cfg.useVpn) {
      enable = cfg.enable;
      user = "radarr";
      group = "media";
      dataDir = cfg.stateDir;
    };

    kirk.vpnnamespace.portMappings = [
      (
        mkIf cfg.useVpn {
          From = defaultPort;
          To = defaultPort;
        }
      )
    ];

    containers.radarr = mkIf cfg.useVpn {
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
        users.users.radarr = {
          uid = lib.mkForce config.users.users.radarr.uid;
          isSystemUser = true;
          group = "media";
        };

        # Use systemd-resolved inside the container
        # Workaround for bug https://github.com/NixOS/nixpkgs/issues/162686
        networking.useHostResolvConf = lib.mkForce false;
        services.resolved.enable = true;
        networking.nameservers = dnsServers;

        services.radarr = {
          enable = true;
          group = "media";
          dataDir = cfg.stateDir;
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
