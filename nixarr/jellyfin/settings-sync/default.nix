{
  config,
  lib,
  pkgs,
  ...
}: let
  inherit (pkgs.writers) writeJSON writePython3Bin;
  inherit (lib) getExe mkIf mkOption types mkEnableOption;

  nixarr = config.nixarr;
  cfg = nixarr.jellyfin;
  settingsCfg = cfg.settings-sync;
  globals = config.util-nixarr.globals;

  nixarr-py = import ../../lib/nixarr-py {inherit pkgs lib config;};

  sync-settings = writePython3Bin "nixarr-sync-jellyfin-settings" {
    libraries = [nixarr-py];
  } (builtins.readFile ./sync_users.py);

in {
  options.nixarr.jellyfin.settings-sync = {
    completeWizard = mkOption {
      type = types.bool;
      default = cfg.users != [];
      defaultText = lib.literalExpression "cfg.users != []";
      description = ''
        Whether to automatically mark the Jellyfin startup wizard as complete
        via the API. This is useful when users are defined declaratively,
        as the wizard becomes unnecessary.

        Defaults to `true` when `nixarr.jellyfin.users` is non-empty.
      '';
    };
  };

  config = mkIf (nixarr.enable && cfg.enable) {
    systemd.services.jellyfin-settings-sync = {
      description = "Sync Jellyfin settings (wizard completion, users)";
      after = ["jellyfin.service" "jellyfin-api-key.service"];
      wants = ["jellyfin.service" "jellyfin-api-key.service"];
      wantedBy = ["multi-user.target"];
      serviceConfig = {
        Type = "oneshot";
        Restart = "on-failure";
        RestartSec = "10s";
        User = globals.jellyfin.user;
        Group = globals.jellyfin.group;
        SupplementaryGroups = ["jellyfin-api"];
        ExecStart = let
          config-file = writeJSON "jellyfin-settings.json" {
            users = map (u: {
              name = u.name;
              passwordFile = u.passwordFile;
            }) cfg.users;
            complete_wizard = settingsCfg.completeWizard;
          };
        in ''
          ${getExe sync-settings} --config-file ${config-file}
        '';
      };
    };
  };
}
