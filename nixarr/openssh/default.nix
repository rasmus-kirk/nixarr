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

  config = mkIf cfg.enable {
    systemd.services.openssh = mkIf (cfg.vpn.enable && config.services.openssh.enable) {
      bindsTo = [ "netns@wg.service" ];
      requires = [ "network-online.target" ];
      after = [ "wg.service" ];
      serviceConfig = {
        NetworkNamespacePath = "/var/run/netns/wg";
      };
    };
  };
}
