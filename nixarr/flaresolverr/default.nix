{
  config,
  lib,
  pkgs,
  ...
}:
with lib; let
  cfg = config.nixarr.flaresolverr;
  nixarr = config.nixarr;
in {
  options.nixarr.flaresolverr = {
    enable = mkOption {
      type = types.bool;
      default = false;
      example = true;
      description = ''
        Whether or not to enable the Flaresolverr service.

        **Required options:** [`nixarr.enable`](#nixarr.enable)
      '';
    };

    package = mkPackageOption pkgs "flaresolverr" {};

    port = mkOption {
      type = types.port;
      default = 8191;
      example = 12345;
      description = "Flaresolverr port.";
    };

    openFirewall = mkOption {
      type = types.bool;
      default = false;
      example = true;
      description = "Open firewall for Flaresolverr";
    };
  };

  config = mkIf cfg.enable {
    assertions = [
      {
        assertion = cfg.enable -> nixarr.enable;
        message = ''
          The nixarr.flaresolverr.enable option requires the
          nixarr.enable option to be set, but it was not.
        '';
      }
    ];

    services.flaresolverr = {
      enable = cfg.enable;
      package = cfg.package;
      openFirewall = cfg.openFirewall;
      port = cfg.port;
    };
  };
}
