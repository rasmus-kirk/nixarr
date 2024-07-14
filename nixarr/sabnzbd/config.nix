{
  config,
  pkgs,
  lib,
  ...
}: let
  cfg = config.nixarr.sabnzbd;
  nixarr = config.nixarr;
  ini-file-target = "${cfg.stateDir}/sabnzbd.ini";
  concatStringsCommaIfExists = with lib.strings;
    stringList: (
      optionalString (builtins.length stringList > 0) (
        concatStringsSep "," stringList
      )
    );

  user-configs = {
    misc = {
      host =
        if cfg.openFirewall
        then "0.0.0.0"
        else "127.0.0.1";
      port = cfg.guiPort;
      download_dir = "${nixarr.mediaDir}/usenet/.incomplete";
      complete_dir = "${nixarr.mediaDir}/usenet/manual";
      dirscan_dir = "${nixarr.mediaDir}/usenet/watch";
      host_whitelist = concatStringsCommaIfExists cfg.whitelistHostnames;
      local_ranges = concatStringsCommaIfExists cfg.whitelistRanges;
      permissions = "775";
    };
  };

  ini-base-config-file = pkgs.writeTextFile {
    name = "base-config.ini";
    text = lib.generators.toINI {} user-configs;
  };

  fix-config-permissions-script = pkgs.writeShellApplication {
    name = "sabnzbd-fix-config-permissions";
    runtimeInputs = with pkgs; [util-linux];
    text = ''
      if [ ! -f ${ini-file-target} ]; then
        echo 'FAILURE: cannot change permissions of ${ini-file-target}, file does not exist'
        exit 1
      fi

      chmod 600 ${ini-file-target}
      chown usenet:media ${ini-file-target}
    '';
  };

  user-configs-to-python-list = with lib;
    attrsets.collect (f: !builtins.isAttrs f) (
      attrsets.mapAttrsRecursive (
        path: value:
          "sab_config_map['"
          + (lib.strings.concatStringsSep "']['" path)
          + "'] = '"
          + (builtins.toString value)
          + "'"
      )
      user-configs
    );
  apply-user-configs-script = with lib; (pkgs.writers.writePython3Bin
    "sabnzbd-set-user-values" {libraries = [pkgs.python3Packages.configobj];} ''
      from pathlib import Path
      from configobj import ConfigObj

      sab_config_path = Path("${ini-file-target}")
      if not sab_config_path.is_file() or sab_config_path.suffix != ".ini":
          raise Exception(f"{sab_config_path} is not a valid config file path.")

      sab_config_map = ConfigObj(str(sab_config_path))

      ${lib.strings.concatStringsSep "\n" user-configs-to-python-list}

      sab_config_map.write()
    '');
in {
  systemd.tmpfiles.rules = ["C ${cfg.stateDir}/sabnzbd.ini - - - - ${ini-base-config-file}"];
  systemd.services.sabnzbd.serviceConfig.ExecStartPre = lib.mkBefore [
    ("+" + fix-config-permissions-script + "/bin/sabnzbd-fix-config-permissions")
    (apply-user-configs-script + "/bin/sabnzbd-set-user-values")
  ];
}
