{
  config,
  lib,
  pkgs,
  ...
}:
with lib; let
  cfg = config.nixarr;
  
  # Helper function to determine if a specific exporter should be enabled
  shouldEnableExporter = service: 
    cfg.${service}.enable && 
    (cfg.monitoring.exporters.${service} or true);
    
  # Helper function to determine if a service is VPN-confined
  isVpnConfined = service: cfg.${service}.enable && cfg.${service}.vpn.enable;
    
  # Helper function to create a script that extracts API key from config.xml
  extractApiKeys = pkgs.writeShellApplication {
    name = "extract-monitoring-api-keys";
    runtimeInputs = with pkgs; [ dasel coreutils ];
    text = ''
      # Create state directory for API keys
      STATE_DIR="/var/lib/exportarr"
      mkdir -p "$STATE_DIR"
      chmod 755 "$STATE_DIR"

      # Function to wait for config file and extract API key
      wait_and_extract() {
        local service=$1
        local config_file=$2
        local max_attempts=30  # 5 minutes (10s * 30)
        local attempt=0

        echo "Waiting for $service config file..."
        while [ $attempt -lt $max_attempts ]; do
          if [ -f "$config_file" ]; then
            API_KEY_FILE="$STATE_DIR/$service-api-key"
            if ${pkgs.dasel}/bin/dasel -f "$config_file" -s ".Config.ApiKey" | tr -d '\n\r'> "$API_KEY_FILE" 2>/dev/null; then
              chmod 400 "$API_KEY_FILE"
              echo "$service API key extracted successfully"
              return 0
            fi
          fi
          echo "Waiting for $service config file to be ready... (attempt $((attempt + 1))/$max_attempts)"
          sleep 10
          attempt=$((attempt + 1))
        done
        echo "Failed to extract $service API key after $max_attempts attempts"
        return 1
      }

      # Extract API keys for enabled services
      ${optionalString (shouldEnableExporter "sonarr") ''
        wait_and_extract "sonarr" "${cfg.sonarr.stateDir}/config.xml"
      ''}

      ${optionalString (shouldEnableExporter "radarr") ''
        wait_and_extract "radarr" "${cfg.radarr.stateDir}/config.xml"
      ''}

      ${optionalString (shouldEnableExporter "lidarr") ''
        wait_and_extract "lidarr" "${cfg.lidarr.stateDir}/config.xml"
      ''}

      ${optionalString (shouldEnableExporter "readarr") ''
        wait_and_extract "readarr" "${cfg.readarr.stateDir}/config.xml"
      ''}

      ${optionalString (shouldEnableExporter "prowlarr") ''
        wait_and_extract "prowlarr" "${cfg.prowlarr.stateDir}/config.xml"
      ''}
    '';
  };
