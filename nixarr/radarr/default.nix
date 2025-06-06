{
  config,
  lib,
  pkgs,
  ...
}:
with lib; let
  cfg = config.nixarr.radarr;
  globals = config.util-nixarr.globals;
  port = 7878;
  nixarr = config.nixarr;
in {
  options.nixarr.radarr = {
    enable = mkOption {
      type = types.bool;
      default = false;
      example = true;
      description = ''
        Whether or not to enable the Radarr service.
      '';
    };

    package = mkPackageOption pkgs "radarr" {};

    port = mkOption {
      type = types.port;
      default = port;
      description = "Port for Radarr to use.";
    };

    stateDir = mkOption {
      type = types.path;
      default = "${nixarr.stateDir}/radarr";
      defaultText = literalExpression ''"''${nixarr.stateDir}/radarr"'';
      example = "/nixarr/.state/radarr";
      description = ''
        The location of the state directory for the Radarr service.

        > **Warning:** Setting this to any path, where the subpath is not
        > owned by root, will fail! For example:
        >
        > ```nix
        >   stateDir = /home/user/nixarr/.state/radarr
        > ```
        >
        > Is not supported, because `/home/user` is owned by `user`.
      '';
    };

    openFirewall = mkOption {
      type = types.bool;
      defaultText = literalExpression ''!nixarr.radarr.vpn.enable'';
      default = !cfg.vpn.enable;
      example = true;
      description = "Open firewall for Radarr";
    };

    vpn.enable = mkOption {
      type = types.bool;
      default = false;
      example = true;
      description = ''
        **Required options:** [`nixarr.vpn.enable`](#nixarr.vpn.enable)

        Route Radarr traffic through the VPN.
      '';
    };
  };

  config = mkIf (nixarr.enable && cfg.enable) {
    assertions = [
      {
        assertion = cfg.vpn.enable -> nixarr.vpn.enable;
        message = ''
          The nixarr.radarr.vpn.enable option requires the
          nixarr.vpn.enable option to be set, but it was not.
        '';
      }
    ];

    systemd.tmpfiles.rules = [
      "d '${nixarr.mediaDir}/library'        0775 ${globals.libraryOwner.user} ${globals.libraryOwner.group} - -"
      "d '${nixarr.mediaDir}/library/movies' 0775 ${globals.libraryOwner.user} ${globals.libraryOwner.group} - -"
    ];

    users = {
      groups.${globals.radarr.group}.gid = globals.gids.${globals.radarr.group};
      users.${globals.radarr.user} = {
        isSystemUser = true;
        group = globals.radarr.group;
        uid = globals.uids.${globals.radarr.user};
      };
    };

    services.radarr = {
      enable = cfg.enable;
      package = cfg.package;
      user = globals.radarr.user;
      group = globals.radarr.group;
      settings.server.port = cfg.port;
      openFirewall = cfg.openFirewall;
      dataDir = cfg.stateDir;
    };

    # Enable and specify VPN namespace to confine service in.
    systemd.services.radarr.vpnConfinement = mkIf cfg.vpn.enable {
      enable = true;
      vpnNamespace = "wg";
    };

    # Port mappings
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
