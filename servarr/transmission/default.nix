# TODO: Dir creation and file permissions in nix
{
  config,
  lib,
  pkgs,
  ...
}:
with lib; let
  cfg = config.servarr.transmission;
  servarr = config.servarr;
  dnsServers = config.lib.vpn.dnsServers;
in {
  options.servarr.transmission = {
    enable = mkOption {
      type = types.bool;
      default = false;
      description = lib.mdDoc "Enable transmission";
    };

    stateDir = mkOption {
      type = types.path;
      default = "${servarr.stateDir}/servarr/transmission";
      description = lib.mdDoc "The state directory for transmission. Only works with useVpn option.";
    };

    downloadDir = mkOption {
      type = types.path;
      default = "${servarr.mediaDir}/torrents";
      description = lib.mdDoc ''
        The directory for transmission to download to.
      '';
    };

    useVpn = mkOption {
      type = types.bool;
      default = false;
      description = lib.mdDoc "Run transmission through VPN";
    };

    useFlood = mkOption {
      type = types.bool;
      default = false;
      description = lib.mdDoc "Use the flood UI";
    };

    peerPort = mkOption {
      type = types.port;
      default = 50000;
      description = "transmission peer traffic port.";
    };

    uiPort = mkOption {
      type = types.port;
      default = 9091;
      description = "transmission web-UI port.";
    };

    extraConfig = mkOption {
      type = types.attrs;
      default = {};
      description = "Extra settings config for the transmission service.";
    };
  };

  config = mkIf cfg.enable {
    services.transmission = mkIf (!cfg.useVpn) {
      enable = true;
      group = "media";
      #home = cfg.stateDir;
      webHome =
        if cfg.useFlood
        then pkgs.flood-for-transmission
        else null;
      package = pkgs.transmission_4;
      openRPCPort = true;
      openPeerPorts = true;
      settings =
        {
          download-dir = "${servarr.mediaDir}/torrents";
          incomplete-dir-enabled = true;
          incomplete-dir = "${servarr.mediaDir}/torrents/.incomplete";
          watch-dir-enabled = true;
          watch-dir = "${servarr.mediaDir}/torrents/.watch";

          rpc-port = cfg.uiPort;
          rpc-whitelist-enabled = true;
          rpc-whitelist = "192.168.15.1,127.0.0.1";
          rpc-authentication-required = true;

          blocklist-enabled = true;
          blocklist-url = "https://github.com/Naunter/BT_BlockLists/raw/master/bt_blocklists.gz";

          encryption = 1;
          utp-enabled = true;
          port-forwarding-enabled = false;

          anti-brute-force-enabled = true;
          anti-brute-force-threshold = 10;
        }
        // cfg.extraConfig;
    };

    util.vpnnamespace = mkIf cfg.useVpn {
      portMappings = [
        {
          From = cfg.uiPort;
          To = cfg.uiPort;
        }
      ];
      openUdpPorts = [cfg.peerPort];
      openTcpPorts = [cfg.peerPort];
    };

    containers.transmission = mkIf cfg.useVpn {
      autoStart = true;
      ephemeral = true;
      extraFlags = ["--network-namespace-path=/var/run/netns/wg"];

      bindMounts = {
        "${servarr.mediaDir}/torrents".isReadOnly = false;
        "/var/lib/transmission" = {
          hostPath = cfg.stateDir;
          isReadOnly = false;
        };
      };

      config = {
        users.groups.media = {
          gid = config.users.groups.media.gid;
        };
        users.users.transmission = {
          uid = lib.mkForce config.users.users.transmission.uid;
          isSystemUser = true;
          group = "media";
        };

        # Use systemd-resolved inside the container
        # Workaround for bug https://github.com/NixOS/nixpkgs/issues/162686
        networking.useHostResolvConf = lib.mkForce false;
        services.resolved.enable = true;
        networking.nameservers = dnsServers;

        systemd.services.transmission.serviceConfig = {
          RootDirectoryStartOnly = lib.mkForce false;
          RootDirectory = lib.mkForce "";
        };

        services.transmission = {
          enable = true;
          # This is maybe wrong, too afraid to fix it lol
          group = "media";
          webHome =
            if cfg.useFlood
            then pkgs.flood-for-transmission
            else null;
          package = pkgs.transmission_4;
          openRPCPort = true;
          openPeerPorts = true;
          settings =
            {
              download-dir = "${servarr.mediaDir}/torrents";
              incomplete-dir-enabled = true;
              incomplete-dir = "${servarr.mediaDir}/torrents/.incomplete";
              watch-dir-enabled = true;
              watch-dir = "${servarr.mediaDir}/torrents/.watch";

              rpc-bind-address = "192.168.15.1";
              rpc-port = cfg.uiPort;
              rpc-whitelist-enabled = false;
              rpc-whitelist = "192.168.15.1,127.0.0.1";
              rpc-authentication-required = false;

              blocklist-enabled = true;
              blocklist-url = "https://github.com/Naunter/BT_BlockLists/raw/master/bt_blocklists.gz";

              peer-port = cfg.peerPort;
              dht-enabled = true;
              pex-enabled = true;
              utp-enabled = false;
              encryption = 1;
              port-forwarding-enabled = false;

              anti-brute-force-enabled = true;
              anti-brute-force-threshold = 10;

              # 0 = None, 1 = Critical, 2 = Error, 3 = Warn, 4 = Info, 5 = Debug, 6 = Trace
              message-level = 3;
            }
            // cfg.extraConfig;
        };

        environment.systemPackages = with pkgs; [
          curl
          wget
          util-linux
          unixtools.ping
          coreutils
          curl
          bash
          libressl
          netcat-gnu
          openresolv
          dig
        ];

        system.stateVersion = "23.11";
      };
    };

    services.nginx = mkIf cfg.useVpn {
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
  };
}