in {
  config = mkIf (cfg.enable && cfg.monitoring.enable) {
    # Configure Prometheus exporters for Arr services
    services.prometheus = {
      exporters = {
        # Enable exportarr for each supported service if it's enabled
        exportarr-sonarr = mkIf (shouldEnableExporter "sonarr") {
          enable = true;
          url = "http://127.0.0.1:8989";
          apiKeyFile = "/var/lib/exportarr/sonarr-api-key";
          port = 9707;
        };
        
        exportarr-radarr = mkIf (shouldEnableExporter "radarr") {
          enable = true;
          url = "http://127.0.0.1:7878";
          apiKeyFile = "/var/lib/exportarr/radarr-api-key";
          port = 9708;
        };
        
        exportarr-lidarr = mkIf (shouldEnableExporter "lidarr") {
          enable = true;
          url = "http://127.0.0.1:8686";
          apiKeyFile = "/var/lib/exportarr/lidarr-api-key";
          port = 9709;
        };
        
        exportarr-readarr = mkIf (shouldEnableExporter "readarr") {
          enable = true;
          url = "http://127.0.0.1:8787";
          apiKeyFile = "/var/lib/exportarr/readarr-api-key";
          port = 9710;
        };
        
        exportarr-prowlarr = mkIf (shouldEnableExporter "prowlarr") {
          enable = true;
          url = "http://127.0.0.1:9696";
          apiKeyFile = "/var/lib/exportarr/prowlarr-api-key";
          port = 9711;
        };
        
        # Enable node and systemd exporters by default
        node.enable = true;
        systemd.enable = true;

        # Configure wireguard exporter
        wireguard = mkIf cfg.vpn.enable {
          enable = true;
          openFirewall = false;
        };
      };
    };

    # Add systemd services for VPN-confined exporters and API key setup
    systemd.services = mkMerge [
      # VPN-confined exporters
      (mkIf cfg.vpn.enable (
        let
          # Create VPN-confined exporter services for each Arr service
          makeVpnExporterService = service: nameInConfig:
            mkIf (isVpnConfined service) {
              "prometheus-exportarr-${service}-exporter" = {
                vpnConfinement = {
                  enable = true;
                  vpnNamespace = "wg";
                };
                # Add proper dependencies
                requires = [ "prometheus-exportarr-setup.service" ];
                after = [ "prometheus-exportarr-setup.service" ];
                serviceConfig = {
                  DynamicUser = true;
                  StateDirectory = "exportarr";
                  LoadCredential = "api-key:/var/lib/exportarr/${service}-api-key";
                  SupplementaryGroups = [ "exportarr" ];
                };
              };
            };
        in
          lib.mkMerge [
            (makeVpnExporterService "sonarr" "exportarr-sonarr")
            (makeVpnExporterService "radarr" "exportarr-radarr")
            (makeVpnExporterService "lidarr" "exportarr-lidarr")
            (makeVpnExporterService "readarr" "exportarr-readarr")
            (makeVpnExporterService "prowlarr" "exportarr-prowlarr")
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

      # API key setup service
      {
        prometheus-exportarr-setup = let
          # Define the list of services we depend on
          afterServices = 
            (optional (shouldEnableExporter "sonarr") "sonarr.service") ++
            (optional (shouldEnableExporter "radarr") "radarr.service") ++
            (optional (shouldEnableExporter "lidarr") "lidarr.service") ++
            (optional (shouldEnableExporter "readarr") "readarr.service") ++
            (optional (shouldEnableExporter "prowlarr") "prowlarr.service");
        in {
          description = "Setup Prometheus Exportarr API keys";
          before = (optional (shouldEnableExporter "sonarr") "prometheus-exportarr-sonarr-exporter.service") ++
                  (optional (shouldEnableExporter "radarr") "prometheus-exportarr-radarr-exporter.service") ++
                  (optional (shouldEnableExporter "lidarr") "prometheus-exportarr-lidarr-exporter.service") ++
                  (optional (shouldEnableExporter "readarr") "prometheus-exportarr-readarr-exporter.service") ++
                  (optional (shouldEnableExporter "prowlarr") "prometheus-exportarr-prowlarr-exporter.service");
          
          # Proper ordering
          after = afterServices;
          requires = afterServices;

          serviceConfig = {
            Type = "oneshot";
            RemainAfterExit = true;
            ExecStart = "${extractApiKeys}/bin/extract-monitoring-api-keys";
            User = "root";
            Group = "root";
          };
        };
        
        # Make all exportarr services depend on our setup service
        "prometheus-exportarr-sonarr-exporter" = mkIf (shouldEnableExporter "sonarr") {
          wants = [ "prometheus-exportarr-setup.service" ];
          after = [ "prometheus-exportarr-setup.service" ];
        };
        
        "prometheus-exportarr-radarr-exporter" = mkIf (shouldEnableExporter "radarr") {
          wants = [ "prometheus-exportarr-setup.service" ];
          after = [ "prometheus-exportarr-setup.service" ];
        };
        
        "prometheus-exportarr-lidarr-exporter" = mkIf (shouldEnableExporter "lidarr") {
          wants = [ "prometheus-exportarr-setup.service" ];
          after = [ "prometheus-exportarr-setup.service" ];
        };
        
        "prometheus-exportarr-readarr-exporter" = mkIf (shouldEnableExporter "readarr") {
          wants = [ "prometheus-exportarr-setup.service" ];
          after = [ "prometheus-exportarr-setup.service" ];
        };
        
        "prometheus-exportarr-prowlarr-exporter" = mkIf (shouldEnableExporter "prowlarr") {
          wants = [ "prometheus-exportarr-setup.service" ];
          after = [ "prometheus-exportarr-setup.service" ];
        };
      }
    ];

    # Create state directory with proper permissions
    systemd.tmpfiles.rules = [
      "d /var/lib/exportarr 0750 root root - -"
    ];
    
    # Add port mappings for VPN-confined exporters
    vpnNamespaces.wg = mkIf cfg.vpn.enable {
      portMappings = 
        (optional (shouldEnableExporter "sonarr" && isVpnConfined "sonarr") { from = 9707; to = 9707; }) ++
        (optional (shouldEnableExporter "radarr" && isVpnConfined "radarr") { from = 9708; to = 9708; }) ++
        (optional (shouldEnableExporter "lidarr" && isVpnConfined "lidarr") { from = 9709; to = 9709; }) ++
        (optional (shouldEnableExporter "readarr" && isVpnConfined "readarr") { from = 9710; to = 9710; }) ++
        (optional (shouldEnableExporter "prowlarr" && isVpnConfined "prowlarr") { from = 9711; to = 9711; }) ++
        [
          {
            from = 9586; # Default Wireguard exporter port
            to = 9586;
          }
        ];
    };
    
    # Open firewall ports for the exporters
    networking.firewall.allowedTCPPorts = mkIf (!cfg.vpn.enable) (
      (optional (shouldEnableExporter "sonarr") 9707) ++
      (optional (shouldEnableExporter "radarr") 9708) ++
      (optional (shouldEnableExporter "lidarr") 9709) ++
      (optional (shouldEnableExporter "readarr") 9710) ++
      (optional (shouldEnableExporter "prowlarr") 9711)
    );
  };
} 