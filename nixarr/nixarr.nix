{
  config,
  lib,
  pkgs,
  ...
}:
with lib; let
  cfg = config.nixarr;
  list-unlinked = pkgs.writeShellApplication {
    name = "list-unlinked";
    runtimeInputs = with pkgs; [util-linux];
    text = ''
      if [ "$#" -ne 1 ]; then
          echo "Illegal number of parameters. Must be one file path"
      fi

      find "$1" -type f -links 1 -exec du -h {} + | sort -h
    '';
  };
  fix-permissions = pkgs.writeShellApplication {
    name = "fix-permissions";
    runtimeInputs = with pkgs; [util-linux];
    text = ''
      if [ "$EUID" -ne 0 ]; then
        echo "Please run as root"
        exit
      fi

      chown -R torrenter:media "${cfg.mediaDir}/torrents"
      chown -R streamer:media "${cfg.mediaDir}/library"
      find "${cfg.mediaDir}" \( -type d -exec chmod 0775 {} + -true \) -o \( -exec chmod 0664 {} + \)
    '' + strings.optionalString cfg.jellyfin.enable ''
      chown -R streamer:root "${cfg.jellyfin.stateDir}"
      find "${cfg.jellyfin.stateDir}" \( -type d -exec chmod 0700 {} + -true \) -o \( -exec chmod 0600 {} + \)
    '' + strings.optionalString cfg.transmission.enable ''
      chown -R torrenter:cross-seed "${cfg.transmission.stateDir}"
      find "${cfg.transmission.stateDir}" \( -type d -exec chmod 0750 {} + -true \) -o \( -exec chmod 0640 {} + \)
    '' + strings.optionalString cfg.transmission.privateTrackers.cross-seed.enable ''
      chown -R cross-seed:root "${cfg.transmission.privateTrackers.cross-seed.stateDir}"
      find "${cfg.transmission.privateTrackers.cross-seed.stateDir}" \( -type d -exec chmod 0700 {} + -true \) -o \( -exec chmod 0600 {} + \)
    '' + strings.optionalString cfg.prowlarr.enable ''
      chown -R prowlarr:root "${cfg.prowlarr.stateDir}"
      find "${cfg.prowlarr.stateDir}" \( -type d -exec chmod 0700 {} + -true \) -o \( -exec chmod 0600 {} + \)
    '' + strings.optionalString cfg.sonarr.enable ''
      chown -R sonarr:root "${cfg.sonarr.stateDir}"
      find "${cfg.sonarr.stateDir}" \( -type d -exec chmod 0700 {} + -true \) -o \( -exec chmod 0600 {} + \)
    '' + strings.optionalString cfg.radarr.enable ''
      chown -R radarr:root "${cfg.radarr.stateDir}"
      find "${cfg.radarr.stateDir}" \( -type d -exec chmod 0700 {} + -true \) -o \( -exec chmod 0600 {} + \)
    '' + strings.optionalString cfg.lidarr.enable ''
      chown -R lidarr:root "${cfg.lidarr.stateDir}"
      find "${cfg.lidarr.stateDir}" \( -type d -exec chmod 0700 {} + -true \) -o \( -exec chmod 0600 {} + \)
    '' + strings.optionalString cfg.bazarr.enable ''
      chown -R bazarr:root "${cfg.bazarr.stateDir}"
      find "${cfg.bazarr.stateDir}" \( -type d -exec chmod 0700 {} + -true \) -o \( -exec chmod 0600 {} + \)
    '' + strings.optionalString cfg.readarr.enable ''
      chown -R readarr:root "${cfg.readarr.stateDir}"
      find "${cfg.readarr.stateDir}" \( -type d -exec chmod 0700 {} + -true \) -o \( -exec chmod 0600 {} + \)
    '';
  };
