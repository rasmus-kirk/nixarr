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
        # Wait for Jellyfin to be fully ready before syncing.
        # The jellyfin-api-key service may have triggered an async restart of Jellyfin
        # after inserting a new API key (via --no-block). We need to wait for Jellyfin
        # to be STABLY available, not just briefly up during a restart transition.
        # We require 3 consecutive successful checks to ensure stability.
        ExecStartPre = pkgs.writeShellScript "wait-for-jellyfin" ''
          RETRIES=120
          CONSECUTIVE_SUCCESS=0
          REQUIRED_SUCCESS=3

          while [ $RETRIES -gt 0 ]; do
            if ${pkgs.curl}/bin/curl -sf http://127.0.0.1:${toString cfg.port}/System/Info/Public >/dev/null 2>&1; then
              CONSECUTIVE_SUCCESS=$((CONSECUTIVE_SUCCESS + 1))
              if [ $CONSECUTIVE_SUCCESS -ge $REQUIRED_SUCCESS ]; then
                exit 0
              fi
            else
              # Reset on failure - Jellyfin might be restarting
              CONSECUTIVE_SUCCESS=0
            fi
            sleep 1
            RETRIES=$((RETRIES - 1))
          done
          echo "Jellyfin did not become stably ready in time" >&2
          exit 1
        '';
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
