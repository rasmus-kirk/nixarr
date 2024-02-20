# TODO: Dir creation and file permissions in nix
{
  pkgs,
  config,
  lib,
  ...
}:
with lib; let
  defaultPort = 9696;
  dnsServers = config.lib.vpn.dnsServers;
  servarr = config.servarr;
  cfg = config.servarr.prowlarr;
in {
  options.servarr.prowlarr = {
    enable = mkOption {
      type = types.bool;
      default = false;
      description = lib.mdDoc "Enable prowlarr";
    };

    stateDir = mkOption {
      type = types.path;
      default = "${servarr.stateDir}/servarr/prowlarr";
      description = lib.mdDoc ''
        The state directory for prowlarr. Currently doesn't work, except with VPN.
      '';
    };

    useVpn = mkOption {
      type = types.bool;
      default = false;
      description = lib.mdDoc "Use VPN with prowlarr";
    };
  };

  config = mkIf cfg.enable {
    services.prowlarr = mkIf (!cfg.useVpn) {
      enable = true;
      openFirewall = true;
    };

    util.vpnnamespace.portMappings = [
      (
        mkIf cfg.useVpn {
          From = defaultPort;
          To = defaultPort;
        }
      )
    ];

    containers.prowlarr = mkIf cfg.useVpn {
      autoStart = true;
      ephemeral = true;
      extraFlags = ["--network-namespace-path=/var/run/netns/wg"];

      bindMounts = {
        "/var/lib/prowlarr" = {
          hostPath = cfg.stateDir;
          isReadOnly = false;
        };
      };

      config = {
        users.groups.prowlarr = {};
        users.users.prowlarr = {
          uid = lib.mkForce config.users.users.prowlarr.uid;
          isSystemUser = true;
          group = "prowlarr";
        };

        # Use systemd-resolved inside the container
        # Workaround for bug https://github.com/NixOS/nixpkgs/issues/162686
        networking.useHostResolvConf = lib.mkForce false;
        services.resolved.enable = true;
        networking.nameservers = dnsServers;

        services.prowlarr = {
          enable = true;
          openFirewall = true;
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
