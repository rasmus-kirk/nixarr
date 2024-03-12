{
  config,
  lib,
  ...
}:
with lib; let
  cfg = config.nixarr.lidarr;
  nixarr = config.nixarr;
  defaultPort = 8686;
in {
  options.nixarr.lidarr = {
    enable = mkEnableOption "the Lidarr service.";

    stateDir = mkOption {
      type = types.path;
      default = "${nixarr.stateDir}/lidarr";
      defaultText = literalExpression ''"''${nixarr.stateDir}/lidarr"'';
      example = "/nixarr/.state/lidarr";
      description = ''
        The location of the state directory for the Lidarr service.

        **Warning:** Setting this to any path, where the subpath is not
        owned by root, will fail! For example:

        ```nix
          stateDir = /home/user/nixarr/.state/lidarr
        ```

        Is not supported, because `/home/user` is owned by `user`.
      '';
    };

    openFirewall = mkOption {
      type = types.bool;
      defaultText = literalExpression ''!nixarr.lidarr.vpn.enable'';
      default = !cfg.vpn.enable;
      example = true;
      description = "Open firewall for Lidarr";
    };

    vpn.enable = mkOption {
      type = types.bool;
      default = false;
      example = true;
      description = ''
        **Required options:** [`nixarr.vpn.enable`](#nixarr.vpn.enable)

        Route Lidarr traffic through the VPN.
      '';
    };
  };

  config = mkIf cfg.enable {
    assertions = [
      {
        assertion = cfg.vpn.enable -> nixarr.vpn.enable;
        message = ''
          The nixarr.lidarr.vpn.enable option requires the
          nixarr.vpn.enable option to be set, but it was not.
        '';
      }
    ];

    services.lidarr = {
      enable = cfg.enable;
      user = "lidarr";
      group = "media";
      openFirewall = cfg.openFirewall;
      dataDir = cfg.stateDir;
    };

    # Enable and specify VPN namespace to confine service in.
    systemd.services.lidarr.vpnconfinement = mkIf cfg.vpn.enable {
      enable = true;
      vpnnamespace = "wg";
    };

    # Port mappings
    # TODO: openports
    vpnnamespaces.wg = mkIf cfg.vpn.enable {
      portMappings = [
        {
          from = defaultPort;
          to = defaultPort;
        }
      ];
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
