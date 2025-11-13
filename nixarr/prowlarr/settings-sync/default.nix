{
  config,
  lib,
  pkgs,
  ...
}: let
  inherit
    (lib)
    types
    pipe
    toSentenceCase
    isString
    filter
    concatMapStringsSep
    mkOption
    getExe
    split
    mkIf
    escapeShellArgs
    recursiveUpdate
    ;

  nixarr = config.nixarr;

  nixarr-utils = import ../../lib/utils.nix {inherit pkgs lib config;};
  inherit (nixarr-utils) call-prowlarr-api mkArrLocalUrl;

  cfg = nixarr.prowlarr.settings-sync;

  # TODO: move to `lib/utils.nix` if we end up reusing it for other systems.
  apply-fields = pkgs.writeShellApplication {
    name = "apply-fields";
    runtimeInputs = with pkgs; [jq coreutils];
    text = builtins.readFile ./apply-fields.sh;
  };

  prowlarr-sync-tags = pkgs.writeShellApplication {
    name = "prowlarr-sync-tags";
    runtimeInputs = with pkgs; [
      curl
      jq
      call-prowlarr-api
    ];
    text = builtins.readFile ./sync-tags.sh;
  };

  prowlarr-sync-indexers = pkgs.writeShellApplication {
    name = "prowlarr-sync-indexers";
    runtimeInputs = with pkgs; [
      curl
      jq
      call-prowlarr-api
      apply-fields
    ];
    text = builtins.readFile ./sync-indexers.sh;
  };

  prowlarr-sync-applications = pkgs.writeShellApplication {
    name = "prowlarr-sync-applications";
    runtimeInputs = with pkgs; [
      curl
      jq
      call-prowlarr-api
      apply-fields
    ];
    text = builtins.readFile ./sync-applications.sh;
  };

  arrSecretType = types.submodule {
    options = {
      secret = mkOption {
        type = types.pathWith {
          inStore = false; # Secret files should not be in the Nix store
          absolute = true;
        };
        description = ''
          Path to a file containing a secret value. Must be readable by the
          relevant service user or group!
        '';
      };
    };
  };

  arrCfgType = with types; attrsOf (oneOf [str bool int arrSecretType (listOf int) (listOf str)]);

  mkAppConfigType = {
    service,
    implementationName,
  }:
    types.submodule {
      freeformType = arrCfgType;
      options = {
        name = mkOption {
          type = types.str;
          # Turns `readarr` into `Readarr` and `readarr-audiobook` into
          # `Readarr-Audiobook`.
          default = pipe service [
            (split "-")
            (filter isString)
            (concatMapStringsSep "-" toSentenceCase)
          ];
          description = ''
            The name Prowlarr uses for this instance of an application. Note
            that app names must be unique among *all* apps (not just apps of
            this type), *ignoring case*.
          '';
        };
        implementationName = mkOption {
          type = types.str;
          default = implementationName;
          description = ''
            The implementation name of the application in Prowlarr. This is used
            to find the default configuration when adding a new application, and
            must match the existing application's implementation name when
            overwriting an existing application.
          '';
        };
        syncLevel = mkOption {
          type = types.enum [
            "fullSync" # AKA "Full Sync"
            "addOnly" # AKA "Add and Remove Only"
            "disabled" # AKA "Disabled"
          ];
          default = "fullSync";
          description = ''
            How Prowlarr should sync indexers with an application.
          '';
        };
        tagLabels = mkOption {
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

            To see available fields, run `${getExe call-prowlarr-api}
            application/schema`, find the definition of the application using
            `implementationName`, and inspect the `fields` property.

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
    implementationName ? toSentenceCase service,
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
        inherit service implementationName;
      };
      default = {};
      description = "Configuration for this application in Prowlarr.";
      example = {
        name = "My special service name";
        tagLabels = ["tag1" "tag2"];
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
      sortName = mkOption {
        type = types.str;
        description = ''
          The sort name of the indexer definition to base this indexer on. This
          is used to find the default configuration when adding a new indexer,
          and must match the existing indexer's sort name when overwriting an
          existing indexer.
        '';
      };
      appProfileName = mkOption {
        type = types.str;
        default = "Standard";
        description = ''
          The app profile to associate with this indexer. Must already exist.
          We look up this profile by name to set the appProfileId field on the
          indexer configuration.
        '';
      };
      tagLabels = mkOption {
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

          To see available fields, run `${getExe call-prowlarr-api}
          indexer/schema`, find the definition of the indexer using `sortName`,
          and inspect the `fields` property.
        ''; # TODO: add schema to `nixarr` utility command?
      };
    };
  };

  arrServiceNames = [
    "sonarr"
    "radarr"
    "lidarr"
    # These are blocked on https://github.com/rasmus-kirk/nixarr/pull/98
    # "readarr"
    # "readarr-audiobook"
  ];

  syncServiceNames =
    filter (name: nixarr.${name}.enable && cfg.apps.${name}.enable) arrServiceNames;

  extraGroups =
    map (service: config.users.groups."${service}-api".name)
    (syncServiceNames ++ ["prowlarr"]);

  wantedServices =
    map (service: "${service}-api-key.service")
    (syncServiceNames ++ ["prowlarr"]);

  syncAppsJson = pipe syncServiceNames [
    (
      map (name:
        recursiveUpdate
        {
          # TODO: we're only doing this here because if we just made these the
          # default values in the app config type and the user adds *any* field,
          # then *all* of the defaults would be overridden.
          fields = {
            prowlarrUrl = mkArrLocalUrl "prowlarr";
            baseUrl = mkArrLocalUrl name;
            apiKey.secret = "${nixarr.stateDir}/api-keys/${name}.key";
          };
        }
        cfg.apps.${name}.config)
    )
    builtins.toJSON
  ];
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
        # These are blocked on https://github.com/rasmus-kirk/nixarr/pull/98
        # readarr = mkAppOptions {service = "readarr";};
        # readarr-audiobook = mkAppOptions {
        #  service = "readarr-audiobook";
        #  implementationName = "Readarr";
        # };
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
        '';
        example = [
          {
            name = "My special indexer name";
            sortName = "nzbgeek";
            tagLabels = ["tag1" "tag2"];
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
        ExecStart = let
          prowlarr-sync-all = pkgs.writeShellApplication {
            name = "prowlarr-sync-all";
            runtimeInputs = [
              prowlarr-sync-tags
              prowlarr-sync-indexers
              prowlarr-sync-applications
            ];
            text = ''
              tagLabels=$1
              appConfigs=$2
              indexerConfigs=$3

              # Attempt to sync everything, but finally exit with failure if any
              # step failed.

              failed=0
              prowlarr-sync-tags "$tagLabels" || failed=1
              prowlarr-sync-indexers "$indexerConfigs" || failed=1
              prowlarr-sync-applications "$appConfigs" || failed=1
              if [ $failed -ne 0 ]; then
                exit 1
              fi
            '';
          };
        in ''
          ${getExe prowlarr-sync-all} ${escapeShellArgs [
            (builtins.toJSON cfg.tags)
            syncAppsJson
            (builtins.toJSON cfg.indexers)
          ]}
        '';
      };
    };
  };
}
