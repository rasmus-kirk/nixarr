{ config, pkgs, lib, ... }:
let
  cfg = config.nixarr.sabnzbd;
  nixarr = config.nixarr;
  ini-file-target = "${cfg.stateDir}/sabnzbd.ini";
  concatStringsCommaIfExists = with lib.strings; stringList: (
    optionalString (builtins.length stringList > 0) (
      concatStringsSep "," stringList
    )
  );

  user-configs = {
    misc = {
      host = if cfg.openFirewall then "0.0.0.0" else "127.0.0.1";
      port = cfg.guiPort;
      download_dir = "${nixarr.mediaDir}/usenet/.incomplete";
      complete_dir = "${nixarr.mediaDir}/usenet/manual";
      dirscan_dir = "${nixarr.mediaDir}/usenet/watch";
      host_whitelist = concatStringsCommaIfExists cfg.whitelistHostnames;
      local_ranges = concatStringsCommaIfExists cfg.whitelistRanges;
    };
  };

  api-key-configs = {
    misc = {
      api_key = "";
      nzb_key = "";
    };
  };

  compiled-configs = {misc = (user-configs.misc // api-key-configs.misc);};

  ini-base-config-file = pkgs.writeTextFile {
    name = "base-config.ini"; 
    text = lib.generators.toINI {} compiled-configs;
  };

  mkSedEditValue = name: value: ''sed -E 's%(\b${name} ?= ?).*%\1${builtins.toString value}%g' '';

  user-config-set-cmds = with lib.attrsets; mapAttrsToList (
    group-n: group-v: (
      mapAttrsToList (
        n: v: "${mkSedEditValue n v} \\\n"
      ) group-v
    )
  ) user-configs;

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

  user-configs-to-python = with lib;
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

      ${lib.strings.concatStringsSep "\n" user-configs-to-python}

      sab_config_map.write()
    '');

  bashCheckIfEmptyStr = v: "[[ -z \$${v} || \$${v} == '\"\"' ]]";
  gen-uuids-script = pkgs.writeShellApplication {
    name = "sabnzbd-set-random-api-uuids";
    runtimeInputs = with pkgs; [initool gnused util-linux];
    text = ''
      if [ ! -f ${ini-file-target} ]; then
        echo "FAILURE: ${ini-file-target} does not exist. Cannot generate crypto strings."
        exit 1
      fi

      api_key_value=$(initool get ${ini-file-target} misc api_key -v)
      nzb_key_value=$(initool get ${ini-file-target} misc nzb_key -v)
      
      if ${bashCheckIfEmptyStr "api_key_value"} || ${bashCheckIfEmptyStr "nzb_key_value"}; then
        cp --preserve ${ini-file-target}{,.tmp}
        api_uuid=$(uuidgen --random | tr -d '-')
        nzb_uuid=$(uuidgen --random | tr -d '-')
        < ${ini-file-target} \
          ${mkSedEditValue "api_key" "'\"$api_uuid\"'"} \
          | ${mkSedEditValue "nzb_key" "'\"$nzb_uuid\"'"} \
          > ${ini-file-target}.tmp && mv -f ${ini-file-target}{.tmp,}
      fi
    '';
  };
in
{
  systemd.tmpfiles.rules = [ "C ${cfg.stateDir}/sabnzbd.ini - - - - ${ini-base-config-file}" ];
  systemd.services.sabnzbd.serviceConfig.ExecStartPre = lib.mkBefore [
    ("+" + fix-config-permissions-script + "/bin/sabnzbd-fix-config-permissions")
    (gen-uuids-script + "/bin/sabnzbd-set-random-api-uuids")
    (apply-user-configs-script + "/bin/sabnzbd-set-user-values")
  ];
}
