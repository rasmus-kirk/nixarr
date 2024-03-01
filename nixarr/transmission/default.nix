# TODO: Dir creation and file permissions in nix
{
  config,
  lib,
  pkgs,
  ...
}:
with lib; let
  cfg = config.nixarr.transmission;
  nixarr = config.nixarr;
  dnsServers = config.lib.vpn.dnsServers;
  get-indexers = with builtins; pkgs.writeShellApplication {
    name = "get-indexers";

    runtimeInputs = with pkgs; [ jq yq ];

    text = ''
      PROWLARR_API_KEY=$(xq '.Config.ApiKey' "${nixarr.prowlarr.stateDir}/config.xml")
    ''
    + toJson (
      map (x: 
        ''http://localhost:9696/${toString x}/api?apikey="$PROWLARR_API_KEY"''
      ) cfg.privateTrackers.cross-seed.indexIds
    );
  };
in {
  options.nixarr.transmission = {
    enable = mkEnableOption "the Transmission service.";

    stateDir = mkOption {
      type = types.path;
      default = "${nixarr.stateDir}/nixarr/transmission";
      description = ''
        The state directory for Transmission.
      '';
    };

    downloadDir = mkOption {
      type = types.path;
      default = "${nixarr.mediaDir}/torrents";
      description = ''
        The directory for Transmission to download to.
      '';
    };

    vpn.enable = mkOption {
      type = types.bool;
      default = false;
      description = ''
        **Required options:** [`nixarr.vpn.enable`](#nixarr.vpn.enable)

        **Recommended:** Route Transmission traffic through the VPN.
      '';
    };

    flood.enable = mkEnableOption "the flood web-UI for the transmission web-UI.";

    privateTrackers = {
      disableDhtPex = mkOption {
        type = types.bool;
        default = false;
        description = ''
          Disable pex and dht, which is required for some private trackers.

          You don't want to enable this unless a private tracker requires you
          to, and some don't. All torrents from private trackers are set as
          "private", and this automatically disables dht and pex for that torrent,
          so it shouldn't even be a necessary rule to have, but I don't make
          their rules ¯\\_(ツ)_/¯.
        '';
      };
      cross-seed = {
        enable = mkOption {
          type = types.bool;
          default = false;
          description = ''
            Enable the cross-seed service.
          '';
        };
        indexIds = mkOption {
          type = with types; listOf int;
          default = [];
          description = ''
            list of indexers TODO: todo
          '';
        };
      };
    };

    messageLevel = mkOption {
      type = types.enum [
        "none"
        "critical"
        "error"
        "warn"
        "info"
        "debug"
        "trace"
      ];
      default = "warn";
      description = "Sets the message level of transmission.";
    };

    peerPort = mkOption {
      type = types.port;
      default = 50000;
      description = "Transmission peer traffic port.";
    };

    uiPort = mkOption {
      type = types.port;
      default = 9091;
      description = "Transmission web-UI port.";
    };

    extraConfig = mkOption {
      type = types.attrs;
      default = {};
      description = ''
        Extra config settings for the Transmission service.

        See the `services.transmission.settings` nixos options in
        the relevant section of the `configuration.nix` manual or on
        [search.nixos.org](https://search.nixos.org/options?channel=unstable&query=services.transmission.settings).
      '';
    };
  };

  imports = [
    ./cross-seed
  ];

  config = mkIf cfg.enable {
    assertions = [
      {
        assertion = cfg.vpn.enable -> nixarr.vpn.enable;
        message = ''
          The nixarr.transmission.vpn.enable option requires the
          nixarr.vpn.enable option to be set, but it was not.
        '';
      }
      {
        assertion = cfg.privateTrackers.cross-seed.enable -> nixarr.prowlarr.enable;
        message = ''
          TODO: todo
        '';
      }
    ];

    systemd.tmpfiles.rules = [
      "d '${cfg.stateDir}'                             0700 torrenter root - -"
      # This is fixes a bug in nixpks (https://github.com/NixOS/nixpkgs/issues/291883)
      "d '${cfg.stateDir}/.config/transmission-daemon' 0700 torrenter root - -"
    ];

    services.transmission = mkIf (!cfg.vpn.enable) {
      enable = true;
      user = "torrenter";
      group = "torrenter";
      home = cfg.stateDir;
      webHome =
        if cfg.flood.enable
        then pkgs.flood-for-transmission
        else null;
      package = pkgs.transmission_4;
      openRPCPort = true;
      openPeerPorts = true;
      settings =
        {
          download-dir = "${nixarr.mediaDir}/torrents";
          incomplete-dir-enabled = true;
          incomplete-dir = "${nixarr.mediaDir}/torrents/.incomplete";
          watch-dir-enabled = true;
          watch-dir = "${nixarr.mediaDir}/torrents/.watch";

          rpc-bind-address = "127.0.0.1";
          rpc-port = cfg.uiPort;
          rpc-whitelist-enabled = true;
          rpc-whitelist = "192.168.15.1,127.0.0.1";
          rpc-authentication-required = false;

          blocklist-enabled = true;
          blocklist-url = "https://github.com/Naunter/BT_BlockLists/raw/master/bt_blocklists.gz";

          peer-port = cfg.peerPort;
          dht-enabled = !cfg.privateTrackers;
          pex-enabled = !cfg.privateTrackers;
          utp-enabled = false;
          encryption = 1;
          port-forwarding-enabled = false;

          anti-brute-force-enabled = true;
          anti-brute-force-threshold = 10;

          message-level =
            if cfg.messageLevel == "none"
            then 0
            else if cfg.messageLevel == "critical"
            then 1
            else if cfg.messageLevel == "error"
            then 2
            else if cfg.messageLevel == "warn"
            then 3
            else if cfg.messageLevel == "info"
            then 4
            else if cfg.messageLevel == "debug"
            then 5
            else if cfg.messageLevel == "trace"
            then 6
            else null;
        }
        // cfg.extraConfig;
    };

    services.cross-seed = mkIf cfg.cross-seed.enable {
      enable = true;
      group = "media";
      dataDir = cfg.privateTrackers.cross-seed.dataDir;
      configFile = cfg.privateTrackers.cross-seed.configFile;
    };

    util-nixarr.vpnnamespace = mkIf cfg.vpn.enable {
      portMappings = [
        {
          From = cfg.uiPort;
          To = cfg.uiPort;
        }
      ];
      openUdpPorts = [cfg.peerPort];
      openTcpPorts = [cfg.peerPort];
    };

    systemd.services."container@transmission" = mkIf cfg.vpn.enable {
      requires = ["wg.service"];
    };

    containers.transmission = mkIf cfg.vpn.enable {
      autoStart = true;
      ephemeral = true;
      extraFlags = ["--network-namespace-path=/var/run/netns/wg"];

      bindMounts = {
        "${nixarr.mediaDir}/torrents".isReadOnly = false;
        "/var/lib/transmission" = {
          hostPath = cfg.stateDir;
          isReadOnly = false;
        };
      };

      config = {
        users.groups.torrenter = {
          gid = config.users.groups.torrenter.gid;
        };
        users.users.torrenter = {
          uid = lib.mkForce config.users.users.torrenter.uid;
          isSystemUser = true;
          group = "torrenter";
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
          user = "torrenter";
          group = "torrenter";
          webHome =
            if cfg.flood.enable
            then pkgs.flood-for-transmission
            else null;
          package = pkgs.transmission_4;
          openRPCPort = true;
          openPeerPorts = true;
          settings =
            {
              download-dir = "${nixarr.mediaDir}/torrents";
              incomplete-dir-enabled = true;
              incomplete-dir = "${nixarr.mediaDir}/torrents/.incomplete";
              watch-dir-enabled = true;
              watch-dir = "${nixarr.mediaDir}/torrents/.watch";

              rpc-bind-address = "192.168.15.1";
              rpc-port = cfg.uiPort;
              rpc-whitelist-enabled = false;
              rpc-whitelist = "192.168.15.1,127.0.0.1";
              rpc-authentication-required = false;

              blocklist-enabled = true;
              blocklist-url = "https://github.com/Naunter/BT_BlockLists/raw/master/bt_blocklists.gz";

              peer-port = cfg.peerPort;
              dht-enabled = !cfg.privateTrackers;
              pex-enabled = !cfg.privateTrackers;
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
  };
}
