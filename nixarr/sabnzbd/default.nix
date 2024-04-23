{
  config,
  lib,
  pkgs,
  ...
}:
with lib; let
  cfg = config.nixarr.sabnzbd;
  defaultPort = 8080;
  nixarr = config.nixarr;
  # downloadDir = "${nixarr.mediaDir}/usenet";
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

    openFirewall = mkOption {
      type = types.bool;
      defaultText = literalExpression ''!nixarr.SABnzbd.vpn.enable'';
      default = !cfg.vpn.enable;
      example = true;
      description = "Open firewall for SABnzbd";
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
      configFile = /. + "${cfg.stateDir}/sabnzbd.ini";
    };

    networking.firewall.allowedTCPPorts = mkIf cfg.openFirewall [ defaultPort ];
  };
}