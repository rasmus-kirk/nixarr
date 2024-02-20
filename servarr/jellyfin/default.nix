{
  config,
  lib,
  ...
}:
with lib; let
  cfg = config.kirk.servarr.jellyfin;
  defaultPort = 8096;
  servarr = config.kirk.servarr;
in {
  options.kirk.servarr.jellyfin = {
    enable = mkOption {
      type = types.bool;
      default = false;
      description = lib.mdDoc "enable jellyfin";
    };

    stateDir = mkOption {
      type = types.path;
      default = "${servarr.stateDir}/servarr/jellyfin";
      description = lib.mdDoc "The state directory for jellyfin";
    };

    useVpn = mkOption {
      type = types.bool;
      default = false;
      description = lib.mdDoc "Use VPN with prowlarr";
    };

    nginx = {
      enable = mkEnableOption "Enable nginx for jellyfin";

      domainName = mkOption {
        type = types.nullOr types.str;
        default = null;
        description = "REQUIRED! The domain name to host jellyfin on.";
      };

      acmeMail = mkOption {
        type = types.nullOr types.str;
        default = null;
        description = "REQUIRED! The ACME mail.";
      };
    };
  };

  config = 
    #assert (!(cfg.useVpn && cfg.nginx.enable)) || abort "useVpn not compatible with nginx.enable.";
    #assert (cfg.nginx.enable -> (cfg.nginx.domainName != null && cfg.nginx.acmeMail != null)) || abort "Both nginx.domain and nginx.acmeMail needs to be set if nginx.enable is set.";
    mkIf cfg.enable 
  {
    services.jellyfin.enable = cfg.enable;

    networking.firewall.allowedTCPPorts = if cfg.nginx.enable then [ 
      80 # http
      443 # https
    ] else [];

    services.nginx = mkIf (cfg.nginx.enable || cfg.useVpn) {
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

      virtualHosts."127.0.0.1:${builtins.toString defaultPort}" = mkIf cfg.useVpn {
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

    kirk.vpnnamespace.portMappings = [(
      mkIf cfg.useVpn {
        From = defaultPort;
        To = defaultPort;
      }
    )];

    containers.jellyfin = mkIf cfg.useVpn {
      autoStart = true;
      ephemeral = true;
      extraFlags = [ "--network-namespace-path=/var/run/netns/wg" ];

      bindMounts = {
        "${servarr.mediaDir}/library".isReadOnly = false;
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
          group = "jellyfin";
          dataDir = "${cfg.stateDir}";
        };

        system.stateVersion = "23.11";
      };
    };
  };
}
