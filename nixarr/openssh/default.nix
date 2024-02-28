{
  config,
  lib,
  ...
}:
with lib; let
  cfg = config.nixarr.openssh;
  nixarr = config.nixarr;
in {
  options.nixarr.openssh.expose.vpn.enable = mkOption {
    type = types.bool;
    default = false;
    description = ''
      **Required options:** [`nixarr.vpn.enable`](#nixarr.vpn.enable)

      Run the openssh service through a vpn, exposing it to the internet.
      
      **Important:** This lets anyone on the internet connect through SSH,
      make sure the SSH configuration is secure! Disallowing password
      authentication and only allowing SSH-keys is considered secure.

      **Note:** This option does _not_ enable the SSHD service you still
      need to setup sshd in your nixos configuration, fx:

      ```nix
        services.openssh = {
          enable = true;
          settings.PasswordAuthentication = false;
          # Get this port from your VPN provider
          ports [ 12345 ];
        };

        users.extraUsers.username.openssh.authorizedKeys.keyFiles = [
          ./path/to/public/key/machine.pub
        ];
      ```

      Then replace `username` with your username and the `keyFiles` path to a
      ssh public key file from the machine that you want to have access. Don't
      use password authentication as it is insecure!
    '';
  };

  config = mkIf cfg.vpn.enable {
    assertions = [
      {
        assertion = cfg.vpn.enable -> nixarr.vpn.enable;
        message = ''
          The nixarr.openssh.vpn.enable option requires the
          nixarr.vpn.enable option to be set, but it was not.
        '';
      }
    ];

    warnings = if config.services.openssh.enable then [
      ''
        nixarr.openssh.vpn.enable is set, but openssh is not enabled on your
        system, so the openssh server is not running. This is probably not
        what you wanted. You can add the following lines to enable it:

        services.openssh = {
          enable = true;
          settings.PasswordAuthentication = false;
          # Get this port from your VPN provider
          ports [ 12345 ];
        };

        users.extraUsers.username.openssh.authorizedKeys.keyFiles = [
          ./path/to/public/key/machine.pub
        ];

        Then replace username with your username and the keyFiles path
        to a ssh public key file from the machine that you want to have
        access. Don't use password authentication as it is insecure!
      ''
    ] else [];

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
