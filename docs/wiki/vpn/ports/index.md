---
title: Opening Ports
---

In order to open a port through a VPN you need to open a port with your VPN-provider.

**Note:** Not all VPN-providers support this feature! Notably, Mullvad does not anymore!

**Note:** The port present in the
  [nixarr.vpn.wgConf](https://nixarr.com/options.html#nixarr.vpn.wgconf),
  should not be used for any options!

## AirVPN

Go to the [ports page](https://airvpn.org/ports/) at AirVPN's website open
a port. After opening it should look like this:

![An open port on AirVPN, the port number that should be used in Nixarr is 12345.](airvpn.png)

Then you can set that port for a service, for example

```nix {.numberLines}
  nixarr.transmission = {
    enable = true;
    vpn.enable = true;
    peerPort = 12345;
  };
```

## Debugging Ports

You can debug an open port using the
[nixarr.vpn.vpnTestService](https://nixarr.com/options.html#nixarr.vpn.vpntestservice.enable).
If the DNS and IP checks out, it will
open a `netcat` instance on the port specified in
[nixarr.vpn.vpnTestService.port](https://nixarr.com/options.html#nixarr.vpn.vpntestservice.port).
You can then run:

```sh
  nc <public VPN ip> <specified port>
```

Where the "_public VPN ip_" is the one shown in the `vpnTestService` logs as
your ip. Upon succesful connection type messages that _should_ show up in the
`vpnTestService` logs.
