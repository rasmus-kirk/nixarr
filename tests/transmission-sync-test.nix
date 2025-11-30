{
  pkgs,
  nixosModules,
  lib ? pkgs.lib,
}:
pkgs.nixosTest {
  name = "transmission-sync-test";

  nodes.machine = {
    config,
    pkgs,
    ...
  }: {
    imports = [nixosModules.default];

    networking.firewall.enable = false;

    nixarr = {
      enable = true;

      transmission = {
        enable = true;
      };

      sonarr = {
        enable = true;
        settings-sync.transmission.enable = true;
      };

      radarr = {
        enable = true;
        settings-sync.transmission.enable = true;
      };
    };
  };

  testScript = ''
    machine.wait_for_unit("multi-user.target")

    # Check that main services are active
    machine.succeed("systemctl is-active transmission")
    machine.succeed("systemctl is-active sonarr")
    machine.succeed("systemctl is-active radarr")

    # These are oneshot services that may complete before we check them
    # Use wait_until_succeeds to handle both running and already-completed states

    machine.wait_until_succeeds("systemctl is-active sonarr-sync-config.service || systemctl status sonarr-sync-config.service | grep 'Active: inactive (dead)'")
    machine.succeed("systemctl status sonarr-sync-config.service | grep 'Result: success'")

    machine.wait_until_succeeds("systemctl is-active radarr-sync-config.service || systemctl status radarr-sync-config.service | grep 'Active: inactive (dead)'")
    machine.succeed("systemctl status radarr-sync-config.service | grep 'Result: success'")

    print("\n=== Transmission Sync Test Completed ===")
  '';
}
