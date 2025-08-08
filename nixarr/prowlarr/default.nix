{
  config,
  lib,
  pkgs,
  ...
}:
with lib; let
  cfg = config.nixarr.prowlarr;
  globals = config.util-nixarr.globals;
  nixarr = config.nixarr;
  port = 9696;
in {
  options.nixarr.prowlarr = {
    enable = mkOption {
      type = types.bool;
      default = false;
      example = true;
      description = ''
        Whether or not to enable the Prowlarr service. This has
        a seperate service since running two instances is the standard
        way of being able to query both ebooks and audiobooks.
      '';
    };

    package = mkPackageOption pkgs "prowlarr" {};

    port = mkOption {
      type = types.port;
      default = port;
      description = "Port for Prowlarr to use.";
    };

    stateDir = mkOption {
      type = types.path;
      default = "${nixarr.stateDir}/prowlarr";
      defaultText = literalExpression ''"''${nixarr.stateDir}/prowlarr"'';
      example = "/nixarr/.state/prowlarr";
      description = ''
        The location of the state directory for the Prowlarr service.

        > **Warning:** Setting this to any path, where the subpath is not
        > owned by root, will fail! For example:
        >
        > ```nix
        >   stateDir = /home/user/nixarr/.state/prowlarr
        > ```
        >
        > Is not supported, because `/home/user` is owned by `user`.
      '';
    };

    openFirewall = mkOption {
      type = types.bool;
      defaultText = literalExpression ''!nixarr.prowlarr.vpn.enable'';
      default = !cfg.vpn.enable;
      example = true;
      description = "Open firewall for Prowlarr";
    };

    vpn.enable = mkOption {
      type = types.bool;
      default = false;
      example = true;
      description = ''
        **Required options:** [`nixarr.vpn.enable`](#nixarr.vpn.enable)

        Route Prowlarr traffic through the VPN.
      '';
    };
  };

  config = mkIf (nixarr.enable && cfg.enable) {
    assertions = [
      {
        assertion = cfg.vpn.enable -> nixarr.vpn.enable;
        message = ''
          The nixarr.prowlarr.vpn.enable option requires the
          nixarr.vpn.enable option to be set, but it was not.
        '';
      }
    ];

    systemd.tmpfiles.rules = [
      "d '${cfg.stateDir}' 0700 ${globals.prowlarr.user} root - -"
    ];

    networking.firewall = mkIf cfg.openFirewall {
      allowedTCPPorts = [cfg.port];
    };

    users = {
      groups.${globals.prowlarr.group}.gid = globals.gids.${globals.prowlarr.group};
      users.${globals.prowlarr.user} = {
        isSystemUser = true;
        group = globals.prowlarr.group;
        uid = globals.uids.${globals.prowlarr.user};
      };
    };
    systemd.services.prowlarr = {
      description = "prowlarr";
      after = ["network.target"];
      wantedBy = ["multi-user.target"];
      wants = mkIf nixarr.autosync ["nixarr-api-key.service"];
      environment.PROWLARR__SERVER__PORT = builtins.toString cfg.port;

      postStart =
        mkIf nixarr.api-key-location
        != null (
          let
            configure-prowlarr =
              pkgs.writers.writePython3Bin "configure-prowlarr" {
                libraries = [];
                flakeIgnore = ["E501" "E121" "E122"];
              } ''
                import sqlite3
                import json
                import os.path
                import time

                db_path = "${cfg.stateDir}/prowlarr.db"
                while not os.path.exists(db_path):
                    time.sleep(1)

                con = sqlite3.connect(db_path)
                api_key = open("${nixarr.api-key-location}", "r").read()
                sonarr = {
                  "prowlarrUrl": "http://localhost:${builtins.toString cfg.port}",
                  "baseUrl": "http://localhost:8989",
                  "apiKey": api_key,
                  "syncCategories": [
                      5000,
                      5010,
                      5020,
                      5030,
                      5040,
                      5045,
                      5050,
                      5090
                  ],
                  "animeSyncCategories": [5070],
                  "syncAnimeStandardFormatSearch": True,
                  "syncRejectBlocklistedTorrentHashesWhileGrabbing": False
                }
                radarr = {
                  "prowlarrUrl": "http://localhost:${builtins.toString cfg.port}",
                  "baseUrl": "http://localhost:${builtins.toString nixarr.radarr.port}",
                  "apiKey": api_key,
                  "syncCategories": [
                      2000,
                      2010,
                      2020,
                      2030,
                      2040,
                      2045,
                      2050,
                      2060,
                      2070,
                      2080,
                      2090
                  ],
                  "syncRejectBlocklistedTorrentHashesWhileGrabbing": False
                }
                cur = con.cursor()
                data = [
                ${
                  if nixarr.sonarr.enable
                  then ''
                    ("nixarr_autosync_sonarr", "Sonarr", json.dumps(sonarr), "SonarrSettings", 2, "[]"),
                  ''
                  else ""
                }
                ${
                  if nixarr.radarr.enable
                  then ''
                    ("nixarr_autosync_radarr", "Radarr", json.dumps(radarr), "RadarrSettings", 2, "[]"),
                  ''
                  else ""
                }
                ]
                cur.executemany("INSERT INTO Applications VALUES(NULL, ?, ?, ?, ?, ?, ?) ON CONFLICT(Name) DO UPDATE SET Settings=excluded.Settings", data)
                con.commit()
              '';
          in "${configure-prowlarr}/bin/configure-prowlarr"
        );

      serviceConfig = {
        Type = "simple";
        User = globals.prowlarr.user;
        Group = globals.prowlarr.group;
        ExecStart = "${lib.getExe cfg.package} -nobrowser -data=${cfg.stateDir}";
        Restart = "on-failure";
      };

      # Enable and specify VPN namespace to confine service in.
      vpnConfinement = mkIf cfg.vpn.enable {
        enable = true;
        vpnNamespace = "wg";
      };
    };

    vpnNamespaces.wg = mkIf cfg.vpn.enable {
      portMappings = [
        {
          from = cfg.port;
          to = cfg.port;
        }
      ];
    };
    services.nginx = mkIf cfg.vpn.enable {
      enable = true;

      recommendedTlsSettings = true;
      recommendedOptimisation = true;
      recommendedGzipSettings = true;

      virtualHosts."127.0.0.1:${builtins.toString cfg.port}" = {
        listen = [
          {
            addr = "0.0.0.0";
            port = cfg.port;
          }
        ];
        locations."/" = {
          recommendedProxySettings = true;
          proxyWebsockets = true;
          proxyPass = "http://192.168.15.1:${builtins.toString cfg.port}";
        };
      };
    };
  };
}
