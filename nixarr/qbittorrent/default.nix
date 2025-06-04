{
  config,
  lib,
  pkgs,
  ...
}:
with lib; let
  cfg = config.nixarr.qbittorrent;
  globals = config.util-nixarr.globals;
  nixarr = config.nixarr;
in {
  options.nixarr.qbittorrent = {
    enable = mkOption {
      type = types.bool;
      default = false;
      example = true;
      description = ''
        Whether or not to enable the qBittorrent service.

        **Required options:** [`nixarr.enable`](#nixarr.enable)
      '';
    };

    package = mkPackageOption pkgs "qbittorrent-nox" {};

    stateDir = mkOption {
      type = types.path;
      default = "${nixarr.stateDir}/qbittorrent";
      defaultText = literalExpression ''"''${nixarr.stateDir}/qbittorrent"'';
      example = "/nixarr/.state/qbittorrent";
      description = ''
        The location of the state directory for the qBittorrent service.

        > **Warning:** Setting this to any path, where the subpath is not
        > owned by root, will fail! For example:
        >
        > ```nix
        >   stateDir = /home/user/nixarr/.state/qbittorrent
        > ```
        >
        > Is not supported, because `/home/user` is owned by `user`.
      '';
    };

    openFirewall = mkOption {
      type = types.bool;
      defaultText = literalExpression ''!nixarr.qbittorrent.vpn.enable'';
      default = !cfg.vpn.enable;
      example = true;
      description = "Open firewall for qBittorrent web UI and BitTorrent ports.";
    };

    vpn.enable = mkOption {
      type = types.bool;
      default = false;
      example = true;
      description = ''
        **Required options:** [`nixarr.vpn.enable`](#nixarr.vpn.enable)

        Route qBittorrent traffic through the VPN.
      '';
    };

    uiPort = mkOption {
      type = types.port;
      default = 8080;
      example = 8080;
      description = "qBittorrent web UI port.";
    };

    peerPort = mkOption {
      type = types.port;
      default = 32189;
      example = 32189;
      description = "qBittorrent BitTorrent protocol port.";
    };
  };

  config = mkIf (nixarr.enable && cfg.enable) {
    assertions = [
      {
        assertion = cfg.enable -> nixarr.enable;
        message = ''
          The nixarr.qbittorrent.enable option requires the
          nixarr.enable option to be set, but it was not.
        '';
      }
      {
        assertion = cfg.vpn.enable -> nixarr.vpn.enable;
        message = ''
          The nixarr.qbittorrent.vpn.enable option requires the
          nixarr.vpn.enable option to be set, but it was not.
        '';
      }
    ];

    users = {
      groups.${globals.qbittorrent.group}.gid = globals.gids.${globals.qbittorrent.group};
      users.${globals.qbittorrent.user} = {
        isSystemUser = true;
        group = globals.qbittorrent.group;
        uid = globals.uids.${globals.qbittorrent.user};
      };
    };

    systemd.tmpfiles.rules = [
      "d '${cfg.stateDir}'                          0750 ${globals.qbittorrent.user} ${globals.qbittorrent.group} - -"

      # Media directories
      "d '${nixarr.mediaDir}/torrents'              0755 ${globals.qbittorrent.user} ${globals.qbittorrent.group} - -"
      "d '${nixarr.mediaDir}/torrents/.incomplete'  0755 ${globals.qbittorrent.user} ${globals.qbittorrent.group} - -"
      "d '${nixarr.mediaDir}/torrents/manual'       0755 ${globals.qbittorrent.user} ${globals.qbittorrent.group} - -"
      "d '${nixarr.mediaDir}/torrents/lidarr'       0755 ${globals.qbittorrent.user} ${globals.qbittorrent.group} - -"
      "d '${nixarr.mediaDir}/torrents/radarr'       0755 ${globals.qbittorrent.user} ${globals.qbittorrent.group} - -"
      "d '${nixarr.mediaDir}/torrents/sonarr'       0755 ${globals.qbittorrent.user} ${globals.qbittorrent.group} - -"
      "d '${nixarr.mediaDir}/torrents/readarr'      0755 ${globals.qbittorrent.user} ${globals.qbittorrent.group} - -"
    ];

    systemd.services.qbittorrent = {
      description = "qBittorrent BitTorrent client";
      after = [ "network.target" ];
      wantedBy = [ "multi-user.target" ];

      serviceConfig = {
        Type = "simple";
        User = globals.qbittorrent.user;
        Group = globals.qbittorrent.group;
        ExecStart = "${cfg.package}/bin/qbittorrent-nox";
        Restart = "on-failure";
        RestartSec = "5s";
        
        NoNewPrivileges = true;
        PrivateTmp = true;
        ProtectSystem = "off";
        ProtectHome = false;
        
        # Always prioritize all other services wrt. IO
        IOSchedulingPriority = 7;
      };

      environment = {
        WEBUI_PORT = toString cfg.uiPort;
        HOME = cfg.stateDir;
        XDG_CONFIG_HOME = cfg.stateDir;
        XDG_DATA_HOME = cfg.stateDir;
      };
    };

    # Enable and specify VPN namespace to confine service in.
    systemd.services.qbittorrent.vpnConfinement = mkIf cfg.vpn.enable {
      enable = true;
      vpnNamespace = "wg";
    };

    # Port mappings
    vpnNamespaces.wg = mkIf cfg.vpn.enable {
      portMappings = [
        {
          from = cfg.uiPort;
          to = cfg.uiPort;
        }
      ];
      openVPNPorts = [
        {
          port = cfg.peerPort;
          protocol = "both";
        }
      ];
    };

    services.nginx = mkIf cfg.vpn.enable {
      enable = true;

      recommendedTlsSettings = true;
      recommendedOptimisation = true;
      recommendedGzipSettings = true;

      virtualHosts."127.0.0.1:${builtins.toString cfg.uiPort}" = {
        listen = [
          {
            addr = "0.0.0.0";
            port = cfg.uiPort;
          }
        ];
        locations."/" = {
          recommendedProxySettings = true;
          proxyWebsockets = true;
          proxyPass = "http://192.168.15.1:${builtins.toString cfg.uiPort}";
        };
      };
    };

    networking.firewall = mkIf cfg.openFirewall {
      allowedTCPPorts = [ cfg.uiPort cfg.peerPort ];
      allowedUDPPorts = [ cfg.peerPort ];
    };
  };
}
