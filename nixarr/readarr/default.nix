{
  config,
  lib,
  ...
}:
with lib; let
  cfg = config.nixarr.readarr;
  nixarr = config.nixarr;
  dnsServers = config.lib.vpn.dnsServers;
in {
  options.nixarr.readarr = {
    enable = mkEnableOption "Enable the Readarr service";

    stateDir = mkOption {
      type = types.path;
      default = "${nixarr.stateDir}/nixarr/readarr";
      description = "The state directory for Readarr";
    };

    vpn.enable = mkOption {
      type = types.bool;
      default = false;
      description = ''
        **Required options:** [`nixarr.vpn.enable`](#nixarr.vpn.enable)

        Route Readarr traffic through the VPN.
      '';
    };
  };

  config = mkIf cfg.enable {
    assertions = [
      {
        assertion = cfg.vpn.enable -> nixarr.vpn.enable;
        message = ''
          The nixarr.readarr.vpn.enable option requires the
          nixarr.vpn.enable option to be set, but it was not.
        '';
      }
    ];

    systemd.tmpfiles.rules = [
      "d '${cfg.stateDir}' 0700 readarr root - -"
    ];

    services.readarr = {
      enable = cfg.enable;
      user = "readarr";
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

    systemd.services."container@readarr" = mkIf cfg.vpn.enable {
      requires = ["wg.service"];
    };

    containers.readarr = mkIf cfg.vpn.enable {
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
        users.users.readarr = {
          uid = lib.mkForce config.users.users.readarr.uid;
          isSystemUser = true;
          group = "media";
        };

        # Use systemd-resolved inside the container
        # Workaround for bug https://github.com/NixOS/nixpkgs/issues/162686
        networking.useHostResolvConf = lib.mkForce false;
        services.resolved.enable = true;
        networking.nameservers = dnsServers;

        services.readarr = {
          enable = true;
          group = "media";
          dataDir = "${cfg.stateDir}";
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
