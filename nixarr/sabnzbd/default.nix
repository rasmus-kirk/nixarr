{
  config,
  lib,
  pkgs,
  ...
}:
with lib; let
  cfg = config.nixarr.sabnzbd;
  nixarr = config.nixarr;

  edited-flag = "edited by nixarr";

  mkSetHostWhitelistCmd = with lib.strings; (hosts: ''
    | initool set - misc host_whitelist ${concatStringsSep "," hosts} \
  '');

  mkSetRangeWhitelistCmd = with lib.strings; (ranges: ''
    | initool set - misc local_ranges ${concatStringsSep "," ranges} \
  '');

  mkINIInitScript = (
    {
      sabnzbd-state-dir,
      guiPort,
      access-externally ? true,
      whitelist-hosts ? [],
      whitelist-ranges ? []
    }:
    pkgs.writeShellApplication {
      name = "set-sabnzbd-ini-values";
      runtimeInputs = with pkgs; [initool sabnzbd sudo coreutils];
      text = with lib.strings; (
        # set download dirs
        ''
        if [ ! -f ${sabnzbd-state-dir}/sabnzbd.ini ]; then
          sudo -u usenet -g media sabnzbd -p -d -f ${sabnzbd-state-dir}/sabnzbd.ini
          sab_pid=$!

          until [ -f "${sabnzbd-state-dir}/sabnzbd.ini" ]
          do
            sleep 1
          done

          kill -INT $sab_pid
       fi

        initool set ${sabnzbd-state-dir}/sabnzbd.ini "" __comment__ '${edited-flag}' \
        | initool set - misc download_dir "${nixarr.mediaDir}/usenet/.incomplete" \
        | initool set - misc complete_dir "${nixarr.mediaDir}/usenet/manual" \
        | initool set - misc dirscan_dir "${nixarr.mediaDir}/usenet/.watch" \
        | initool set - misc port "${builtins.toString guiPort}" \
        '' +
        
        # set host to 0.0.0.0 if remote access needed
        optionalString access-externally ''
          | initool set - misc host 0.0.0.0 \
        '' +
        
        # set hostname whitelist
        optionalString (builtins.length whitelist-hosts > 0) (
          mkSetHostWhitelistCmd whitelist-hosts
        ) +

        # set ip range whitelist
        optionalString (builtins.length whitelist-ranges > 0) (
          mkSetRangeWhitelistCmd whitelist-ranges
        ) +

        ''
        > ${sabnzbd-state-dir}/sabnzbd.ini.tmp \
        && mv ${sabnzbd-state-dir}/sabnzbd.ini{.tmp,}
        ''
      );
    }
  );  
