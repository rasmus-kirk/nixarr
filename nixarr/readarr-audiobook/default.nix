{
  config,
  lib,
  pkgs,
  ...
}:
with lib; let
  cfg = config.nixarr.readarr-audiobook;
  globals = config.util-nixarr.globals;
  nixarr = config.nixarr;
  port = 9494;
in {
  options.nixarr.readarr-audiobook = {
    enable = mkOption {
      type = types.bool;
      default = false;
      example = true;
      description = ''
        Whether or not to enable the Readarr Audiobook service. This has
        a seperate service since running two instances is the standard
        way of being able to query both ebooks and audiobooks.
      '';
    };

    package = mkPackageOption pkgs "readarr" {};

    port = mkOption {
      type = types.port;
      default = port;
      description = "Port for Readarr Audiobook to use.";
    };

    stateDir = mkOption {
      type = types.path;
      default = "${nixarr.stateDir}/readarr-audiobook";
      defaultText = literalExpression ''"''${nixarr.stateDir}/readarr-audiobook"'';
      example = "/nixarr/.state/readarr-audiobook";
      description = ''
        The location of the state directory for the Readarr Audiobook service.

        > **Warning:** Setting this to any path, where the subpath is not
        > owned by root, will fail! For example:
        >
        > ```nix
        >   stateDir = /home/user/nixarr/.state/readarr-audiobook
        > ```
        >
        > Is not supported, because `/home/user` is owned by `user`.
      '';
    };

    openFirewall = mkOption {
      type = types.bool;
      defaultText = literalExpression ''!nixarr.readarr-audiobook.vpn.enable'';
      default = !cfg.vpn.enable;
      example = true;
      description = "Open firewall for Readarr Audiobook";
    };

    vpn.enable = mkOption {
      type = types.bool;
      default = false;
      example = true;
      description = ''
        **Required options:** [`nixarr.vpn.enable`](#nixarr.vpn.enable)

        Route Readarr Audiobook traffic through the VPN.
      '';
    };
  };

  config = mkIf (nixarr.enable && cfg.enable) {
    assertions = [
      {
        assertion = cfg.vpn.enable -> nixarr.vpn.enable;
        message = ''
          The nixarr.readarr-audiobook.vpn.enable option requires the
          nixarr.vpn.enable option to be set, but it was not.
        '';
      }
    ];

    users = {
      groups.${globals.readarr-audiobook.group}.gid = globals.gids.${globals.readarr-audiobook.group};
      users.${globals.readarr-audiobook.user} = {
        isSystemUser = true;
        group = globals.readarr-audiobook.group;
        uid = globals.uids.${globals.readarr-audiobook.user};
      };
    };

    systemd.tmpfiles.rules = [
      "d '${cfg.stateDir}' 0700 ${globals.readarr-audiobook.user} root - -"

      "d '${nixarr.mediaDir}/library'             0775 ${globals.libraryOwner.user} ${globals.libraryOwner.group} - -"
      "d '${nixarr.mediaDir}/library/audiobooks'  0775 ${globals.libraryOwner.user} ${globals.libraryOwner.group} - -"
    ];

    systemd.services.readarr-audiobook = {
      description = "Readarr-Audiobook";
      after = ["network.target"];
      wantedBy = ["multi-user.target"];
      environment.READARR__SERVER__PORT = builtins.toString cfg.port;

      serviceConfig = {
        Type = "simple";
        User = globals.readarr-audiobook.user;
        Group = globals.readarr-audiobook.group;
        ExecStart = "${lib.getExe cfg.package} -nobrowser -data=${cfg.stateDir}";
        Restart = "on-failure";
      };
    };

    networking.firewall = mkIf cfg.openFirewall {
      allowedTCPPorts = [cfg.port];
    };

    # Enable and specify VPN namespace to confine service in.
    systemd.services.readarr-audiobook.vpnConfinement = mkIf cfg.vpn.enable {
      enable = true;
      vpnNamespace = "wg";
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
