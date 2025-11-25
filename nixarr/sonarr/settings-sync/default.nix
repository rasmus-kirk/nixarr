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
    recursiveUpdate
    ;

  inherit
    (pkgs.writers)
    writeJSON
    writePython3Bin
    ;

  nixarr = config.nixarr;
  globals = config.util-nixarr.globals;
  cfg = nixarr.sonarr.settings-sync;

  nixarr-utils = import ../../lib/utils.nix {inherit pkgs lib config;};
  inherit (nixarr-utils) arrCfgType;

  nixarr-py = import ../../lib/nixarr-py {inherit pkgs lib config;};

  show-schemas = writePython3Bin "nixarr-show-sonarr-schemas" {
    libraries = [nixarr-py];
    flakeIgnore = [
      "E501" # Line too long
    ];
  } (builtins.readFile ./show_schemas.py);

  sync-settings = writePython3Bin "nixarr-sync-sonarr-settings" {
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
          The name Sonarr uses for this download client.
          Note that names must be unique among *all download clients*, *ignoring case*.
        '';
      };
      implementation = mkOption {
        type = types.str;
        description = ''
          The implementation name of the download client in Sonarr. This is used
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

  wantedServices = ["sonarr-api-key.service"];
in {
  options = {
    nixarr.sonarr.settings-sync = {
      downloadClients = mkOption {
        type = with types; listOf downloadClientConfigType;
        default = [];
        description = ''
          List of download clients to configure in Sonarr.

          To see available top-level properties and `fields` members for each
          download client, run `${getExe show-schemas} download_client | jq '.'` as root.
        '';
      };

      transmission.enable = mkOption {
        type = types.bool;
        default = false;
        description = ''
          Automatically configure Transmission as a download client in Sonarr.
          Requires `nixarr.transmission.enable` to be true.
        '';
      };
    };
  };

  config = mkIf (nixarr.enable && nixarr.sonarr.enable) {
    # Add Transmission config if enabled
    nixarr.sonarr.settings-sync.downloadClients = mkIf cfg.transmission.enable [
      {
        name = "Transmission";
        implementation = "Transmission";
        enable = true;
        fields = {
          host = "localhost";
          port = nixarr.transmission.uiPort;
          useSsl = false;
          # If VPN is enabled, we might need to adjust settings, but localhost should work
          # if both are in the same network namespace or if we use the VPN IP.
          # However, Sonarr and Transmission might be in different namespaces if VPN is on.
          # If VPN is on for Transmission, it's in 'wg' namespace.
          # If VPN is on for Sonarr, it's in 'wg' namespace.
          # If both are in 'wg', localhost works? No, they are in the same netns?
          # Wait, nixarr uses vpnNamespaces.wg.
          # If both are enabled for VPN, they share the namespace.
          # If only Transmission is enabled for VPN, Sonarr (on host) cannot reach localhost:9091 easily if it's confined?
          # Actually, nixarr exposes ports via socat/nginx usually?
          # Let's look at how Prowlarr connects to things.
          # Prowlarr uses http://localhost:9696/1/api?apikey=...
          # Transmission exposes RPC on uiPort.
          # If Transmission is in VPN, it exposes port to host via portMappings?
          # Let's assume localhost works for now or use the logic from Prowlarr/Transmission interaction.
          # In Transmission module:
          # rpc-bind-address = if cfg.vpn.enable then "192.168.15.1" else "0.0.0.0";
          # And nginx proxies 127.0.0.1:uiPort to 192.168.15.1:uiPort.
          # So localhost:uiPort on host should work because of Nginx proxy!
        };
      }
    ];

    users.users.sonarr.extraGroups = ["sonarr-api"];

    environment.systemPackages = [show-schemas];

    systemd.services.sonarr-sync-config = {
      description = ''
        Sync Sonarr configuration (download clients)
      '';
      after = wantedServices ++ ["sonarr.service"];
      wants = wantedServices;
      wantedBy = ["sonarr.service" "multi-user.target"];
      serviceConfig = {
        Type = "oneshot";
        Restart = "on-failure";
        RestartSec = "10s";
        User = globals.sonarr.user;
        Group = globals.sonarr.group;
        ExecStart = let
          config-file = writeJSON "sonarr-sync-config.json" {
            download_clients = cfg.downloadClients;
          };
        in ''
          ${getExe sync-settings} --config-file ${config-file}
        '';
      };
    };
  };
}