in {
  options.nixarr.sabnzbd = {
    enable = mkEnableOption "Enable the SABnzbd service.";

    stateDir = mkOption {
      type = types.path;
      default = "${nixarr.stateDir}/sabnzbd";
      defaultText = literalExpression ''"''${nixarr.stateDir}/sabnzbd"'';
      example = "/nixarr/.state/sabnzbd";
      description = ''
        The location of the state directory for the SABnzbd service.

        **Warning:** Setting this to any path, where the subpath is not
        owned by root, will fail! For example:

        ```nix
          stateDir = /home/user/nixarr/.state/sabnzbd
        ```

        Is not supported, because `/home/user` is owned by `user`.
      '';
    };

    guiPort = mkOption {
      type = types.port;
      default = 8080;
      example = 9999;
      description = ''
        The port that SABnzbd's GUI will listen on for incomming connections.
      '';
    };

    openFirewall = mkOption {
      type = types.bool;
      defaultText = literalExpression ''!nixarr.SABnzbd.vpn.enable'';
      default = !cfg.vpn.enable;
      example = true;
      description = "Open firewall for SABnzbd";
    };

    whitelistHostnames = mkOption {
      type = types.listOf types.str;
      default = [ config.networking.hostName ];
      defaultText = "[ config.networking.hostName ]";
      example = ''[ "mediaserv" "media.example.com" ]'';
      description = ''
        A list that specifies what URLs that are allowed to represent your
        SABnzbd instance. If you see an error message like this when
        trying to connect to SABnzbd from another device...

        ```
        Refused connection with hostname "your.hostname.com"
        ```

        ...then you should add your hostname(s) to this list.

        SABnzbd only allows connections matching these URLs in order to prevent
        DNS hijacking. See <https://sabnzbd.org/wiki/extra/hostname-check.html>
        for more info.
      '';
    };

    whitelistRanges = mkOption {
      type = types.listOf types.str;
      default = [ ];
      defaultText = "[ ]";
      example = ''[ "192.168.1.0/24" "10.0.0.0/23" ]'';
      description = ''
        A list of IP ranges that will be allowed to connect to SABnzbd's
        web GUI. This only needs to be set if SABnzbd needs to be accessed
        from another machine besides its host.
      '';
    };

    vpn.enable = mkOption {
      type = types.bool;
      default = false;
      example = true;
      description = ''
        **Required options:** [`nixarr.vpn.enable`](#nixarr.vpn.enable)

        Route SABnzbd traffic through the VPN.
      '';
    };
  };

  imports = [];

  config = mkIf cfg.enable {
    systemd.tmpfiles.rules = [
      "d '${cfg.stateDir}' 0750 usenet root - -"
    ];

    services.sabnzbd = {
      enable = true;
      user = "usenet";
      group = "media";
      configFile = "${cfg.stateDir}/sabnzbd.ini";
    };

    networking.firewall.allowedTCPPorts = mkIf cfg.openFirewall [ cfg.guiPort ];

    systemd.services.sabnzbd.serviceConfig = {
      ExecStartPre = mkBefore [
        (
          "+" + mkINIInitScript {
            sabnzbd-state-dir = cfg.stateDir;
            guiPort = cfg.guiPort;
            access-externally = cfg.openFirewall;
            whitelist-hosts = cfg.whitelistHostnames;
            whitelist-ranges = cfg.whitelistRanges;
          } + "/bin/set-sabnzbd-ini-values"
        )
      ];

     #  ExecStartPost = mkBefore [
        # (
        #   "+" + pkgs.writeShellApplication {
        #     name = "ensure-sabnzbd-config-edits";
        #     runtimeInputs = with pkgs; [initool coreutils systemd];
        #     text = ''
        #       until [ -f "${cfg.stateDir}/sabnzbd.ini" ]
        #       do
        #         sleep 1
        #       done
        #
        #       if ! initool get "${cfg.stateDir}/sabnzbd.ini" "" __comment__; then
        #         # force sabnzbd.service restart for ExecStartPre to run now
        #         #  that sabnzbd.ini has been created by the instance
        #         systemctl restart -f sabnzbd.service
        #       fi
        #
        #       exit
        #     '';
        #   } + "/bin/ensure-sabnzbd-config-edits"
        # )
     #  ];
      Restart = "on-failure";
      StartLimitInterval = 15;
      StartLimitBurst = 5;
    };

    # Enable and specify VPN namespace to confine service in.
    systemd.services.sabnzbd.vpnconfinement = mkIf cfg.vpn.enable {
      enable = true;
      vpnnamespace = "wg";
    };

    # Port mappings
    vpnnamespaces.wg = mkIf cfg.vpn.enable {
      portMappings = [
        {
          from = cfg.guiPort;
          to = cfg.guiPort;
        }
      ];
    };

    services.nginx = mkIf cfg.vpn.enable {
      enable = true;

      recommendedTlsSettings = true;
      recommendedOptimisation = true;
      recommendedGzipSettings = true;

      virtualHosts."127.0.0.1:${builtins.toString cfg.guiPort}" = {
        listen = [
          {
            addr = "0.0.0.0";
            port = cfg.guiPort;
          }
        ];
        locations."/" = {
          recommendedProxySettings = true;
          proxyWebsockets = true;
          proxyPass = "http://192.168.15.1:${builtins.toString cfg.guiPort}";
        };
      };
    };
  };
}
