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

  dynamic-configs = {
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

  dynamic-config-set-cmds = with lib.attrsets; mapAttrsToList (
    group-n: group-v: (
      mapAttrsToList (
        n: v: "| initool set - ${group-n} ${n} \"${builtins.toString v}\" \\\n"
      ) group-v
    )
  ) dynamic-configs;

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

  apply-dynamic-configs-script = pkgs.writeShellApplication {
    name = "sabnzbd-set-dynamic-values";
    runtimeInputs = with pkgs; [initool util-linux];
    text = with lib; ''
      if [ ! -f ${ini-file-target} ]; then
        echo "FAILURE: Cannot write changes to ${ini-file-target}, file does not exist"
        exit 1
      fi

      cp --preserve ${ini-file-target}{,.tmp}
      initool set ${ini-file-target} "" __comment__ 'edited by nixarr' \
    '' + (strings.concatStrings (lists.flatten dynamic-config-set-cmds))
    + ''
      > ${ini-file-target}.tmp && mv -f ${ini-file-target}{.tmp,}
    '';
  };

  bashCheckIfEmptyStr = v: "[[ -z \$${v} || \$${v} == '\"\"' ]]";
  gen-uuids-script = pkgs.writeShellApplication {
    name = "sabnzbd-set-random-api-uuids";
    runtimeInputs = with pkgs; [initool util-linux];
    text = ''
      if [ ! -f ${ini-file-target} ]; then
        echo "FAILURE: ${ini-file-target} does not exist. Cannot generate crypto strings."
        exit 1
      fi

      api_key_value=$(initool get ${ini-file-target} misc api_key -v)
      nzb_key_value=$(initool get ${ini-file-target} misc nzb_key -v)

      cp --preserve ${ini-file-target}{,.tmp}
      if ${bashCheckIfEmptyStr "api_key_value"}; then
        api_uuid=$(uuidgen --random | tr -d '-')
        initool set ${ini-file-target} misc api_key "$api_uuid" \
          > ${ini-file-target}.tmp
        echo "Generated api_key for ${ini-file-target}"
      fi
      if ${bashCheckIfEmptyStr "nzb_key_value"}; then
        nzb_uuid=$(uuidgen --random | tr -d '-')
        initool set ${ini-file-target} misc nzb_key "$nzb_uuid" \
          > ${ini-file-target}.tmp
        echo "Generated nzb_key for ${ini-file-target}"
      fi
      mv -f ${ini-file-target}{.tmp,}
    '';
  };
in
{
  systemd.tmpfiles.rules = [ "C ${cfg.stateDir}/sabnzbd.ini - - - - ${./base-config.ini}" ];
  systemd.services.sabnzbd.serviceConfig.ExecStartPre = lib.mkBefore [
    ("+" + fix-config-permissions-script + "/bin/sabnzbd-fix-config-permissions")
    (gen-uuids-script + "/bin/sabnzbd-set-random-api-uuids")
    (apply-dynamic-configs-script + "/bin/sabnzbd-set-dynamic-values")
  ];
}
