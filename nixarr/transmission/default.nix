{
  config,
  lib,
  pkgs,
  ...
}:
with lib; let
  cfg = config.nixarr.transmission;
  nixarr = config.nixarr;
  cfg-cross-seed = config.nixarr.transmission.privateTrackers.cross-seed;
  downloadDir = "${nixarr.mediaDir}/torrents";
  transmissionCrossSeedScript = with builtins; pkgs.writeShellApplication {
    name = "transmission-cross-seed-script";

    runtimeInputs = with pkgs; [ curl ];

    text = ''
      PROWLARR_API_KEY=$(cat prowlarr-api-key)
      curl -XPOST http://localhost:2468/api/webhook?apikey="$PROWLARR_API_KEY" --data-urlencode "infoHash=$TR_TORRENT_HASH"
    '';
  };
  importProwlarrApi = with builtins; pkgs.writeShellApplication {
    name = "import-prowlarr-api";

    runtimeInputs = with pkgs; [ yq ];

    text = ''
      touch ${cfg.stateDir}/prowlarr-api-key
      chmod 400 ${cfg.stateDir}/prowlarr-api-key
      chown torrenter ${cfg.stateDir}/prowlarr-api-key
      xq -r '.Config.ApiKey' "${nixarr.prowlarr.stateDir}/config.xml" > "${cfg.stateDir}/prowlarr-api-key"
    '';
  };
  mkCrossSeedCredentials = with builtins; pkgs.writeShellApplication {
    name = "mk-cross-seed-credentials";

    runtimeInputs = with pkgs; [ jq yq ];

    text =
      "INDEX_LINKS=("
      + (strings.concatMapStringsSep " " toString cfg.privateTrackers.cross-seed.indexIds)
      + ")"
      + "\n"
      + ''
        TMP_JSON=$(mktemp)
        CRED_FILE="/run/secrets/cross-seed/credentialsFile.json"
        PROWLARR_API_KEY=$(xq -r '.Config.ApiKey' "${nixarr.prowlarr.stateDir}/config.xml")
        # shellcheck disable=SC2034
        CRED_DIR=$(dirname "$CRED_FILE")

        mkdir -p "$CRED_DIR"
        echo '{}' > "$CRED_FILE"
        chmod 400 "$CRED_FILE"
        chown "${config.util-nixarr.services.cross-seed.user}" "$CRED_FILE"

        for i in "''${INDEX_LINKS[@]}"
        do
          LINK="http://localhost:9696/$i/api?apikey=$PROWLARR_API_KEY"
          jq ".torznab += [\"$LINK\"]" "$CRED_FILE" > "$TMP_JSON" && mv "$TMP_JSON" "$CRED_FILE"
        done
      '';
  };
