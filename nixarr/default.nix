{
  config,
  lib,
  ...
}:
with lib; let
  cfg = config.nixarr;
in {
  imports = [
    ./jellyfin
    ./radarr
    ./lidarr
    ./readarr
    ./sonarr
    ./prowlarr
    ./transmission
    ../util
  ];

  options.nixarr = {
    enable = mkOption {
      type = types.bool;
      default = false;
      description = ''
        Whether or not to enable the nixarr module. Has the following features:

        - **Run services through a VPN:** You can run any service that this module
          supports through a VPN, fx `nixarr.transmission.vpn.enable = true;`
        - **Automatic Directories, Users and Permissions:** The module automatically
          creates directories and users for your media library. It also sets sane
          permissions.
        - **State Management:** All services support state management and all state
          that they manage is located by default in `/data/.state/nixarr/*`
        - **Optional Automatic Port Forwarding:** This module has a UPNP support that
          lets services request ports from your router automatically, if you enable it.
      
        It is possible, _but not recommended_, to run the "*Arrs" behind a VPN,
        because it can cause rate limiting issues. Generally, you should use
        VPN on transmission and maybe jellyfin, depending on your setup.

        The following services are supported:

        - Jellyfin
        - Lidarr
        - Prowlarr
        - Radarr
        - Readarr
        - Sonarr
        - Transmission

        Remember to read the options.
      '';
    };

    mediaDir = mkOption {
      type = types.path;
      default = "/data/media";
      description = ''
        The location of the media directory for the services.
      '';
    };

    stateDir = mkOption {
      type = types.path;
      default = "/data/.state";
      description = ''
        The location of the state directory for the services.
      '';
    };

    vpn = {
      enable = mkOption {
        type = types.bool;
        default = false;
        description = ''
          **Required options:** [`nixarr.vpn.wgConf`](/options.html#nixarr.vpn.wgConf)

          Whether or not to enable VPN support for the services that nixarr
          supports.
        '';
      };

      wgConf = mkOption {
        type = types.nullOr types.path;
        default = null;
        description = "The path to the wireguard configuration file.";
      };

      dnsServers = mkOption {
        type = with types; nullOr (listOf str);
        default = null;
        description = ''
          Extra DNS servers for the VPN. If your wg config has a DNS field,
          then this should not be necessary.
        '';
        example = ["1.1.1.2"];
      };

      vpnTestService = {
        enable = mkEnableOption ''
          the vpn test service. Useful for testing DNS leaks or if the VPN
          port forwarding works correctly.
        '';

        port = mkOption {
          type = types.port;
          default = 12300;
          description = ''
            The port that the vpn test service listens to.
          '';
          example = 58403;
        };
      };

      openTcpPorts = mkOption {
        type = with types; listOf port;
        default = [];
        description = lib.mdDoc ''
          What TCP ports to allow traffic from. You might need this if you're
          port forwarding on your VPN provider and you're setting up services
          not covered in by this module that uses the VPN.
        '';
        example = [46382 38473];
      };

      openUdpPorts = mkOption {
        type = with types; listOf port;
        default = [];
        description = lib.mdDoc ''
          What UDP ports to allow traffic from. You might need this if you're
          port forwarding on your VPN provider and you're setting up services
          not covered in by this module that uses the VPN.
        '';
        example = [46382 38473];
      };
    };
  };

  config = mkIf cfg.enable {
    users.groups = {
      media.gid = 992;
      prowlarr = {};
      transmission = {};
      streamer = {};
      torrenter = {};
    };
    # TODO: This is BAD. But seems necessary when using containers.
    # The prefered solution is to just remove containerization.
    # Look at https://github.com/NixOS/nixpkgs/blob/master/nixos/modules/misc/ids.nix
    users.users = {
      streamer = {
        isSystemUser = true;
        uid = lib.mkForce 316;
      };
      sonarr = {
        isSystemUser = true;
        group = "media";
        uid = lib.mkForce 274;
      };
      radarr = {
        isSystemUser = true;
        group = "media";
        uid = lib.mkForce 275;
      };
      lidarr = {
        isSystemUser = true;
        group = "media";
        uid = lib.mkForce 306;
      };
      readarr = {
        isSystemUser = true;
        group = "media";
        uid = lib.mkForce 309;
      };
      torrenter = {
        isSystemUser = true;
        uid = lib.mkForce 70;
      };
      prowlarr = {
        isSystemUser = true;
        group = "prowlarr";
        uid = lib.mkForce 293;
      };
    };

    systemd.tmpfiles.rules = [
      # Media dirs
      "d '${cfg.mediaDir}'                        0775 root         media - -"
      "d '${cfg.mediaDir}/library'                0775 streamer     media - -"
      "d '${cfg.mediaDir}/library/shows'          0775 streamer     media - -"
      "d '${cfg.mediaDir}/library/movies'         0775 streamer     media - -"
      "d '${cfg.mediaDir}/library/music'          0775 streamer     media - -"
      "d '${cfg.mediaDir}/library/books'          0775 streamer     media - -"
      "d '${cfg.mediaDir}/torrents'               0755 torrenter    media - -"
      "d '${cfg.mediaDir}/torrents/.incomplete'   0755 torrenter    media - -"
      "d '${cfg.mediaDir}/torrents/.watch'        0755 torrenter    media - -"
      "d '${cfg.mediaDir}/torrents/manual'        0755 torrenter    media - -"
      "d '${cfg.mediaDir}/torrents/liadarr'       0755 torrenter    media - -"
      "d '${cfg.mediaDir}/torrents/radarr'        0755 torrenter    media - -"
      "d '${cfg.mediaDir}/torrents/sonarr'        0755 torrenter    media - -"
      "d '${cfg.mediaDir}/torrents/readarr'       0755 torrenter    media - -"
    ];

    util-nixarr.vpnnamespace = {
      enable = cfg.vpn.enable;
      accessibleFrom = [
        "192.168.1.0/24"
        "127.0.0.1"
      ];
      dnsServers = cfg.vpn.dnsServers;
      wireguardAddressPath = cfg.vpn.wgAddress;
      wireguardConfigFile = cfg.vpn.wgConf;
      vpnTestService = {
        enable = cfg.vpn.vpnTestService.enable;
        port = cfg.vpn.vpnTestService.port;
      };
      openTcpPorts = cfg.vpn.openTcpPorts;
      openUdpPorts = cfg.vpn.openUdpPorts;
    };
  };
}
