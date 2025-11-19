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

    # Check that sync services ran successfully
    # We use 'systemctl status' to check if it exited with success (0)
    # Since they are oneshot services, they might be 'inactive' (dead) but the result should be 'success'
    
    # Wait for them to finish (they are wantedBy sonarr/radarr so they should start around the same time)
    # But they depend on api-key services which depend on the main services being up? 
    # No, api-key services wait for the file to exist.
    # The sync services wait for api-key services AND the main service (added in my fix).
    
    # Let's wait for the sync services to be active or finished.
    # Since they are oneshot, we can't wait_for_unit("...service") because it might exit quickly.
    # But we can check if they *failed*.
    
    machine.wait_until_succeeds("systemctl is-active sonarr-sync-config.service || systemctl status sonarr-sync-config.service | grep 'Active: inactive (dead)'")
    machine.succeed("systemctl status sonarr-sync-config.service | grep 'Result: success'")

    machine.wait_until_succeeds("systemctl is-active radarr-sync-config.service || systemctl status radarr-sync-config.service | grep 'Active: inactive (dead)'")
    machine.succeed("systemctl status radarr-sync-config.service | grep 'Result: success'")

    print("\n=== Transmission Sync Test Completed ===")
  '';
}
