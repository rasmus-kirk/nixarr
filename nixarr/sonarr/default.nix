{
  config,
  lib,
  pkgs,
  ...
}:
with lib; let
  cfg = config.nixarr.sonarr;
  globals = config.util-nixarr.globals;
  defaultPort = 8989;
  nixarr = config.nixarr;
in {
  options.nixarr.sonarr = {
    enable = mkOption {
      type = types.bool;
      default = false;
      example = true;
      description = ''
        Whether or not to enable the Sonarr service.
      '';
    };

    package = mkPackageOption pkgs "sonarr" {};

    stateDir = mkOption {
      type = types.path;
      default = "${nixarr.stateDir}/sonarr";
      defaultText = literalExpression ''"''${nixarr.stateDir}/sonarr"'';
      example = "/nixarr/.state/sonarr";
      description = ''
        The location of the state directory for the Sonarr service.

        > **Warning:** Setting this to any path, where the subpath is not
        > owned by root, will fail! For example:
        >
        > ```nix
        >   stateDir = /home/user/nixarr/.state/sonarr
        > ```
        >
        > Is not supported, because `/home/user` is owned by `user`.
      '';
    };

    openFirewall = mkOption {
      type = types.bool;
      defaultText = literalExpression ''!nixarr.sonarr.vpn.enable'';
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

  config = mkIf (nixarr.enable && cfg.enable) {
    assertions = [
      {
        assertion = cfg.vpn.enable -> nixarr.vpn.enable;
        message = ''
          The nixarr.sonarr.vpn.enable option requires the
          nixarr.vpn.enable option to be set, but it was not.
        '';
      }
    ];

    users = {
      groups.${globals.sonarr.group}.gid = globals.gids.${globals.sonarr.group};
      users.${globals.sonarr.user} = {
        isSystemUser = true;
        group = globals.sonarr.group;
        uid = globals.uids.${globals.sonarr.user};
      };
    };

    systemd.tmpfiles.rules = [
      "d '${nixarr.mediaDir}/library'        0775 ${globals.libraryOwner.user} ${globals.libraryOwner.group} - -"
      "d '${nixarr.mediaDir}/library/shows'  0775 ${globals.libraryOwner.user} ${globals.libraryOwner.group} - -"
    ];

    services.sonarr = {
      enable = cfg.enable;
      package = cfg.package;
      user = globals.sonarr.user;
      group = globals.sonarr.group;
      openFirewall = cfg.openFirewall;
      dataDir = cfg.stateDir;
    };

    systemd.services.sonarr = {
      preStart = mkIf nixarr.autosync (
        let
          configure-sonarr = pkgs.writeShellApplication {
            name = "configure-sonarr";

            runtimeInputs = with pkgs; [util-linux coreutils bash yq];

            text = ''
              cd ${cfg.stateDir}
              API_KEY=$(cat ${nixarr.stateDir}/api-key)
              if [ ! -f ./config.xml ]; then
                echo "<Config></Config>" > config.xml
              fi
              xq ".Config.ApiKey=\"$API_KEY\"" --in-place -x ./config.xml
            '';
          };
        in "${configure-sonarr}/bin/configure-sonarr"
      );

      wants = mkIf nixarr.autosync ["nixarr-api-key.service"];
      # Enable and specify VPN namespace to confine service in.
      vpnConfinement = mkIf cfg.vpn.enable {
        enable = true;
        vpnNamespace = "wg";
      };
    };

    # Port mappings
    vpnNamespaces.wg = mkIf cfg.vpn.enable {
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
