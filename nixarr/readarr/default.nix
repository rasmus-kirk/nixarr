{
  config,
  lib,
  ...
}:
with lib; let
  cfg = config.nixarr.readarr;
  nixarr = config.nixarr;
in {
  options.nixarr.readarr = {
    enable = mkEnableOption "Enable the Readarr service";

    stateDir = mkOption {
      type = types.path;
      default = "${nixarr.stateDir}/readarr";
      defaultText = literalExpression ''"''${nixarr.stateDir}/readarr"'';
      example = "/home/user/.local/share/nixarr/readarr";
      description = "The state directory for Readarr";
    };

    openFirewall = mkOption {
      type = types.bool;
      defaultText = literalExpression ''"''${nixarr.vpn.enable}"'';
      default = !cfg.vpn.enable;
      example = true;
      description = "Open firewall for Readarr";
    };

    vpn.enable = mkOption {
      type = types.bool;
      default = false;
      example = true;
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
      openFirewall = cfg.openFirewall;
      dataDir = cfg.stateDir;
    };

    # Enable and specify VPN namespace to confine service in.
    systemd.services.readarr.vpnconfinement = mkIf cfg.vpn.enable {
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
