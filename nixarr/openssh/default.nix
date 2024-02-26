# TODO: Dir creation and file permissions in nix
{
  config,
  lib,
  ...
}:
with lib; let
  cfg = config.nixarr.openssh;
in {
  options.nixarr.openssh.vpn.enable = {
    type = types.bool;
    default = false;
    description = ''
      Run the openssh service through a vpn.
      
      **Note:** This option does _not_ enable the sshd service you still
      need to setup sshd in your nixos configuration, fx:

      ```nix
        services.openssh = {
          enable = true;
          settings.PasswordAuthentication = false;
        };

        users.extraUsers.username.openssh.authorizedKeys.keyFiles = [
          ./path/to/public/key/machine.pub}
        ];
      ```
    '';
  };

  config = mkIf (cfg.vpn.enable && config.services.openssh.enable) {
    util-nixarr.vpnnamespace = {
      portMappings = builtins.map (x: { From = x; To = x; }) config.services.openssh.ports;
      openUdpPorts = config.services.openssh.ports;
      openTcpPorts = config.services.openssh.ports;
    };

    systemd.services.openssh = {
      bindsTo = [ "netns@wg.service" ];
      requires = [ "network-online.target" ];
      after = [ "wg.service" ];
      serviceConfig = {
        NetworkNamespacePath = "/var/run/netns/wg";
      };
    };
  };
}
