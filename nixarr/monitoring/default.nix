{
  config,
  lib,
  pkgs,
  ...
}:
with lib; let
  cfg = config.nixarr;

  # Helper function to determine if a service is VPN-confined
  isVpnConfined = service: cfg.${service}.enable && cfg.${service}.vpn.enable;

  # Helper to determine if an exporter should be enabled
  shouldEnableExporter = service:
    cfg.${service}.enable
    && (cfg.${service}.exporter.enable == null || cfg.${service}.exporter.enable);
in {
  imports = [../lib/api-keys.nix];

  options = {
    nixarr = {
      exporters = {
        enable = mkEnableOption "Enable Prometheus exporters for all supported nixarr services";
      };

      sonarr.exporter = {
        enable = mkOption {
          type = types.nullOr types.bool;
          default = null;
          description = ''
            Whether to enable the Sonarr Prometheus exporter.
            - null: enable if exporters.enable is true and sonarr service is enabled (default)
            - true: force enable if exporters.enable is true
            - false: always disable
          '';
        };
        port = mkOption {
          type = types.port;
          default = 9707;
          description = "Port for Sonarr metrics";
        };
      };
      radarr.exporter = {
        enable = mkOption {
          type = types.nullOr types.bool;
          default = null;
          description = ''
            Whether to enable the Radarr Prometheus exporter.
            - null: enable if exporters.enable is true and radarr service is enabled (default)
            - true: force enable if exporters.enable is true
            - false: always disable
          '';
        };
        port = mkOption {
          type = types.port;
          default = 9708;
          description = "Port for Radarr metrics";
        };
      };
      lidarr.exporter = {
        enable = mkOption {
          type = types.nullOr types.bool;
          default = null;
          description = ''
            Whether to enable the Lidarr Prometheus exporter.
            - null: enable if exporters.enable is true and lidarr service is enabled (default)
            - true: force enable if exporters.enable is true
            - false: always disable
          '';
        };
        port = mkOption {
          type = types.port;
          default = 9709;
          description = "Port for Lidarr metrics";
        };
      };
      readarr.exporter = {
        enable = mkOption {
          type = types.nullOr types.bool;
          default = null;
          description = ''
            Whether to enable the Readarr Prometheus exporter.
            - null: enable if exporters.enable is true and readarr service is enabled (default)
            - true: force enable if exporters.enable is true
            - false: always disable
          '';
        };
        port = mkOption {
          type = types.port;
          default = 9710;
          description = "Port for Readarr metrics";
        };
      };
      prowlarr.exporter = {
        enable = mkOption {
          type = types.nullOr types.bool;
          default = null;
          description = ''
            Whether to enable the Prowlarr Prometheus exporter.
            - null: enable if exporters.enable is true and prowlarr service is enabled (default)
            - true: force enable if exporters.enable is true
            - false: always disable
          '';
        };
        port = mkOption {
          type = types.port;
          default = 9711;
          description = "Port for Prowlarr metrics";
        };
      };
    };
  };

  config = mkIf (cfg.enable && cfg.exporters.enable) {
    # Configure Prometheus exporters
    services.prometheus = {
      exporters = {
        # Enable exportarr for each supported service if it's enabled
        exportarr-sonarr =
          mkIf (
            cfg.sonarr.enable
            && (cfg.sonarr.exporter.enable == null || cfg.sonarr.exporter.enable)
          ) {
            enable = true;
            url = "http://127.0.0.1:8989";
            apiKeyFile = "${cfg.stateDir}/api-keys/sonarr.key";
            port = cfg.sonarr.exporter.port;
          };

        exportarr-radarr =
          mkIf (
            cfg.radarr.enable
            && (cfg.radarr.exporter.enable == null || cfg.radarr.exporter.enable)
          ) {
            enable = true;
            url = "http://127.0.0.1:7878";
            apiKeyFile = "${cfg.stateDir}/api-keys/radarr.key";
            port = cfg.radarr.exporter.port;
          };

        exportarr-lidarr =
          mkIf (
            cfg.lidarr.enable
            && (cfg.lidarr.exporter.enable == null || cfg.lidarr.exporter.enable)
          ) {
            enable = true;
            url = "http://127.0.0.1:8686";
            apiKeyFile = "${cfg.stateDir}/api-keys/lidarr.key";
            port = cfg.lidarr.exporter.port;
          };

        exportarr-readarr =
          mkIf (
            cfg.readarr.enable
            && (cfg.readarr.exporter.enable == null || cfg.readarr.exporter.enable)
          ) {
            enable = true;
            url = "http://127.0.0.1:8787";
            apiKeyFile = "${cfg.stateDir}/api-keys/readarr.key";
            port = cfg.readarr.exporter.port;
          };

        exportarr-prowlarr =
          mkIf (
            cfg.prowlarr.enable
            && (cfg.prowlarr.exporter.enable == null || cfg.prowlarr.exporter.enable)
          ) {
            enable = true;
            url = "http://127.0.0.1:9696";
            apiKeyFile = "${cfg.stateDir}/api-keys/prowlarr.key";
            port = cfg.prowlarr.exporter.port;
          };

        # Enable node and systemd exporters by default
        node = {
          enable = true;
          enabledCollectors = ["systemd" "tcpstat" "network_route"];
        };
        systemd.enable = true;

        # Configure wireguard exporter
        wireguard = mkIf cfg.vpn.enable {
          enable = true;
          openFirewall = false;
        };
      };
    };

    # Add systemd services for VPN-confined exporters
    systemd.services = mkMerge [
      # VPN-confined exporters
      (mkIf cfg.vpn.enable (
        let
          # Create VPN-confined exporter services for each Arr service
          makeVpnExporterService = service:
            mkIf (isVpnConfined service && shouldEnableExporter service) {
              "prometheus-exportarr-${service}-exporter" = {
                vpnConfinement = {
                  enable = true;
                  vpnNamespace = "wg";
                };
                # Add dependency on API key extraction
                after = ["${service}-api-key.service"];
                requires = ["${service}-api-key.service"];
                serviceConfig = {
                  DynamicUser = true;
                  SupplementaryGroups = ["api-keys"];
                };
              };
            };
        in
          lib.mkMerge [
            (makeVpnExporterService "sonarr")
            (makeVpnExporterService "radarr")
            (makeVpnExporterService "lidarr")
            (makeVpnExporterService "readarr")
            (makeVpnExporterService "prowlarr")
            {
              # Add VPN confinement for wireguard exporter
              prometheus-wireguard-exporter = {
                vpnConfinement = {
                  enable = true;
                  vpnNamespace = "wg";
                };
                serviceConfig = {
                  DynamicUser = true;
                };
              };
            }
          ]
      ))

      # Add dependencies for non-VPN exporters
      {
        "prometheus-exportarr-sonarr-exporter" = mkIf (shouldEnableExporter "sonarr" && !isVpnConfined "sonarr") {
          after = ["sonarr-api-key.service"];
          requires = ["sonarr-api-key.service"];
        };
        "prometheus-exportarr-radarr-exporter" = mkIf (shouldEnableExporter "radarr" && !isVpnConfined "radarr") {
          after = ["radarr-api-key.service"];
          requires = ["radarr-api-key.service"];
        };
        "prometheus-exportarr-lidarr-exporter" = mkIf (shouldEnableExporter "lidarr" && !isVpnConfined "lidarr") {
          after = ["lidarr-api-key.service"];
          requires = ["lidarr-api-key.service"];
        };
        "prometheus-exportarr-readarr-exporter" = mkIf (shouldEnableExporter "readarr" && !isVpnConfined "readarr") {
          after = ["readarr-api-key.service"];
          requires = ["readarr-api-key.service"];
        };
        "prometheus-exportarr-prowlarr-exporter" = mkIf (shouldEnableExporter "prowlarr" && !isVpnConfined "prowlarr") {
          after = ["prowlarr-api-key.service"];
          requires = ["prowlarr-api-key.service"];
        };
      }
    ];

    # Add port mappings for VPN-confined exporters
    vpnNamespaces.wg = mkIf cfg.vpn.enable {
      portMappings =
        (optional (shouldEnableExporter "sonarr" && isVpnConfined "sonarr") {
          from = cfg.sonarr.exporter.port;
          to = cfg.sonarr.exporter.port;
        })
        ++ (optional (shouldEnableExporter "radarr" && isVpnConfined "radarr") {
          from = cfg.radarr.exporter.port;
          to = cfg.radarr.exporter.port;
        })
        ++ (optional (shouldEnableExporter "lidarr" && isVpnConfined "lidarr") {
          from = cfg.lidarr.exporter.port;
          to = cfg.lidarr.exporter.port;
        })
        ++ (optional (shouldEnableExporter "readarr" && isVpnConfined "readarr") {
          from = cfg.readarr.exporter.port;
          to = cfg.readarr.exporter.port;
        })
        ++ (optional (shouldEnableExporter "prowlarr" && isVpnConfined "prowlarr") {
          from = cfg.prowlarr.exporter.port;
          to = cfg.prowlarr.exporter.port;
        })
        ++ [
          {
            from = 9586; # Default Wireguard exporter port
            to = 9586;
          }
        ];
    };

    # Open firewall ports for non-VPN exporters
    networking.firewall.allowedTCPPorts = mkIf (!cfg.vpn.enable) (
      (optional (shouldEnableExporter "sonarr" && !isVpnConfined "sonarr") cfg.sonarr.exporter.port)
      ++ (optional (shouldEnableExporter "radarr" && !isVpnConfined "radarr") cfg.radarr.exporter.port)
      ++ (optional (shouldEnableExporter "lidarr" && !isVpnConfined "lidarr") cfg.lidarr.exporter.port)
      ++ (optional (shouldEnableExporter "readarr" && !isVpnConfined "readarr") cfg.readarr.exporter.port)
      ++ (optional (shouldEnableExporter "prowlarr" && !isVpnConfined "prowlarr") cfg.prowlarr.exporter.port)
    );
  };
}
