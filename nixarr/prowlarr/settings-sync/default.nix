{
  config,
  lib,
  pkgs,
  ...
}: let
  inherit
    (lib)
    types
    toSentenceCase
    filter
    mkOption
    getExe
    mkIf
    recursiveUpdate
    ;

  inherit
    (pkgs.writers)
    writeJSON
    writePython3Bin
    ;

  nixarr = config.nixarr;
  cfg = nixarr.prowlarr.settings-sync;

  nixarr-utils = import ../../lib/utils.nix {inherit pkgs lib config;};
  inherit (nixarr-utils) mkArrLocalUrl toKebabSentenceCase arrCfgType;

  nixarr-py = import ../../lib/nixarr-py {inherit pkgs lib config;};

  show-schemas = writePython3Bin "nixarr-show-prowlarr-schemas" {
    libraries = [nixarr-py];
    flakeIgnore = [
      "E501" # Line too long
    ];
  } (builtins.readFile ./show_schemas.py);

  sync-settings = writePython3Bin "nixarr-sync-prowlarr-settings" {
    libraries = [nixarr-py];
    flakeIgnore = [
      "E501" # Line too long
    ];
  } (builtins.readFile ./sync_settings.py);

  mkAppConfigType = {
    service,
    implementation,
  }:
    types.submodule {
      freeformType = arrCfgType;
      options = {
        name = mkOption {
          type = types.str;
          default = toKebabSentenceCase service;
          description = ''
            The name Prowlarr uses for this instance of an application. Note
            that app names must be unique among *all* apps (not just apps of
            this type), *ignoring case*.
          '';
        };
        implementation = mkOption {
          type = types.str;
          default = implementation;
          description = ''
            The implementation name of the application in Prowlarr. This is used
            to find the default configuration when adding a new application, and
            must match the existing application's implementation name when
            overwriting an existing application.
          '';
        };
        tag_labels = mkOption {
          type = with types; listOf str;
          default = [];
          description = ''
            List of tag labels to associate with this application. Overwrites
            any existing tags on the application.
          '';
        };
        fields = mkOption {
          type = arrCfgType;
          default = {};
          description = ''
            Additional fields to set on the application configuration. Other
            configuration options are left unchanged from their defaults (for
            new applications) or existing values (for overwritten applications).

            In the schema, these are represented as an array of objects with
            `.name` and `.value` members. Each attribute in this config attrSset
            will update the `.value` member of the `fields` item with a matching
            `.name`. For more details on each field, check the schema.

            The fields `prowlarrUrl`, `baseUrl`, and `apiKey` are set by this
            module but can be overridden here if necessary.
          ''; # TODO: add schema to `nixarr` utility command?
          example = {
            syncCategories = [2030];
            syncRejectBlocklistedTorrentHashesWhileGrabbing = true;
            somePassword = {
              secret = "/path/to/secret/file";
            };
          };
        };
      };
    };

  mkAppOptions = {
    service,
    implementation ? toSentenceCase service,
  }: {
    enable = mkOption {
      type = types.bool;
      default = cfg.apps.enable;
      description = ''
        Whether to sync the config for this application to Prowlarr.
      '';
    };
    config = mkOption {
      type = mkAppConfigType {
        inherit service implementation;
      };
      default = {};
      description = ''
        Configuration for this application in Prowlarr.

        To see available top-level properties and `fields` members, run
        `${getExe show-schemas} application | jq '.[] | select(.implementation
        == "${implementation}")'` as root.
      '';
      example = {
        name = "My special service name";
        tag_labels = ["tag1" "tag2"];
        fields = {
          syncCategories = [2030];
        };
      };
    };
  };

  indexerConfigType = types.submodule {
    freeformType = arrCfgType;
    options = {
      name = mkOption {
        type = with types; nullOr str;
        default = null;
        description = ''
          The name Prowlarr uses for this indexer. If not provided, the default
          name from the indexer definition is used.

          Note that indexer names must be unique among *all indexers*, *ignoring
          case*.
        '';
      };
      sort_name = mkOption {
        type = types.str;
        description = ''
          The sort name of the indexer definition to base this indexer on. This
          is used to find the default configuration when adding a new indexer,
          and must match the existing indexer's sort name when overwriting an
          existing indexer.
        '';
      };
      app_profile_name = mkOption {
        type = types.str;
        default = "Standard";
        description = ''
          The app profile to associate with this indexer. Must already exist.
          We look up this profile by name to set the appProfileId field on the
          indexer configuration.
        '';
      };
      tag_labels = mkOption {
        type = with types; listOf str;
        default = [];
        description = ''
          List of tag labels to associate with this indexer. Overwrites any
          existing tags on the indexer.
        '';
      };
      fields = mkOption {
        type = arrCfgType;
        default = {};
        description = ''
          Fields to set on the configuration for an indexer. Other configuration
          options are left unchanged from their defaults (for new indexers) or
          existing values (for overwritten indexers).

          In the schema, these are represented as an array of objects with
          `.name` and `.value` members. Each attribute in this config attrSset
          will update the `.value` member of the `fields` item with a matching
          `.name`. For more details on each field, check the schema.
        '';
      };
    };
  };

  arrServiceNames = [
    "sonarr"
    "radarr"
    "lidarr"
    "readarr"
    "readarr-audiobook"
  ];

  syncServiceNames =
    filter (name: nixarr.${name}.enable && cfg.apps.${name}.enable) arrServiceNames;

  extraGroups =
    map (service: config.users.groups."${service}-api".name)
    (syncServiceNames ++ ["prowlarr"]);

  wantedServices =
    map (service: "${service}-api-key.service")
    (syncServiceNames ++ ["prowlarr"]);
