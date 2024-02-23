# Nixarr

![Logo](./docs/img/logo-1.webp)

This is a nixos module that aims to make the installation and management of
running the "*Arrs" as easy, and pain free, as possible.

If you have problems or feedback, feel free to join [the
discord](https://discord.gg/n9ga99KwWC).

Note that this is still in a somewhat alpha state and options are still 
subject to change.

## Options

The documentation for the options can be found
[here](https://nixarr.rasmuskirk.com/)

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

```nix
nixarr.vpn = {
  enable = true;
  # IMPORTANT: This file must _not_ be in the config git directory
  # You can usually get this wireguard file from your VPN provider
  wgConf = "/data/.secret/wg.conf";
}
```

## Examples

Full example can be seen below:

```nix
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

Another example where port forwarding is not an option. This could be for
example if you're living in a dorm:

```nix
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

## Todo

### DDNS

Add DDNS-support.

- [ ] Njalla

### State Directories

- [x] Jellyfin: Works
- [x] Prowlarr: Works
- [x] Sonarr: Works
- [x] Radarr: Works
- [x] Lidarr: Works
- [x] Readarr: Works
- [ ] Transmission: Works for VPN, get weird bug, if
  `services.transmission.dataDir` is set.

### Buildarr

Using buildarr would allow setup services to integrate with each other upon
activation with no user input, definitely nice.

Needs to be added to nixpkgs, not too hard, but is not worth it if the
project is abandoned.

- [ ] Package with nix
- [ ] Add to nixpkgs

### DNS leaks

Prevent DNS leaks _without using containerization,_ as is currently done. No
idea how this could be done, but would simplify things _a lot_.

### cross-seed

Create support for the [cross-seed](https://github.com/cross-seed/cross-seed) service.

- [ ] Package with nix
- [ ] Create nix service daemon
- [ ] Add to nixpkgs
