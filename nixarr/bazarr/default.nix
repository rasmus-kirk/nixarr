{
  config,
  lib,
  pkgs,
  ...
}:
with lib; let
  cfg = config.nixarr.bazarr;
  globals = config.util-nixarr.globals;
  port = 6767;
  nixarr = config.nixarr;
in {
  options.nixarr.bazarr = {
    enable = mkOption {
      type = types.bool;
      default = false;
      example = true;
      description = ''
        Whether or not to enable the Bazarr service.
      '';
    };

    package = mkPackageOption pkgs "bazarr" {};

    port = mkOption {
      type = types.port;
      default = port;
      description = "Port for Bazarr to use.";
    };

    stateDir = mkOption {
      type = types.path;
      default = "${nixarr.stateDir}/bazarr";
      defaultText = literalExpression ''"''${nixarr.stateDir}/bazarr"'';
      example = "/nixarr/.state/bazarr";
      description = ''
        The location of the state directory for the Bazarr service.

        > **Warning:** Setting this to any path, where the subpath is not
        > owned by root, will fail! For example:
        >
        > ```nix
        >   stateDir = /home/user/nixarr/.state/bazarr
        > ```
        >
        > Is not supported, because `/home/user` is owned by `user`.
      '';
    };

    openFirewall = mkOption {
      type = types.bool;
      defaultText = literalExpression ''!nixarr.bazarr.vpn.enable'';
      default = !cfg.vpn.enable;
      example = true;
      description = "Open firewall for Bazarr";
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

    integrations = {
      sonarr = mkOption {
        type = types.bool;
        default = nixarr.autosync && nixarr.sonarr.enable;
      };
      radarr = mkOption {
        type = types.bool;
        default = nixarr.autosync && nixarr.sonarr.enable;
      };
    };
  };

  config = mkIf (nixarr.enable && cfg.enable) {
    assertions = [
      {
        assertion = cfg.vpn.enable -> nixarr.vpn.enable;
        message = ''
          The nixarr.bazarr.vpn.enable option requires the
          nixarr.vpn.enable option to be set, but it was not.
        '';
      }
    ];

    nixarr.sonarr.set-api-key = mkIf cfg.integrations.sonarr true;
    nixarr.radarr.set-api-key = mkIf cfg.integrations.radarr true;

    systemd.tmpfiles.rules = [
      "d '${cfg.stateDir}' 0700 ${globals.bazarr.user} root - -"
    ];

    systemd.services.bazarr = {
      description = "bazarr";
      after = ["network.target"];
      wants = mkIf nixarr.autosync ["nixarr-api-key.service"];
      wantedBy = ["multi-user.target"];

      preStart = let
        configure-bazarr = pkgs.writeShellApplication {
          name = "configure-bazarr";

          runtimeInputs = with pkgs; [util-linux coreutils bash yq];

          text = ''
            cd ${cfg.stateDir}
            mkdir -p config
            API_KEY=$(cat ${nixarr.api-key-location-internal})
            if [ ! -f ./config/config.yaml ]; then
              echo "---" > ./config/config.yaml
            fi
            ${
              if cfg.integrations.radarr
              then ''
                yq ".radarr.apikey=\"$API_KEY\"" --in-place -Y ./config/config.yaml
                yq ".radarr.ip=\"localhost\"" --in-place -Y ./config/config.yaml
                yq ".radarr.port=\"${builtins.toString nixarr.radarr.port}\"" --in-place -Y ./config/config.yaml
                yq ".general.use_radarr=\"true\"" --in-place -Y ./config/config.yaml
              ''
              else ""
            }
            ${
              if cfg.integrations.sonarr
              then ''
                yq ".sonarr.apikey=\"$API_KEY\"" --in-place -Y ./config/config.yaml
                yq ".sonarr.ip=\"localhost\"" --in-place -Y ./config/config.yaml
                yq ".sonarr.port=\"8989\"" --in-place -Y ./config/config.yaml
                yq ".general.use_sonarr=\"true\"" --in-place -Y ./config/config.yaml
              ''
              else ""
            }
          '';
        };
      in "${configure-bazarr}/bin/configure-bazarr";

      serviceConfig = {
        Type = "simple";
        User = globals.bazarr.user;
        Group = globals.bazarr.group;
        SyslogIdentifier = "bazarr";
        ExecStart = pkgs.writeShellScript "start-bazarr" ''
          ${pkgs.bazarr}/bin/bazarr \
            --config '${cfg.stateDir}' \
            --port ${toString cfg.port} \
            --no-update True
        '';
        Restart = "on-failure";
      };
    };

    networking.firewall = mkIf cfg.openFirewall {
      allowedTCPPorts = [cfg.port];
    };

    users = {
      groups.${globals.bazarr.group}.gid = globals.gids.${globals.bazarr.group};
      users.${globals.bazarr.user} = {
        isSystemUser = true;
        group = globals.bazarr.group;
        uid = globals.uids.${globals.bazarr.user};
      };
    };

    # Enable and specify VPN namespace to confine service in.
    systemd.services.bazarr.vpnConfinement = mkIf cfg.vpn.enable {
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