in {
  options = {
    nixarr.prowlarr.settings-sync = {
      # TODO: add sync interval?
      # TODO: allow configuring whether to overwrite existing items?
      # TODO: allow *deleting* items not in the config?

      apps = {
        enable = mkOption {
          type = types.bool;
          default = false;
          description = ''
            Enable syncing application information to Prowlarr by default. You
            can override this per application.
          '';
        };

        sonarr = mkAppOptions {service = "sonarr";};
        radarr = mkAppOptions {service = "radarr";};
        lidarr = mkAppOptions {service = "lidarr";};
        readarr = mkAppOptions {service = "readarr";};
        readarr-audiobook = mkAppOptions {
          service = "readarr-audiobook";
          implementation = "Readarr";
        };
      };

      tags = mkOption {
        type = with types; listOf str;
        default = [];
        description = ''
          List of tag labels to create in Prowlarr. Note that tag labels must
          be unique *ignoring case*.
        '';
      };

      indexers = mkOption {
        type = with types; listOf indexerConfigType;
        default = [];
        description = ''
          List of indexers to configure in Prowlarr.

          To see available top-level properties and `fields` members for each
          indexer, run `${getExe show-schemas} indexer | jq '.'` as root. You
          may want to filter by `sort_name` to find the indexer you want to
          configure.
        '';
        example = [
          {
            name = "My special indexer name";
            sort_name = "nzbgeek";
            tag_labels = ["tag1" "tag2"];
            priority = 30;
            fields = {
              apiKey.secret = "/path/to/secret/file";
            };
          }
        ];
      };
    };
  };

  config = mkIf (nixarr.enable && nixarr.prowlarr.enable) {
    users.users.prowlarr.extraGroups = extraGroups;

    environment.systemPackages = [show-schemas];

    systemd.services.prowlarr-sync-config = {
      description = ''
        Sync Prowlarr configuration (tags, indexers, applications)
      '';
      after = wantedServices;
      wants = wantedServices;
      wantedBy = ["prowlarr.service"];
      serviceConfig = {
        Type = "oneshot";
        User = "prowlarr";
        Group = "prowlarr";
        Restart = "on-failure"; # Retry in case Prowlarr isn't up yet...
        RestartSec = "1s"; # But not too fast.
        ExecStart = let
          mkAppConfig = name:
            recursiveUpdate
            {
              /*
              TODO: we're only doing this here because if we just made these the
              default values in the app config type and the user adds *any*
              field, then *all* of the defaults would be overridden.
              */
              fields = {
                prowlarrUrl = mkArrLocalUrl "prowlarr";
                baseUrl = mkArrLocalUrl name;
                apiKey.secret = "${nixarr.stateDir}/api-keys/${name}.key";
              };
            }
            cfg.apps.${name}.config;
          config-file = writeJSON "prowlarr-sync-config.json" {
            tag_labels = cfg.tags;
            app_configs = map mkAppConfig syncServiceNames;
            indexer_configs = cfg.indexers;
          };
        in ''
          ${getExe sync-settings} --config-file ${config-file}
        '';
      };
    };
  };
}
