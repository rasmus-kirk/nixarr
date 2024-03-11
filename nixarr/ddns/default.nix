{
  pkgs,
  config,
  lib,
  ...
}:
with lib; let
  cfg = config.nixarr.ddns;
in {
  options.nixarr.ddns = {
    njalla = {
      enable = mkOption {
        type = types.bool;
        default = false;
        example = true;
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
        example = "/data/.secret/njalla/keys-file.json";
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
  };

  config = mkIf cfg.njalla.enable {
    assertions = [
      {
        assertion = cfg.njalla.enable -> cfg.njalla.keysFile != null;
        message = ''
          The nixarr.ddns.njalla.enable option requires the
          nixarr.ddns.njalla.keysFile option to be set, but it was not.
        '';
      }
    ];

    systemd.timers = mkIf cfg.njalla.enable {
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
          json_file="${cfg.njalla.keysFile}"

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
    in mkIf cfg.njalla.enable {
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
