{
  config,
  lib,
  pkgs,
  ...
}:
with lib; let
  cfg = config.nixarr.jellyseerr;
  nixarr = config.nixarr;
  defaultPort = 5055;
in {
  imports = [
    ./jellyseerr-module
  ];

  options.nixarr.jellyseerr = {
    enable = mkOption {
      type = types.bool;
      default = false;
      example = true;
      description = ''
        Whether or not to enable the Jellyseerr service.
      '';
    };

    package = mkPackageOption pkgs "jellyseerr" {};

    stateDir = mkOption {
      type = types.path;
      default = "${nixarr.stateDir}/jellyseerr";
      defaultText = literalExpression ''"''${nixarr.stateDir}/jellyseerr"'';
      example = "/nixarr/.state/jellyseerr";
      description = ''
        The location of the state directory for the Jellyseerr service.

        > **Warning:** Setting this to any path, where the subpath is not
        > owned by root, will fail! For example:
        >
        > ```nix
        >   stateDir = /home/user/nixarr/.state/jellyseerr
        > ```
        >
        > Is not supported, because `/home/user` is owned by `user`.
      '';
    };

    port = mkOption {
      type = types.port;
      default = defaultPort;
      example = 12345;
      description = "Jellyseerr web-UI port.";
    };

    openFirewall = mkOption {
      type = types.bool;
      defaultText = literalExpression ''!nixarr.jellyseerr.vpn.enable'';
      default = !cfg.vpn.enable;
      example = true;
      description = "Open firewall for Jellyseerr";
    };

    vpn.enable = mkOption {
      type = types.bool;
      default = false;
      example = true;
      description = ''
        **Required options:** [`nixarr.vpn.enable`](#nixarr.vpn.enable)

        **Conflicting options:** [`nixarr.jellyseerr.expose.https.enable`](#nixarr.jellyseerr.expose.https.enable)

        Route Jellyseerr traffic through the VPN.
      '';
    };

    expose = {
      https = {
        enable = mkOption {
          type = types.bool;
          default = false;
          example = true;
          description = ''
            **Required options:**

            - [`nixarr.jellyseerr.expose.https.acmeMail`](#nixarr.jellyseerr.expose.https.acmemail)
            - [`nixarr.jellyseerr.expose.https.domainName`](#nixarr.jellyseerr.expose.https.domainname)

            **Conflicting options:** [`nixarr.jellyseerr.vpn.enable`](#nixarr.jellyseerr.vpn.enable)

            Expose the Jellyseerr web service to the internet with https support,
            allowing anyone to access it.

            > **Warning:** Do _not_ enable this without setting up Jellyseerr
            > authentication through localhost first!
          '';
        };

        upnp.enable = mkEnableOption "UPNP to try to open ports 80 and 443 on your router.";

        domainName = mkOption {
          type = types.nullOr types.str;
          default = null;
          example = "jellyseerr.example.com";
          description = "The domain name to host Jellyseerr on.";
        };

        acmeMail = mkOption {
          type = types.nullOr types.str;
          default = null;
          example = "mail@example.com";
          description = "The ACME mail required for the letsencrypt bot.";
        };
      };
    };
  };

  config = mkIf (nixarr.enable && cfg.enable) {
    assertions = [
      {
        assertion = cfg.vpn.enable -> nixarr.vpn.enable;
        message = ''
          The nixarr.jellyseerr.vpn.enable option requires the
          nixarr.vpn.enable option to be set, but it was not.
        '';
      }
      {
        assertion = !(cfg.vpn.enable && cfg.expose.https.enable);
        message = ''
          The nixarr.jellyseerr.vpn.enable option conflicts with the
          nixarr.jellyseerr.expose.https.enable option. You cannot set both.
        '';
      }
      {
        assertion =
          cfg.expose.https.enable
          -> (
            (cfg.expose.https.domainName != null)
            && (cfg.expose.https.acmeMail != null)
          );
        message = ''
          The nixarr.jellyseerr.expose.https.enable option requires the
          following options to be set, but one of them were not:

          - nixarr.jellyseerr.expose.https.domainName
          - nixarr.jellyseerr.expose.https.acmeMail
        '';
      }
    ];

    util-nixarr.services.jellyseerr = {
      enable = true;
      package = cfg.package;
      openFirewall = cfg.openFirewall;
      port = cfg.port;
      configDir = cfg.stateDir;
    };

    networking.firewall = mkIf cfg.expose.https.enable {
      allowedTCPPorts = [80 443];
    };

    util-nixarr.upnp = mkIf cfg.expose.https.upnp.enable {
      enable = true;
      openTcpPorts = [80 443];
    };

    services.nginx = mkMerge [
      (mkIf (cfg.expose.https.enable || cfg.vpn.enable) {
        enable = true;

        recommendedTlsSettings = true;
        recommendedOptimisation = true;
        recommendedGzipSettings = true;
      })
      (mkIf cfg.expose.https.enable {
        virtualHosts."${builtins.replaceStrings ["\n"] [""] cfg.expose.https.domainName}" = {
          enableACME = true;
          forceSSL = true;
          locations."/" = {
            recommendedProxySettings = true;
            proxyWebsockets = true;
            proxyPass = "http://127.0.0.1:${builtins.toString defaultPort}";
          };
        };
      })
      (mkIf cfg.vpn.enable {
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
      })
    ];

    security.acme = mkIf cfg.expose.https.enable {
      acceptTerms = true;
      defaults.email = cfg.expose.https.acmeMail;
    };

    # Enable and specify VPN namespace to confine service in.
    systemd.services.jellyseerr.vpnConfinement = mkIf cfg.vpn.enable {
      enable = true;
      vpnNamespace = "wg";
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
  };
}