in {
  options.nixarr.transmission = {
    enable = mkEnableOption "the Transmission service.";

    stateDir = mkOption {
      type = types.path;
      default = "${nixarr.stateDir}/transmission";
      defaultText = literalExpression ''"''${nixarr.stateDir}/transmission"'';
      example = "/home/user/.local/share/nixarr/transmission";
      description = ''
        The state directory for Transmission.
      '';
    };

    vpn.enable = mkOption {
      type = types.bool;
      default = false;
      example = true;
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
        example = true;
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
          example = true;
          description = ''
            **Required options:** [`nixarr.prowlarr.enable`](#nixarr.prowlarr.enable)

            Whether or not to enable the [cross-seed](https://www.cross-seed.org/) service.
          '';
        };

        stateDir = mkOption {
          type = types.path;
          default = "${nixarr.stateDir}/cross-seed";
          defaultText = literalExpression ''"''${nixarr.stateDir}/cross-seed"'';
          example = "/home/user/.local/share/nixarr/cross-seed";
          description = ''
            The state directory for Transmission.
          '';
        };

        indexIds = mkOption {
          type = with types; listOf int;
          default = [];
          example = [ 1 3 7 ];
          description = ''
            List of indexer-ids, from prowlarr. These are from the RSS links
            for the indexers, located by the "radio" or "RSS" logo on the
            right of the indexer, you'll see the links have the form:

            `http://localhost:9696/1/api?apikey=aaaaaaaaaaaaa`

            Then the id needed here is the `1`.
          '';
        };

        extraSettings = mkOption {
          type = types.attrs;
          default = {};
          example = {
            port = 3000;
            delay = 20;
          };
          description = ''
            Extra settings for the cross-seed
            service, see [the cross-seed options
            documentation](https://www.cross-seed.org/docs/basics/options)
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
      example = "debug";
      description = "Sets the message level of transmission.";
    };

    peerPort = mkOption {
      type = types.port;
      default = 50000;
      example = 12345;
      description = "Transmission peer traffic port.";
    };

    uiPort = mkOption {
      type = types.port;
      default = 9091;
      example = 12345;
      description = "Transmission web-UI port.";
    };

    extraSettings = mkOption {
      type = types.attrs;
      default = {};
      example = {
        trash-original-torrent-files = true;
      };
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
        assertion = cfg-cross-seed.enable -> nixarr.prowlarr.enable;
        message = ''
          The nixarr.privateTrackers.cross-seed.enable option requires the
          nixarr.prowlarr.enable option to be set, but it was not.
        '';
      }
    ];

    systemd.tmpfiles.rules = [
      "d '${cfg.stateDir}' 0700 torrenter root - -"
      # This is fixes a bug in nixpks (https://github.com/NixOS/nixpkgs/issues/291883)
      "d '${cfg.stateDir}/.config/transmission-daemon' 0700 torrenter root - -"
    ] ++ (
      if cfg-cross-seed.enable then
        [ "d '${cfg-cross-seed.stateDir}' 0700 cross-seed root - -" ]
      else []
    );

    util-nixarr.services.cross-seed = mkIf cfg-cross-seed.enable {
      enable = true;
      dataDir = cfg-cross-seed.stateDir;
      #group = "media";
      settings = {
        torrentDir = "${nixarr.mediaDir}/torrents";
        outputDir = "${nixarr.mediaDir}/torrents/.cross-seed";
        transmissionRpcUrl = "http://localhost:${builtins.toString cfg.uiPort}/transmission/rpc";
        rssCadence = "20 minutes";

        action = "inject";

        # Enable infrequent periodic searches
        searchCadence = "1 week";
        excludeRecentSearch = "1 year";
        excludeOlder = "1 year";
      } // cfg-cross-seed.extraSettings;
    };
    # Run as root in case that the cfg.credentialsFile is not readable by cross-seed
    systemd.services.cross-seed.serviceConfig = mkIf cfg-cross-seed.enable {
        ExecStartPre = mkBefore [( 
          "+" + "${mkCrossSeedCredentials}/bin/mk-cross-seed-credentials"
        )];
    };

    systemd.services.transmission.serviceConfig = mkIf cfg-cross-seed.enable {
        ExecStartPre = mkBefore [( 
          "+" + "${importProwlarrApi}/bin/import-prowlarr-api"
        )];
    };
    services.transmission = {
      enable = true;
      user = "torrenter";
      group = "torrenter";
      home = cfg.stateDir;
      webHome =
        if cfg.flood.enable
        then pkgs.flood-for-transmission
        else null;
      package = pkgs.transmission_4;
      openRPCPort = false;
      openPeerPorts = !cfg.vpn.enable;
      settings =
        {
          download-dir = downloadDir;
          incomplete-dir-enabled = true;
          incomplete-dir = "${downloadDir}/.incomplete";
          watch-dir-enabled = true;
          watch-dir = "${downloadDir}/.watch";

          rpc-bind-address = if cfg.vpn.enable then "192.168.15.1" else "127.0.0.1";
          rpc-port = cfg.uiPort;
          # TODO: fix this for ssh tunneling...
          rpc-whitelist-enabled = true;
          rpc-whitelist = "127.0.0.1,192.168.*";
          rpc-authentication-required = false;

          blocklist-enabled = true;
          blocklist-url = "https://github.com/Naunter/BT_BlockLists/raw/master/bt_blocklists.gz";

          peer-port = cfg.peerPort;
          dht-enabled = !cfg.privateTrackers.disableDhtPex;
          pex-enabled = !cfg.privateTrackers.disableDhtPex;
          utp-enabled = false;
          encryption = 1;
          port-forwarding-enabled = false;

          anti-brute-force-enabled = true;
          anti-brute-force-threshold = 10;

          script-torrent-done-enabled = cfg-cross-seed.enable;
          script-torrent-done-filename = if cfg-cross-seed.enable then 
            "${transmissionCrossSeedScript}/bin/transmission-cross-seed-script"
          else null;

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
        // cfg.extraSettings;
    };

    # Enable and specify VPN namespace to confine service in.
    systemd.services.transmission.vpnconfinement = mkIf cfg.vpn.enable {
      enable = true;
      vpnnamespace = "wg";
    };

    # Port mappings
    # TODO: open peerPort
    vpnnamespaces.wg = mkIf cfg.vpn.enable {
      portMappings = [{ from = cfg.uiPort; to = cfg.uiPort; }];
      openVPNPorts = [{ port = 24745; protocol = "both"; }];
      #openTcpPorts = [cfg.peerPort];
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
