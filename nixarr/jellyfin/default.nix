{
  config,
  lib,
  ...
}:
with lib; let
  cfg = config.nixarr.jellyfin;
  defaultPort = 8096;
  nixarr = config.nixarr;
  dnsServers = config.lib.vpn.dnsServers;
in {
  options.nixarr.jellyfin = {
    enable = mkEnableOption "Enable the Jellyfin service.";

    stateDir = mkOption {
      type = types.path;
      default = "${nixarr.stateDir}/nixarr/jellyfin";
      description = "The state directory for Jellyfin.";
    };

    vpn.enable = mkEnableOption ''
      Route Jellyfin traffic through the VPN. Requires that `nixarr.vpn`
      is configured
    '';

    expose = {
      enable = mkEnableOption ''
        Enable expose for Jellyfin, exposing the web service to the internet.
      '';

      upnp.enable = mkEnableOption ''
        Use UPNP to try to open ports 80 and 443 on your router.
      '';

      domainName = mkOption {
        type = types.nullOr types.str;
        default = null;
        description = "REQUIRED! The domain name to host Jellyfin on.";
      };

      acmeMail = mkOption {
        type = types.nullOr types.str;
        default = null;
        description = "REQUIRED! The ACME mail required for the letsencrypt bot.";
      };
    };
  };

  config =
    # TODO: this doesn't work. I don't know why :(
    #assert (!(cfg.vpn.enable && cfg.expose.enable)) || abort "vpn.enable not compatible with expose.enable.";
    #assert (cfg.expose.enable -> (cfg.expose.domainName != null && cfg.expose.acmeMail != null)) || abort "Both expose.domain and expose.acmeMail needs to be set if expose.enable is set.";
    mkIf cfg.enable
    {
      services.jellyfin = {
        enable    = cfg.enable;
        logDir    = "${cfg.stateDir}/log";
        cacheDir  = "${cfg.stateDir}/cache";
        dataDir   = "${cfg.stateDir}/data";
        configDir = "${cfg.stateDir}/config";
      };

      networking.firewall = mkIf cfg.expose.enable {
        allowedTCPPorts = [ 80 443 ];
      };

      util-nixarr.upnp = mkIf cfg.expose.upnp.enable {
        enable = true;
        openTcpPorts = [ 80 443 ];
      };

      services.nginx = mkIf (cfg.expose.enable || cfg.vpn.enable) {
        enable = true;

        recommendedTlsSettings = true;
        recommendedOptimisation = true;
        recommendedGzipSettings = true;

        virtualHosts."${builtins.replaceStrings ["\n"] [""] cfg.expose.domainName}" = mkIf cfg.expose.enable {
          enableACME = true;
          forceSSL = true;
          locations."/" = {
            recommendedProxySettings = true;
            proxyWebsockets = true;
            proxyPass = "http://127.0.0.1:${builtins.toString defaultPort}";
          };
        };

        virtualHosts."127.0.0.1:${builtins.toString defaultPort}" = mkIf cfg.vpn.enable {
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

      security.acme = mkIf cfg.expose.enable {
        acceptTerms = true;
        defaults.email = cfg.expose.acmeMail;
      };

      util-nixarr.vpnnamespace.portMappings = [
        (
          mkIf cfg.vpn.enable {
            From = defaultPort;
            To = defaultPort;
          }
        )
      ];

      containers.jellyfin = mkIf cfg.vpn.enable {
        autoStart = true;
        ephemeral = true;
        extraFlags = ["--network-namespace-path=/var/run/netns/wg"];

        bindMounts = {
          "${nixarr.mediaDir}/library".isReadOnly = false;
          "${cfg.stateDir}".isReadOnly = false;
        };

        config = {
          users.groups.jellyfin = {};
          users.users.jellyfin = {
            uid = lib.mkForce config.users.users.jellyfin.uid;
            isSystemUser = true;
            group = "jellyfin";
          };

          # Use systemd-resolved inside the container
          # Workaround for bug https://github.com/NixOS/nixpkgs/issues/162686
          networking.useHostResolvConf = lib.mkForce false;
          services.resolved.enable = true;
          networking.nameservers = dnsServers;

          services.jellyfin = {
            enable = true;
            logDir = "${cfg.stateDir}/log";
            cacheDir = "${cfg.stateDir}/cache";
            dataDir = "${cfg.stateDir}/data";
            configDir = "${cfg.stateDir}/config";
          };

          system.stateVersion = "23.11";
        };
      };
    };
}
