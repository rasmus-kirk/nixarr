{
  config,
  lib,
  ...
}:
with lib; let
  cfg = config.nixarr.bazarr;
  nixarr = config.nixarr;
in {
  imports = [
    ./bazarr-module
  ];
  
  options.nixarr.bazarr = {
    enable = mkEnableOption "the bazarr service.";

    stateDir = mkOption {
      type = types.path;
      default = "${nixarr.stateDir}/bazarr";
      defaultText = literalExpression ''"''${nixarr.stateDir}/bazarr"'';
      example = "/home/user/.local/share/nixarr/bazarr";
      description = "The state directory for bazarr";
    };

    vpn.enable = mkOption {
      type = types.bool;
      default = false;
      example = true;
      description = ''
        **Required options:** [`nixarr.vpn.enable`](#nixarr.vpn.enable)

        Route Bazarr traffic through the VPN.
      '';
    };
  };

  config = mkIf cfg.enable {
    assertions = [
      {
        assertion = cfg.vpn.enable -> nixarr.vpn.enable;
        message = ''
          The nixarr.bazarr.vpn.enable option requires the
          nixarr.vpn.enable option to be set, but it was not.
        '';
      }
    ];

    util-nixarr.services.bazarr = {
      enable = cfg.enable;
      user = "bazarr";
      group = "media";
      dataDir = cfg.stateDir;
    };

    # Enable and specify VPN namespace to confine service in.
    systemd.services.bazarr.vpnconfinement = mkIf cfg.vpn.enable {
      enable = true;
      vpnnamespace = "wg";
    };

    # Port mappings
    # TODO: openports
    vpnnamespaces.wg = mkIf cfg.vpn.enable {
      portMappings = [{ from = config.bazarr.listenPort; to = config.bazarr.listenPort; }];
    };

    services.nginx = mkIf cfg.vpn.enable {
      enable = true;

      recommendedTlsSettings = true;
      recommendedOptimisation = true;
      recommendedGzipSettings = true;

      virtualHosts."127.0.0.1:${builtins.toString config.bazarr.listenPort}" = {
        listen = [
          {
            addr = "0.0.0.0";
            port = config.bazarr.listenPort;
          }
        ];
        locations."/" = {
          recommendedProxySettings = true;
          proxyWebsockets = true;
          proxyPass = "http://192.168.15.1:${builtins.toString config.bazarr.listenPort}";
        };
      };
    };
  };
}
