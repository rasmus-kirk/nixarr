{
  config,
  lib,
  pkgs,
  ...
}: let
  inherit
    (lib)
    types
    mkOption
    getExe
    mkIf
    ;

  inherit
    (pkgs.writers)
    writeJSON
    writePython3Bin
    ;

  nixarr = config.nixarr;
  globals = config.util-nixarr.globals;
  cfg = nixarr.radarr.settings-sync;

  nixarr-utils = import ../../lib/utils.nix {inherit pkgs lib config;};
  inherit (nixarr-utils) arrCfgType;

  nixarr-py = import ../../lib/nixarr-py {inherit pkgs lib config;};

  show-schemas = writePython3Bin "nixarr-show-radarr-schemas" {
    libraries = [nixarr-py];
    flakeIgnore = [
      "E501" # Line too long
    ];
  } (builtins.readFile ./show_schemas.py);

  sync-settings = writePython3Bin "nixarr-sync-radarr-settings" {
    libraries = [nixarr-py];
    flakeIgnore = [
      "E501" # Line too long
    ];
  } (builtins.readFile ./sync_settings.py);

  downloadClientConfigType = types.submodule {
    freeformType = arrCfgType;
    options = {
      name = mkOption {
        type = types.str;
        description = ''
          The name Radarr uses for this download client.
          Note that names must be unique among *all download clients*, *ignoring case*.
        '';
      };
      implementation = mkOption {
        type = types.str;
        description = ''
          The implementation name of the download client in Radarr. This is used
          to find the default configuration when adding a new download client, and
          must match the existing download client's implementation name when
          overwriting an existing download client.
        '';
      };
      enable = mkOption {
        type = types.bool;
        default = true;
        description = "Whether the download client is enabled.";
      };
      fields = mkOption {
        type = arrCfgType;
        default = {};
        description = ''
          Fields to set on the configuration for a download client. Other configuration
          options are left unchanged from their defaults (for new download clients) or
          existing values (for overwritten download clients).

          In the schema, these are represented as an array of objects with
          `.name` and `.value` members. Each attribute in this config attrSset
          will update the `.value` member of the `fields` item with a matching
          `.name`. For more details on each field, check the schema.
        '';
      };
    };
  };

  wantedServices = ["radarr-api.service"];
in {
  options = {
    nixarr.radarr.settings-sync = {
      downloadClients = mkOption {
        type = with types; listOf downloadClientConfigType;
        default = [];
        description = ''
          List of download clients to configure in Radarr.

          To see available top-level properties and `fields` members for each
          download client, run `${getExe show-schemas} download_client | jq '.'` as root.
        '';
      };

      transmission.enable = mkOption {
        type = types.bool;
        default = false;
        description = ''
          Automatically configure Transmission as a download client in Radarr.
        '';
      };
    };
  };

  config = mkIf (nixarr.enable && nixarr.radarr.enable) {
    assertions = [
      {
        assertion = !cfg.transmission.enable || nixarr.transmission.enable;
        message = "nixarr.radarr.settings-sync.transmission.enable requires nixarr.transmission.enable to be true";
      }
    ];

    # Add Transmission config if enabled
    nixarr.radarr.settings-sync.downloadClients = mkIf cfg.transmission.enable [
      {
        name = "Transmission";
        implementation = "Transmission";
        enable = true;
        fields = {
          host = "localhost";
          port = nixarr.transmission.uiPort;
          useSsl = false;
        };
      }
    ];

    users.users.radarr.extraGroups = ["radarr-api"];

    environment.systemPackages = [show-schemas];

    systemd.services.radarr-sync-config = {
      description = ''
        Sync Radarr configuration (download clients)
      '';
      after = wantedServices;
      wants = wantedServices;
      wantedBy = ["radarr.service" "multi-user.target"];
      serviceConfig = {
        Type = "oneshot";
        User = globals.radarr.user;
        Group = globals.radarr.group;
        RemainAfterExit = true;
        ExecStart = let
          config-file = writeJSON "radarr-sync-config.json" {
            download_clients = cfg.downloadClients;
          };
        in ''
          ${getExe sync-settings} --config-file ${config-file}
        '';
      };
    };
  };
}
