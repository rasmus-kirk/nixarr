# TODO: Dir creation and file permissions in nix
{
  config,
  lib,
  ...
}:
with lib; let
  defaultPort = 9696;
  dnsServers = config.lib.vpn.dnsServers;
  nixarr = config.nixarr;
  cfg = config.nixarr.prowlarr;
in {
  imports = [
    ./prowlarr-module
  ];

  options.nixarr.prowlarr = {
    enable = mkEnableOption "Enable the Prowlarr service.";

    stateDir = mkOption {
      type = types.path;
      default = "${nixarr.stateDir}/nixarr/prowlarr";
      description = "The state directory for Prowlarr.";
    };

    vpn.enable = mkEnableOption ''
      **Required options:** [`nixarr.vpn.enable`](/options.html#nixarr.vpn.enable)

      Route Prowlarr traffic through the VPN.
    '';
  };

  config = mkIf cfg.enable {
    systemd.tmpfiles.rules = [
      "d '${cfg.stateDir}' 0700 prowlarr root - -"
    ];

    util-nixarr.services.prowlarr = mkIf (!cfg.vpn.enable) {
      enable = true;
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

    systemd.services."container@prowlarr" = mkIf cfg.vpn.enable {
      requires = ["wg.service"];
    };

    containers.prowlarr = mkIf cfg.vpn.enable {
      autoStart = true;
      ephemeral = true;
      extraFlags = ["--network-namespace-path=/var/run/netns/wg"];
      bindMounts."${cfg.stateDir}".isReadOnly = false;

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

        util-nixarr.services.prowlarr = {
          enable = true;
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
