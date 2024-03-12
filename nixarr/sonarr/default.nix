# TODO: Dir creation and file permissions in nix
{
  config,
  lib,
  ...
}:
with lib; let
  cfg = config.nixarr.sonarr;
  defaultPort = 8989;
  nixarr = config.nixarr;
in {
  options.nixarr.sonarr = {
    enable = mkOption {
      type = types.bool;
      default = false;
      description = "Enable the Sonarr service.";
    };

    stateDir = mkOption {
      type = types.path;
      default = "${nixarr.stateDir}/sonarr";
      defaultText = literalExpression ''"''${nixarr.stateDir}/sonarr"'';
      example = "/nixarr/.state/sonarr";
      description = "The state directory for Sonarr.";
    };

    openFirewall = mkOption {
      type = types.bool;
      defaultText = literalExpression ''!cfg.vpn.enable'';
      default = !cfg.vpn.enable;
      example = true;
      description = "Open firewall for Sonarr";
    };

    vpn.enable = mkOption {
      type = types.bool;
      default = false;
      example = true;
      description = ''
        **Required options:** [`nixarr.vpn.enable`](#nixarr.vpn.enable)

        Route Sonarr traffic through the VPN.
      '';
    };
  };

  config = mkIf cfg.enable {
    assertions = [
      {
        assertion = cfg.vpn.enable -> nixarr.vpn.enable;
        message = ''
          The nixarr.sonarr.vpn.enable option requires the
          nixarr.vpn.enable option to be set, but it was not.
        '';
      }
    ];

    services.sonarr = {
      enable = cfg.enable;
      user = "sonarr";
      group = "media";
      openFirewall = cfg.openFirewall;
      dataDir = cfg.stateDir;
    };

    # Enable and specify VPN namespace to confine service in.
    systemd.services.sonarr.vpnconfinement = mkIf cfg.vpn.enable {
      enable = true;
      vpnnamespace = "wg";
    };

    # Port mappings
    vpnnamespaces.wg = mkIf cfg.vpn.enable {
      portMappings = [{ from = defaultPort; to = defaultPort; }];
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
