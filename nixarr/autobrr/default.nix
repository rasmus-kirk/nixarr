{
  config,
  lib,
  pkgs,
  ...
}:
with lib; let
  cfg = config.nixarr.autobrr;
  globals = config.util-nixarr.globals;
  nixarr = config.nixarr;

  # Define config format
  configFormat = pkgs.formats.toml {};

  # Helper function to determine if metrics should be enabled
  metricsEnabled = nixarr.exporters.enable && (cfg.exporter.enable == null || cfg.exporter.enable);

  # Build the final settings without using mkMerge/mkIf directly
  finalSettings =
    # Start with user settings
    cfg.settings
    //
    # Ensure host is 0.0.0.0 by default, and force it when VPN is enabled
    (
      if (!(cfg.settings ? host) || cfg.vpn.enable)
      then {host = "0.0.0.0";}
      else {}
    )
    //
    # Add metrics if enabled - use top-level keys as per autobrr docs
    (
      if metricsEnabled
      then {
        metricsEnabled = true;
        metricsHost = "0.0.0.0";
        metricsPort = cfg.exporter.port;
      }
      else {}
    );

  # Generate the template from the evaluated settings
  configTemplate = configFormat.generate "autobrr.toml" finalSettings;
in {
  options.nixarr.autobrr = {
    enable = mkOption {
      type = types.bool;
      default = false;
      example = true;
      description = ''
        Whether or not to enable the Autobrr service.

        **Required options:** [`nixarr.enable`](#nixarr.enable)
      '';
    };

    package = mkPackageOption pkgs "autobrr" {};

    openFirewall = mkOption {
      type = types.bool;
      defaultText = literalExpression ''!nixarr.autobrr.vpn.enable'';
      default = !cfg.vpn.enable;
      example = true;
      description = "Open firewall for the Autobrr port.";
    };

    vpn.enable = mkOption {
      type = types.bool;
      default = false;
      example = true;
      description = ''
        **Required options:** [`nixarr.vpn.enable`](#nixarr.vpn.enable)

        Route Autobrr traffic through the VPN.
      '';
    };

    settings = lib.mkOption {
      type = lib.types.submodule {freeformType = configFormat.type;};
      default = {
        host = "0.0.0.0";
        port = 7474;
        checkForUpdates = false;
      };
      example = {
        logLevel = "DEBUG";
      };
      description = ''
        Autobrr configuration options.

        See https://autobrr.com/configuration/autobrr for more information.

        `sessionSecret` is automatically generated upon first installation and will be overridden.
        This is done to ensure that the secret is not hard-coded in the configuration file.
        The actual secret file is generated in the systemd service at `${cfg.stateDir}/session-secret`.
      '';
    };

    stateDir = mkOption {
      type = types.path;
      default = "${nixarr.stateDir}/autobrr";
      defaultText = literalExpression ''"''${nixarr.stateDir}/autobrr"'';
      example = "/nixarr/.state/autobrr";
      description = "The location of the state directory for the Autobrr service.";
    };

    exporter = {
      enable = mkOption {
        type = types.nullOr types.bool;
        default = null;
        example = true;
        description = ''
          Whether to enable the Prometheus metrics exporter for Autobrr.
          If null, follows the global nixarr.exporters.enable setting.
        '';
      };

      port = mkOption {
        type = types.port;
        default = 9712;
        example = 9712;
        description = "Port for the Prometheus metrics exporter.";
      };
    };
  };

  config = mkIf cfg.enable {
    assertions = [
      {
        assertion = cfg.vpn.enable -> nixarr.vpn.enable;
        message = ''
          The nixarr.autobrr.vpn.enable option requires the
          nixarr.vpn.enable option to be set, but it was not.
        '';
      }
      {
        assertion = cfg.enable -> nixarr.enable;
        message = ''
          The nixarr.autobrr.enable option requires the nixarr.enable
          option to be set, but it was not.
        '';
      }
    ];

    users = {
      groups.${globals.autobrr.group}.gid = globals.gids.${globals.autobrr.group};
      users.${globals.autobrr.user} = {
        isSystemUser = true;
        group = globals.autobrr.group;
        uid = globals.uids.${globals.autobrr.user};
      };
    };

    # Create state directory with proper permissions
    systemd.tmpfiles.rules = [
      "d '${cfg.stateDir}' 0700 ${globals.autobrr.user} root - -"
    ];

    # Configure the autobrr service
    services.autobrr = {
      enable = true;
      package = cfg.package;
      # We need to provide a secretFile even though we're handling it ourselves
      # The actual secret file is generated in the systemd service at ${cfg.stateDir}/session-secret
      secretFile = "/dev/null"; # This is a placeholder that won't be used
      settings = finalSettings;
    };

    # Override the autobrr service to use our state directory and session secret handling
    systemd.services.autobrr = {
      description = "Autobrr";
      after = ["syslog.target" "network-online.target"];
      wants = ["network-online.target"];
      wantedBy = ["multi-user.target"];
      path = [pkgs.openssl pkgs.dasel];

      serviceConfig = {
        Type = "simple";
        User = globals.autobrr.user;
        Group = globals.autobrr.group;
        UMask = 066;
        DynamicUser = lib.mkForce false;
        # disable SecretFilec
        LoadCredential = lib.mkForce null;
        # disable state directory
        StateDirectory = lib.mkForce null;
        ExecStartPre = lib.mkForce (pkgs.writeShellScript "autobrr-config-prep" ''
          # Generate session secret if it doesn't exist
          SESSION_SECRET_FILE="${cfg.stateDir}/session-secret"
          if [ ! -f "$SESSION_SECRET_FILE" ]; then
            openssl rand -base64 32 > "$SESSION_SECRET_FILE"
            chmod 600 "$SESSION_SECRET_FILE"
          fi

          # Create config with session secret
          SESSION_SECRET=$(cat "$SESSION_SECRET_FILE")
          cp '${configTemplate}' "${cfg.stateDir}/config.toml"
          chmod 600 "${cfg.stateDir}/config.toml"
          ${pkgs.dasel}/bin/dasel put -f "${cfg.stateDir}/config.toml" -v "$SESSION_SECRET" -o "${cfg.stateDir}/config.toml" "sessionSecret"
        '');
        ExecStart = lib.mkForce "${lib.getExe cfg.package} --config ${cfg.stateDir}";
        Restart = "on-failure";
      };

      # Enable and specify VPN namespace to confine service in
      vpnConfinement = mkIf cfg.vpn.enable {
        enable = true;
        vpnNamespace = "wg";
      };
    };

    # Port mappings for VPN
    vpnNamespaces.wg = mkIf cfg.vpn.enable {
      portMappings = [
        {
          from = cfg.settings.port;
          to = cfg.settings.port;
        }
        # Add mapping for metrics port if enabled
        (mkIf metricsEnabled {
          from = cfg.exporter.port;
          to = cfg.exporter.port;
        })
      ];
    };

    # Nginx proxy for VPN-confined service
    services.nginx = mkIf cfg.vpn.enable {
      enable = true;
      recommendedTlsSettings = true;
      recommendedOptimisation = true;
      recommendedGzipSettings = true;

      virtualHosts = {
        # Main service proxy
        "127.0.0.1:${builtins.toString cfg.settings.port}" = {
          listen = [
            {
              addr = "0.0.0.0";
              port = cfg.settings.port;
            }
          ];
          locations."/" = {
            recommendedProxySettings = true;
            proxyWebsockets = true;
            proxyPass = "http://192.168.15.1:${builtins.toString cfg.settings.port}";
          };
        };

        # Metrics endpoint proxy (only if metrics are enabled)
        "127.0.0.1:${builtins.toString cfg.exporter.port}" = mkIf metricsEnabled {
          listen = [
            {
              addr = "0.0.0.0";
              port = cfg.exporter.port;
            }
          ];
          locations."/" = {
            recommendedProxySettings = true;
            proxyPass = "http://192.168.15.1:${builtins.toString cfg.exporter.port}";
          };
        };
      };
    };

    # Open firewall ports if needed
    networking.firewall = mkIf cfg.openFirewall {
      allowedTCPPorts = [cfg.settings.port cfg.exporter.port];
    };
  };
}
