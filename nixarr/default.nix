{
  config,
  lib,
  pkgs,
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
    ./openssh
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

        - [Jellyfin](#nixarr.jellyfin.enable)
        - [Lidarr](#nixarr.lidarr.enable)
        - [Prowlarr](#nixarr.prowlarr.enable)
        - [Radarr](#nixarr.radarr.enable)
        - [Readarr](#nixarr.readarr.enable)
        - [Sonarr](#nixarr.sonarr.enable)
        - [Transmission](#nixarr.transmission.enable)

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

    ddns.njalla = {
      enable = mkOption {
        type = types.bool;
        default = false;
        description = ''
          **Required options:**

          - [`nixarr.ddns.njalla.keysFile`](#nixarr.ddns.njalla.keysfile)

          Whether or not to enable DDNS for a [Njalla](https://njal.la/)
          domain.
        '';
      };

      keysFile = mkOption {
        type = with types; nullOr path;
        default = null;
        description = ''
          A path to a JSON-file containing key value pairs of domains and keys.

          To get the keys, create a dynamic njalla record. Upon creation
          you should see something like the following command suggested:

          ```sh
            curl "https://njal.la/update/?h=jellyfin.example.com&k=zeubesojOLgC2eJC&auto"
          ```

          Then the JSON-file you pass here should contain:

          ```json
            {
              "jellyfin.example.com": "zeubesojOLgC2eJC"
            }
          ```

          You can, of course, add more key-value pairs than just one.
        '';
      };
    };

    vpn = {
      enable = mkOption {
        type = types.bool;
        default = false;
        description = ''
          **Required options:** [`nixarr.vpn.wgConf`](#nixarr.vpn.wgconf)

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
    assertions = [
      {
        assertion = cfg.vpn.enable -> cfg.vpn.wgConf != null;
        message = ''
          The nixarr.vpn.enable option requires the nixarr.vpn.wgConf option
          to be set, but it was not.
        '';
      }
      {
        assertion = cfg.ddns.njalla.enable -> cfg.ddns.njalla.keysFile != null;
        message = ''
          The nixarr.ddns.njalla.enable option requires the
          nixarr.ddns.njalla.keysFile option to be set, but it was not.
        '';
      }
    ];

    users.groups = {
      media.gid = 992;
      prowlarr = {};
      streamer = {};
      torrenter = {};
    };
    # TODO: This is BAD. But seems necessary when using containers.
    # The prefered solution is to just remove containerization.
    # Look at https://github.com/NixOS/nixpkgs/blob/master/nixos/modules/misc/ids.nix
    # See also issue: https://github.com/rasmus-kirk/nixarr/issues/1
    users.users = {
      streamer = {
        isSystemUser = true;
        group = "streamer";
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
        group = "torrenter";
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
      wireguardConfigFile = if cfg.vpn.wgConf != null then cfg.vpn.wgConf else "";
      vpnTestService = {
        enable = cfg.vpn.vpnTestService.enable;
        port = cfg.vpn.vpnTestService.port;
      };
      openTcpPorts = cfg.vpn.openTcpPorts;
      openUdpPorts = cfg.vpn.openUdpPorts;
    };

    systemd.timers = mkIf cfg.ddns.njalla.enable {
      ddnsNjalla = {
        description = "Timer for setting the Njalla DDNS records";

        timerConfig = {
          OnBootSec = "30"; # Run 30 seconds after system boot
          OnCalendar = "hourly";
          Persistent = true; # Run service immediately if last window was missed
          RandomizedDelaySec = "5min"; # Run service OnCalendar +- 5min
        };

        wantedBy = ["multi-user.target"];
      };
    };

    systemd.services = let 
      ddns-njalla = pkgs.writeShellApplication {
        name = "ddns-njalla";

        runtimeInputs = with pkgs; [ curl jq ];

        # Thanks chatgpt...
        text = ''
          # Path to the JSON file
          json_file="${cfg.ddns.njalla.keysFile}"

          # Convert the JSON object into a series of tab-separated key-value pairs using jq
          # - `to_entries[]`: Convert the object into an array of key-value pairs.
          # - `[.key, .value]`: For each pair, create an array containing the key and the value.
          # - `@tsv`: Convert the array to a tab-separated string.
          # The output will be a series of lines, each containing a key and a value separated by a tab.
          jq_command='to_entries[] | [.key, .value] | @tsv'

          # Read the converted output line by line
          # - `IFS=$'\t'`: Use the tab character as the field separator.
          # - `read -r key val`: For each line, split it into `key` and `val` based on the tab separator.
          while IFS=$'\t' read -r key val; do
            # For each key-value pair, execute the curl command
            # Replace `''${key}` and `''${val}` in the URL with the actual key and value.
            curl -s "https://njal.la/update/?h=''${key}&k=''${val}&auto"
          done < <(jq -r "$jq_command" "$json_file")
        '';
      };
    in mkIf cfg.ddns.njalla.enable {
      ddnsNjalla = {
        description = "Sets the Njalla DDNS records";

        serviceConfig = {
          ExecStart = getExe ddns-njalla;
          Type = "oneshot";
        };
      };
    };
  };
}
