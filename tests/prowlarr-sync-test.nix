{
  pkgs,
  nixosModules,
}:
pkgs.testers.runNixOSTest {
  name = "prowlarr-sync-test";

  nodes.machine = {
    config,
    pkgs,
    ...
  }: {
    imports = [
      nixosModules.default
    ];

    services = {
      prowlarr.settings.auth.required = "DisabledForLocalAddresses";
      sonarr.settings.auth.required = "DisabledForLocalAddresses";
      radarr.settings.auth.required = "DisabledForLocalAddresses";
    };

    virtualisation.cores = 4; # one per service plus one for luck

    networking.firewall.enable = false;

    nixarr = {
      enable = true;

      prowlarr = {
        enable = true;
        settings-sync = {
          enable-nixarr-apps = true;
          tags = ["a" "b"];
        };
      };

      sonarr = {
        enable = true;
      };

      radarr = {
        enable = true;
      };
    };
  };

  testScript = ''
    machine.wait_for_unit("multi-user.target")

    # Check that main services are active
    machine.succeed("systemctl is-active prowlarr")
    machine.succeed("systemctl is-active sonarr")
    machine.succeed("systemctl is-active radarr")

    # These are oneshot services that may complete before we check them
    # Use wait_until_succeeds to handle both running and already-completed states

    machine.wait_until_succeeds("systemctl is-active prowlarr-sync-config.service || systemctl status prowlarr-sync-config.service | grep 'Active: inactive (dead)'")
    machine.succeed("systemctl status prowlarr-sync-config.service | grep 'Result: success'")

    print("\n=== Prowlarr Sync Test Completed ===")
  '';
}
