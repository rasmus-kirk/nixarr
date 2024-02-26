# TODO: Dir creation and file permissions in nix
{
  config,
  lib,
  ...
}:
with lib; let
  cfg = config.nixarr.radarr;
  defaultPort = 7878;
  nixarr = config.nixarr;
  dnsServers = config.lib.vpn.dnsServers;
in {
  options.nixarr.radarr = {
    enable = mkEnableOption "Enable the Radarr service.";

    stateDir = mkOption {
      type = types.path;
      default = "${nixarr.stateDir}/nixarr/radarr";
      description = "The state directory for radarr.";
    };

    vpn.enable = mkEnableOption ''
      **Required options:** [`nixarr.vpn.enable`](/options.html#nixarr.vpn.enable)

      Route Radarr traffic through the VPN.
    '';
  };

  config = mkIf cfg.enable {
    systemd.tmpfiles.rules = [
      "d '${cfg.stateDir}' 0700 radarr root - -"
    ];

    services.radarr = mkIf (!cfg.vpn.enable) {
      enable = cfg.enable;
      user = "radarr";
      group = "media";
      dataDir = cfg.stateDir;
    };

    util-nixarr.vpnnamespace.portMappings = [
      (
        mkIf cfg.vpn.enable {
          From = defaultPort;
          To = defaultPort;
        }
      )
    ];

    systemd.services."container@radarr" = mkIf cfg.vpn.enable {
      requires = ["wg.service"];
    };

    containers.radarr = mkIf cfg.vpn.enable {
      autoStart = true;
      ephemeral = true;
      extraFlags = ["--network-namespace-path=/var/run/netns/wg"];

      bindMounts = {
        "${nixarr.mediaDir}".isReadOnly = false;
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

    services.nginx = mkIf cfg.vpn.enable {
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
