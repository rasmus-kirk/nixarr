{
  config,
  lib,
  ...
}:
with lib; let
  cfg = config.kirk.servarr;
in {
  imports = [
    ./jellyfin
    ./radarr
    ./lidarr
    ./readarr
    ./sonarr
    ./prowlarr
    ./transmission
  ];
  
  options.kirk.servarr = {
    enable = mkEnableOption ''
      My servarr setup. Lets you host the servarr services optionally
      through a VPN. It is possible, BUT NOT RECOMENDED, to have
      prowlarr/sonarr/radarr/readarr/lidarr behind a VPN. Generally, you
      should use VPN on transmission and maybe jellyfin, depending on your
      setup. Also sets permissions and creates folders.

      - Jellyfin
      - Lidarr
      - Prowlarr
      - Radarr
      - Readarr
      - Sonarr
      - Transmission

      Remember to read the options.
    '';

    mediaUsers = mkOption {
      type = with types; listOf str;
      default = [];
      description = "Extra users to add the the media group, giving access to the media directory. You probably want to add your own user here.";
    };

    mediaDir = mkOption {
      type = types.path;
      default = "/data/media";
      description = "The location of the media directory for the services.";
    };

    stateDir = mkOption {
      type = types.path;
      default = "/data/.state";
      description = "The location of the state directory for the services.";
    };

    upnp.enable = mkEnableOption "Enable automatic port forwarding using UPNP.";

    vpn = {
      enable = mkEnableOption ''Enable vpn'';

      wgConf = mkOption {
        type = types.nullOr types.path;
        default = null;
        description = "REQUIRED! The path to the wireguard configuration file.";
      };

      dnsServers = mkOption {
        type = with types; nullOr (listOf str);
        default = null;
        description = lib.mdDoc ''
          Extra DNS servers for the VPN. If your wg config has a DNS field,
          then this should not be necessary.
        '';
        example = [ "1.1.1.2" ];
      };

      vpnTestService = {
        enable = mkEnableOption "Enable the vpn test service.";

        port = mkOption {
          type = types.port;
          default = 12300;
          description = lib.mdDoc ''
            The port that the vpn test service listens to.
          '';
          example = 58403;
        };
      };

      openTcpPorts = mkOption {
        type = with types; listOf port;
        default = [];
        description = lib.mdDoc ''
          What TCP ports to allow incoming traffic from. You might need this
          if you're port forwarding on your VPN provider and you're setting
          up services that is not covered in by this module.
        '';
        example = [ 46382 38473 ];
      };

      openUdpPorts = mkOption {
        type = with types; listOf port;
        default = [];
        description = lib.mdDoc ''
          What UDP ports to allow incoming traffic from. You might need this
          if you're port forwarding on your VPN provider and you're setting
          up services that is not covered in by this module.
        '';
        example = [ 46382 38473 ];
      };
    };
  };

  config = mkIf cfg.enable {
    users.groups = {
      media = {
        members = cfg.mediaUsers;
        gid = 992;
      };
      prowlarr = {};
      transmission = {};
      jellyfin = {};
    };
    # TODO: This is BAD. But seems necessary when using containers.
    # The prefered solution is to just remove containerization.
    # Look at https://github.com/NixOS/nixpkgs/blob/master/nixos/modules/misc/ids.nix
    users.users = {
      jellyfin = {
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
      transmission = {
        isSystemUser = true;
        group = "transmission";
        uid = lib.mkForce 70;
      };
      prowlarr = {
        isSystemUser = true;
        group = "prowlarr";
        uid = lib.mkForce 293;
      };
    };

    systemd.tmpfiles.rules = [
      # State dirs
      "d '${cfg.stateDir}'                        0755 root         root  - -"
      "d '${cfg.stateDir}/servarr'                0755 root         root  - -"
      "d '${cfg.stateDir}/servarr/jellyfin'       0700 jellyfin     root  - -"
      "d '${cfg.stateDir}/servarr/transmission'   0700 transmission root  - -"
      "d '${cfg.stateDir}/servarr/sonarr'         0700 sonarr       root  - -"
      "d '${cfg.stateDir}/servarr/radarr'         0700 radarr       root  - -"
      "d '${cfg.stateDir}/servarr/readarr'        0700 readarr      root  - -"
      "d '${cfg.stateDir}/servarr/lidarr'         0700 lidarr       root  - -"
      "d '${cfg.stateDir}/servarr/prowlarr'       0700 prowlarr     root  - -"

      # Media dirs
      "d '${cfg.mediaDir}'                        0775 root         media - -"
      "d '${cfg.mediaDir}/library'                0775 jellyfin     media - -"
      "d '${cfg.mediaDir}/library/series'         0775 jellyfin     media - -"
      "d '${cfg.mediaDir}/library/movies'         0775 jellyfin     media - -"
      "d '${cfg.mediaDir}/library/music'          0775 jellyfin     media - -"
      "d '${cfg.mediaDir}/library/books'          0775 jellyfin     media - -"
      "d '${cfg.mediaDir}/torrents'               0755 transmission media - -"
      "d '${cfg.mediaDir}/torrents/.incomplete'   0755 transmission media - -"
      "d '${cfg.mediaDir}/torrents/.watch'        0755 transmission media - -"
      "d '${cfg.mediaDir}/torrents/manual'        0755 transmission media - -"
      "d '${cfg.mediaDir}/torrents/liadarr'       0755 transmission media - -"
      "d '${cfg.mediaDir}/torrents/radarr'        0755 transmission media - -"
      "d '${cfg.mediaDir}/torrents/sonarr'        0755 transmission media - -"
      "d '${cfg.mediaDir}/torrents/readarr'       0755 transmission media - -"
    ];

    kirk.upnp.enable = cfg.upnp.enable;

    kirk.vpnnamespace = {
      enable = true;
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
