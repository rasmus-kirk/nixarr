{
  config,
  lib,
  pkgs,
  ...
}:
with lib; let
  cfg = config.nixarr;
  globals = config.util-nixarr.globals;
in {
  imports = [
    ./audiobookshelf
    ./autobrr
    ./bazarr
    ./ddns
    ./jellyfin
    ./jellyseerr
    ./lidarr
    ./nixarr-command
    ./openssh
    ./plex
    ./prowlarr
    ./radarr
    ./readarr
    ./readarr-audiobook
    ./recyclarr
    ./sabnzbd
    ./sonarr
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

        Also comes with the `nixarr` command that helps you manage your library.

        It is possible, _but not recommended_, to run the "*Arrs" behind a VPN,
        because it can cause rate limiting issues. Generally, you should use
        VPN on transmission and maybe jellyfin, depending on your setup.

        The following services are supported:

        - [Audiobookshelf](#nixarr.audiobookshelf.enable)
        - [Autobrr](#nixarr.autobrr.enable)
        - [Bazarr](#nixarr.bazarr.enable)
        - [Jellyfin](#nixarr.jellyfin.enable)
        - [Jellyseerr](#nixarr.jellyseerr.enable)
        - [Lidarr](#nixarr.lidarr.enable)
        - [Plex](#nixarr.plex.enable)
        - [Prowlarr](#nixarr.prowlarr.enable)
        - [Radarr](#nixarr.radarr.enable)
        - [Readarr](#nixarr.readarr.enable)
        - [Readarr Audiobook](#nixarr.readarr-audiobook.enable)
        - [Recyclarr](#nixarr.recyclarr.enable)
        - [SABnzbd](#nixarr.sabnzbd.enable)
        - [Sonarr](#nixarr.sonarr.enable)
        - [Transmission](#nixarr.transmission.enable)

        Remember to read the options!
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

        > **Warning:** Setting this to any path, where the subpath is not
        > owned by root, will fail! For example:
        >
        > ```nix
        >   mediaDir = /home/user/nixarr
        > ```
        >
        > Is not supported, because `/home/user` is owned by `user`.
      '';
    };

    autosync = mkOption {
      type = types.bool;
      default = false;
      example = true;
      description = ''
        Automatically create integrations between enabled services.

        Currently this includes
        - Sonarr and Radarr integrations for Prowlarr
        - Sonarr and Radarr integrations for Bazarr
      '';
    };

    api-key-location = mkOption {
      type = types.nullOr types.str;
      default = null;
      description = ''
        User provided api key to set as the api key for various services

        Currently includes:
        - Sonarr
        - Radarr
      '';
    };

    api-key-location-internal = mkOption {
      internal = true;
      type = types.str;
      default =
        if cfg.api-key-location == null
        then "${cfg.stateDir}/api-key"
        else cfg.api-key-location;
    };

    stateDir = mkOption {
      type = types.path;
      default = "/data/.state/nixarr";
      example = "/nixarr/.state";
      description = ''
        The location of the state directory for the services.

        > **Warning:** Setting this to any path, where the subpath is not
        > owned by root, will fail! For example:
        >
        > ```nix
        >   stateDir = /home/user/nixarr/.state
        > ```
        >
        > Is not supported, because `/home/user` is owned by `user`.
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

      accessibleFrom = mkOption {
        type = with types; listOf str;
        default = [];
        description = ''
          What IP's the VPN submodule should be accessible from. By default
          the following are included:

          - "192.168.1.0/24"
          - "192.168.0.0/24"
          - "127.0.0.1"

          Otherwise, you would not be able to services over your local
          network. You might have to use this option to extend your list
          with your local IP range by passing it with this option.
        '';
        example = ["192.168.2.0/24"];
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

    users.groups.media.members = cfg.mediaUsers;

    environment.systemPackages = with pkgs; [
      jdupes
    ];

    vpnNamespaces.wg = mkIf cfg.vpn.enable {
      enable = true;
      openVPNPorts = optional (cfg.vpn.vpnTestService.port != null) {
        port = cfg.vpn.vpnTestService.port;
        protocol = "tcp";
      };
      accessibleFrom =
        [
          "192.168.1.0/24"
          "192.168.0.0/24"
          "127.0.0.1"
        ]
        ++ cfg.vpn.accessibleFrom;
      wireguardConfigFile = cfg.vpn.wgConf;
    };
    systemd = {
      tmpfiles.rules = [
        "d '${cfg.mediaDir}'  0775 ${globals.libraryOwner.user} ${globals.libraryOwner.group} - -"
      ];

      services.nixarr-api-key = {
        serviceConfig = {
          Group = "media";
          Type = "oneshot";
        };

        script = let
          nixarr-api-key = pkgs.writeShellApplication {
            name = "nixarr-api-key";

            runtimeInputs = with pkgs; [util-linux coreutils bash openssl];

            text =
              if (cfg.api-key-location == null)
              then ''
                mkdir -p "$(dirname ${cfg.stateDir})"
                if [ ! -f ${cfg.api-key-location-internal} ]; then
                  openssl rand -hex 64 > ${cfg.api-key-location-internal}
                  chgrp media ${cfg.api-key-location-internal}
                fi
              ''
              else ''
                if [ ! -f ${cfg.api-key-location-internal} ]; then
                  echo "The user-specified Nixarr API key file ${cfg.api-key-location-internal} does not exist!" >&2
                  exit 1
                fi
              '';
          };
        in "${nixarr-api-key}/bin/nixarr-api-key";
      };

      services.vpn-test-service = mkIf cfg.vpn.vpnTestService.enable {
        enable = true;

        vpnConfinement = {
          enable = true;
          vpnNamespace = "wg";
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
  };
}