in {
  imports = [
    ./jellyfin
    ./bazarr
    ./ddns
    ./radarr
    ./lidarr
    ./readarr
    ./sonarr
    ./openssh
    ./prowlarr
    ./transmission
    ../util
  ];

  options.nixarr = {
    enable = mkOption {
      type = types.bool;
      default = false;
      example = true;
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

        - [Jellyfin](#nixarr.jellyfin.enable)
        - [Bazarr](#nixarr.bazarr.enable)
        - [Lidarr](#nixarr.lidarr.enable)
        - [Prowlarr](#nixarr.prowlarr.enable)
        - [Radarr](#nixarr.radarr.enable)
        - [Readarr](#nixarr.readarr.enable)
        - [Sonarr](#nixarr.sonarr.enable)
        - [Transmission](#nixarr.transmission.enable)

        Remember to read the options.
      '';
    };

    mediaUsers = mkOption {
      type = with types; listOf str;
      default = [];
      example = ["user"];
      description = ''
        Extra users to add to the media group.
      '';
    };

    mediaDir = mkOption {
      type = types.path;
      default = "/data/media";
      example = "/nixarr";
      description = ''
        The location of the media directory for the services.

        **Warning:** Setting this to any path, where the subpath is not
        owned by root, will fail! For example:

        ```nix
          mediaDir = /home/user/nixarr
        ```

        Is not supported, because `/home/user` is owned by `user`.
      '';
    };

    stateDir = mkOption {
      type = types.path;
      default = "/data/.state/nixarr";
      example = "/nixarr/.state";
      description = ''
        The location of the state directory for the services.

        **Warning:** Setting this to any path, where the subpath is not
        owned by root, will fail! For example:

        ```nix
          stateDir = /home/user/nixarr/.state
        ```

        Is not supported, because `/home/user` is owned by `user`.
      '';
    };

    vpn = {
      enable = mkOption {
        type = types.bool;
        default = false;
        example = true;
        description = ''
          **Required options:** [`nixarr.vpn.wgConf`](#nixarr.vpn.wgconf)

          Whether or not to enable VPN support for the services that nixarr
          supports.
        '';
      };

      wgConf = mkOption {
        type = types.nullOr types.path;
        default = null;
        example = "/data/.secret/vpn/wg.conf";
        description = "The path to the wireguard configuration file.";
      };

      vpnTestService = {
        enable = mkEnableOption ''
          the vpn test service. Useful for testing DNS leaks or if the VPN
          port forwarding works correctly.
        '';

        port = mkOption {
          type = with types; nullOr port;
          default = null;
          example = 58403;
          description = ''
            The port that netcat listens to on the vpn test service. If set to
            `null`, then netcat will not be started.
          '';
        };
      };

      openTcpPorts = mkOption {
        type = with types; listOf port;
        default = [];
        description = ''
          What TCP ports to allow traffic from. You might need this if you're
          port forwarding on your VPN provider and you're setting up services
          not covered in by this module that uses the VPN.
        '';
        example = [46382 38473];
      };

      openUdpPorts = mkOption {
        type = with types; listOf port;
        default = [];
        description = ''
          What UDP ports to allow traffic from. You might need this if you're
          port forwarding on your VPN provider and you're setting up services
          not covered in by this module that uses the VPN.
        '';
        example = [46382 38473];
      };
    };
  };

  config = mkIf cfg.enable {
    assertions = [
      {
        assertion = cfg.vpn.enable -> cfg.vpn.wgConf != null;
        message = ''
          The nixarr.vpn.enable option requires the nixarr.vpn.wgConf option
          to be set, but it was not.
        '';
      }
    ];

    users.groups = {
      media.members = cfg.mediaUsers;
      streamer = {};
      torrenter = {};
    };
    users.users = {
      streamer = {
        isSystemUser = true;
        group = "streamer";
      };
      torrenter = {
        isSystemUser = true;
        group = "torrenter";
      };
    };

    systemd.tmpfiles.rules = [
      # Media dirs
      "d '${cfg.mediaDir}'                      0775 root      media - -"
      "d '${cfg.mediaDir}/library'              0775 streamer  media - -"
      "d '${cfg.mediaDir}/library/shows'        0775 streamer  media - -"
      "d '${cfg.mediaDir}/library/movies'       0775 streamer  media - -"
      "d '${cfg.mediaDir}/library/music'        0775 streamer  media - -"
      "d '${cfg.mediaDir}/library/books'        0775 streamer  media - -"
      "d '${cfg.mediaDir}/torrents'             0755 torrenter media - -"
      "d '${cfg.mediaDir}/torrents/.incomplete' 0755 torrenter media - -"
      "d '${cfg.mediaDir}/torrents/.watch'      0755 torrenter media - -"
      "d '${cfg.mediaDir}/torrents/manual'      0755 torrenter media - -"
      "d '${cfg.mediaDir}/torrents/lidarr'      0755 torrenter media - -"
      "d '${cfg.mediaDir}/torrents/radarr'      0755 torrenter media - -"
      "d '${cfg.mediaDir}/torrents/sonarr'      0755 torrenter media - -"
      "d '${cfg.mediaDir}/torrents/readarr'     0755 torrenter media - -"
    ];

    environment.systemPackages = with pkgs; [
      jdupes
      list-unlinked
      fix-permissions
    ];

    vpnnamespaces.wg = mkIf cfg.vpn.enable {
      enable = true;
      openVPNPorts = optional cfg.vpn.vpnTestService.enable {
        port = cfg.vpn.vpnTestService.port;
        protocol = "tcp";
      };
      accessibleFrom = [
        "192.168.1.0/24"
        "10.0.0.0/8"
        "127.0.0.1"
      ];
      wireguardConfigFile = cfg.vpn.wgConf;
    };

    # TODO: openports
    systemd.services.vpn-test-service = mkIf cfg.vpn.vpnTestService.enable {
      enable = true;

      vpnconfinement = {
        enable = true;
        vpnnamespace = "wg";
      };

      script = let
        vpn-test = pkgs.writeShellApplication {
          name = "vpn-test";

          runtimeInputs = with pkgs; [util-linux unixtools.ping coreutils curl bash libressl netcat-gnu openresolv dig];

          text =
            ''
              cd "$(mktemp -d)"

              # DNS information
              dig google.com

              # Print resolv.conf
              echo "/etc/resolv.conf contains:"
              cat /etc/resolv.conf

              # Query resolvconf
              echo "resolvconf output:"
              resolvconf -l
              echo ""

              # Get ip
              echo "Getting IP:"
              curl -s ipinfo.io

              echo -ne "DNS leak test:"
              curl -s https://raw.githubusercontent.com/macvk/dnsleaktest/b03ab54d574adbe322ca48cbcb0523be720ad38d/dnsleaktest.sh -o dnsleaktest.sh
              chmod +x dnsleaktest.sh
              ./dnsleaktest.sh
            ''
            + (
              if cfg.vpn.vpnTestService.port != null
              then ''
                echo "starting netcat on port ${builtins.toString cfg.vpn.vpnTestService.port}:"
                nc -vnlp ${builtins.toString cfg.vpn.vpnTestService.port}
              ''
              else ""
            );
        };
      in "${vpn-test}/bin/vpn-test";
    };
  };
}
