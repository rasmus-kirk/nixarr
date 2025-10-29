{
  config,
  lib,
  pkgs,
  ...
}:
with lib; let
  cfg = config.nixarr.stash;
  globals = config.util-nixarr.globals;
  nixarr = config.nixarr;
  defaultPort = 9999;
in {
  options.nixarr.stash = {
    enable = mkOption {
      type = types.bool;
      default = false;
      example = true;
      description = ''
        Whether or not to enable the stash service.
      '';
    };

    package = mkPackageOption pkgs "stash" {};

    stateDir = mkOption {
      type = types.path;
      default = "${nixarr.stateDir}/stash";
      defaultText = literalExpression ''"''${nixarr.stateDir}/stash"'';
      example = "/nixarr/.state/stash";
      description = ''
        The location of the state directory for the stash service.

        > **Warning:** Setting this to any path, where the subpath is not
        > owned by root, will fail! For example:
        >
        > ```nix
        >   stateDir = /home/user/nixarr/.state/stash
        > ```
        >
        > Is not supported, because `/home/user` is owned by `user`.
      '';
    };

    openFirewall = mkOption {
      type = types.bool;
      defaultText = literalExpression ''!nixarr.stash.vpn.enable'';
      default = !cfg.vpn.enable;
      example = true;
      description = "Open firewall for stash";
    };

    port = mkOption {
      type = types.port;
      default = defaultPort;
      description = "Port for Stash to use.";
    };

    vpn.enable = mkOption {
      type = types.bool;
      default = false;
      example = true;
      description = ''
        **Required options:** [`nixarr.vpn.enable`](#nixarr.vpn.enable)

        Route stash traffic through the VPN.
      '';
    };
  };

  config = mkIf (nixarr.enable && cfg.enable) {
    assertions = [
      {
        assertion = cfg.vpn.enable -> nixarr.vpn.enable;
        message = ''
          The nixarr.stash.vpn.enable option requires the
          nixarr.vpn.enable option to be set, but it was not.
        '';
      }
    ];

    users = {
      groups.${globals.stash.group}.gid = globals.gids.${globals.stash.group};
      users.${globals.stash.user} = {
        isSystemUser = true;
        group = globals.stash.group;
        uid = globals.uids.${globals.stash.user};
      };
    };

    services.stash = {
      enable = cfg.enable;
      settings.port = cfg.port;
      package = cfg.package;
      user = globals.stash.user;
      group = globals.stash.group;
      openFirewall = cfg.openFirewall;
      dataDir = cfg.stateDir;
    };

    # Enable and specify VPN namespace to confine service in.
    systemd.services.stash.vpnConfinement = mkIf cfg.vpn.enable {
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
