# Nixarr

![Logo](./docs/img/logo-2.png)

This is a nixos module that aims to make the installation and management
of running the ["*Arrs"](https://wiki.servarr.com/) as easy, and pain free,
as possible.

If you have problems or feedback, feel free to join [the
discord](https://discord.gg/n9ga99KwWC).

Note that this is still in a somewhat alpha state, bugs are around and
options are still subject to change, but the general format won't change.

## Options

The documentation for the options can be found
[here](https://nixarr.rasmuskirk.com/options)

## Features

- **Run services through a VPN:** You can run any service that this module
  supports through a VPN, fx `nixarr.*.vpn.enable = true;`
- **Automatic Directories, Users and Permissions:** The module automatically
  creates directories and users for your media library. It also sets sane
  permissions.
- **State Management:** All services support state management and all state
  that they manage is by default in `/data/.state/nixarr/*`
- **Optional Automatic Port Forwarding:** This module has a UPNP module that
  lets services request ports from your router automatically, if you enable it.

To run services through a VPN, you must provide a wg-quick config file:

```nix {.numberLines}
nixarr.vpn = {
  enable = true;
  # IMPORTANT: This file must _not_ be in the config git directory
  # You can usually get this wireguard file from your VPN provider
  wgConf = "/data/.secret/wg.conf";
}
```

## Examples

Full example can be seen below:

```nix {.numberLines}
nixarr = {
  enable = true;
  # These two values are also the default, but you can set them to whatever
  # else you want
  mediaDir = "/data/media";
  stateDir = "/data/media/.state";

  vpn = {
    enable = true;
    # IMPORTANT: This file must _not_ be in the config git directory
    # You can usually get this wireguard file from your VPN provider
    wgConf = "/data/.secret/wg.conf";
  };

  jellyfin = {
    enable = true;
    # These options set up a nginx HTTPS reverse proxy, so you can access
    # Jellyfin on your domain with HTTPS
    expose = {
      enable = true;
      domainName = "your.domain.com";
      acmeMail = "your@email.com"; # Required for ACME-bot
    };
  };

  transmission = {
    enable = true;
    vpn.enable = true;
    peerPort = 50000; # Set this to the port forwarded by your VPN
  };

  # It is possible for this module to run the *Arrs through a VPN, but it
  # is generally not recommended, as it can cause rate-limiting issues.
  sonarr.enable = true;
  radarr.enable = true;
  prowlarr.enable = true;
  readarr.enable = true;
  lidarr.enable = true;
};
```

Another example where port forwarding is not an option. This could be useful
for example if you're living in a dorm without access to port forwarding:

```nix {.numberLines}
nixarr = {
  enable = true;

  vpn = {
    enable = true;
    wgConf = "/data/.secret/wg.conf";
  };

  jellyfin = {
    enable = true;
    vpn = {
      enable = true;
      # Access the Jellyfin web-ui from the internet
      openWebPort = true;
    };
  };

  transmission = {
    enable = true;
    vpn.enable = true;
    peerPort = 50000; # Set this to the port forwarded by your VPN
  };

  sonarr.enable = true;
  radarr.enable = true;
  prowlarr.enable = true;
  readarr.enable = true;
  lidarr.enable = true;
};
```

## VPN

It's recommended that the VPN you're using has support for port forwarding. I
suggest [AirVpn](https://airvpn.org/), since they accept Monero, but you can
use whatever you want.

## Domain Registrars

If you need a domain registrar I suggest [Njalla](https://njal.la/),
they are privacy-oriented, support DDNS and accept Monero. Note that you
don't technically "own" the domain for privacy reasons, they "lease" it to
you. However, this also means that you don't have to give _any_ personal data.
