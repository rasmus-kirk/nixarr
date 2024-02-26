# TODO: Dir creation and file permissions in nix
{
  config,
  lib,
  ...
}:
with lib; let
  cfg = config.nixarr.sonarr;
  defaultPort = 8989;
  nixarr = config.nixarr;
  dnsServers = config.lib.vpn.dnsServers;
in {
  options.nixarr.sonarr = {
    enable = mkOption {
      type = types.bool;
      default = false;
      description = "Enable the Sonarr service.";
    };

    stateDir = mkOption {
      type = types.path;
      default = "${nixarr.stateDir}/sonarr";
      description = "The state directory for Sonarr.";
    };

    vpn.enable = mkEnableOption ''
      Route Readarr traffic through the VPN. Requires that `nixarr.vpn`
      is configured.
    '';
  };

  config = mkIf cfg.enable {
    systemd.tmpfiles.rules = [
      "d '${cfg.stateDir}' 0700 sonarr root - -"
    ];

    services.sonarr = mkIf (!cfg.vpn.enable) {
      enable = cfg.enable;
      user = "sonarr";
      group = "media";
      dataDir = cfg.stateDir;
    };

    util-nixarr.vpnnamespace.portMappings = [
      (mkIf cfg.vpn.enable {
        From = defaultPort;
        To = defaultPort;
      })
    ];

    systemd.services."container@sonarr" = mkIf cfg.vpn.enable {
      requires = ["wg.service"];
    };

    containers.sonarr = mkIf cfg.vpn.enable {
      autoStart = true;
      ephemeral = true;
      extraFlags = ["--network-namespace-path=/var/run/netns/wg"];

      bindMounts = {
        "${nixarr.mediaDir}".isReadOnly = false;
        "${cfg.stateDir}".isReadOnly = false;
      };

      config = {
        users.groups.media = {
          gid = config.users.groups.media.gid;
        };
        users.users.sonarr = {
          uid = lib.mkForce config.users.users.sonarr.uid;
          isSystemUser = true;
          group = "media";
        };

        # Use systemd-resolved inside the container
        # Workaround for bug https://github.com/NixOS/nixpkgs/issues/162686
        networking.useHostResolvConf = lib.mkForce false;
        services.resolved.enable = true;
        networking.nameservers = dnsServers;

        users.groups.media = {};

        services.sonarr = {
          enable = cfg.enable;
          group = "media";
          dataDir = cfg.stateDir;
        };

        system.stateVersion = "23.11";
      };
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
