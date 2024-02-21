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
        Enable nginx for Jellyfin, exposing the web service to the internet.
      '';

      upnp = mkOption {
        type = types.bool;
        default = false;
        description = "Use UPNP to try to open ports 80 and 443 on your router.";
      };

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
    #assert (!(cfg.vpn.enable && cfg.nginx.enable)) || abort "vpn.enable not compatible with nginx.enable.";
    #assert (cfg.nginx.enable -> (cfg.nginx.domainName != null && cfg.nginx.acmeMail != null)) || abort "Both nginx.domain and nginx.acmeMail needs to be set if nginx.enable is set.";
    mkIf cfg.enable
    {
      services.jellyfin = {
        enable    = cfg.enable;
        logDir    = "${cfg.stateDir}/log";
        cacheDir  = "${cfg.stateDir}/cache";
        dataDir   = "${cfg.stateDir}/data";
        configDir = "${cfg.stateDir}/config";
      };

      networking.firewall = mkIf cfg.nginx.enable {
        allowedTCPPorts = [ 80 443 ];
      };

      util.upnp = mkIf cfg.nginx.upnp.enable {
        enable = true;
        openTcpPorts = [ 80 443 ];
      };

      services.nginx = mkIf (cfg.nginx.enable || cfg.vpn.enable) {
        enable = true;

        recommendedTlsSettings = true;
        recommendedOptimisation = true;
        recommendedGzipSettings = true;

        virtualHosts."${builtins.replaceStrings ["\n"] [""] cfg.nginx.domainName}" = mkIf cfg.nginx.enable {
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

      security.acme = mkIf cfg.nginx.enable {
        acceptTerms = true;
        defaults.email = cfg.nginx.acmeMail;
      };

      util.vpnnamespace.portMappings = [
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
