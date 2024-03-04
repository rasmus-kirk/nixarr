# Nixarr

![Logo](./docs/img/logo-2.png)

This is a Nixos module that aims to make the installation and management
of running the ["*Arrs"](https://wiki.servarr.com/) as easy, and pain free,
as possible.

If you have problems or feedback, feel free to join [the
discord](https://discord.gg/n9ga99KwWC).

Note that this is still in a somewhat alpha state, beware!

- Bugs are around
- Options are still subject to change
- Some options are mostly untested

The general format won't change however. If you do still use it, any feedback
is greatly appreciated.

## Features

- **Run services through a VPN:** You can run any service that this module
  supports through a VPN, fx `nixarr.transmission.vpn.enable = true;`
- **Automatic Directories, Users and Permissions:** The module automatically
  creates directories and users for your media library. It also sets sane
  permissions.
- **State Management:** All services support state management and all state
  that they manage is located by default in `/data/.state/nixarr/*`
- **Optional Dynamic DNS support:** If you use [Njalla](https://njal.la/)
  and don't have a static IP, you can use the `nixarr.ddns.njalla.enable`
  option to dynamically update a DNS record that points to the dynamic public
  IP of your server.
- **Optional Automatic Port Forwarding:** This module has a UPNP support that
  lets services request ports from your router automatically, if you enable it.

To run services through a VPN, you must provide a wg-quick config file,
that is provided by most VPN providers:

```nix {.numberLines}
  nixarr.vpn = {
    enable = true;
    # IMPORTANT: This file must _not_ be in the config git directory
    # You can usually get this wireguard file from your VPN provider
    wgConf = "/data/.secret/wg.conf";
  }
```

It is possible, _but not recommended_, to run the "*Arrs" behind a VPN,
because it can cause rate limiting issues.

## Options

The documentation for the options can be found
[here](https://nixarr.rasmuskirk.com/options)

## The Wiki

If you want to know how to setup DDNS with Njalla, or how to manage secrets
in nix, check out the [wiki](https://nixarr.rasmuskirk.com/wiki/)

## Importing this module

To use this module, add it to your flake inputs in your nix flake file,
like shown in this example flake:

```nix {.numberLines}
  {
    description = "Your nix flake";

    inputs = {
      nixpkgs.url = "github:nixos/nixpkgs/nixos-unstable";
      nixarr.url = "github:rasmus-kirk/nixarr";
    };

    outputs = { 
      nixpkgs,
      nixarr,
      ...
    }@inputs: {
      nixosConfigurations = {
        servarr = nixpkgs.lib.nixosSystem {
          system = "x86_64-linux";

          modules = [
            ./nixos/servarr/configuration.nix
            nixarr.nixosModules.default
          ];

          specialArgs = { inherit inputs; };
        };
      };
    };
  }
```

## Examples

This example does the following:

- Runs a jellyfin server and exposes it to the internet with HTTPS support.
- Runs the transmission torrent client through a vpn
- Runs all "*Arrs" supported by this module

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
      expose.https = {
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

Another example where port forwarding is not an option. This is useful if,
for example, you're living in a dorm that does not allow port forwarding. This
example does the following:

- Runs Jellyfin and exposes it to the internet on a set port
- Starts openssh and runs it through the VPN so that it can be accessed
  outside your home network
- Runs all the supported "*Arrs"

**Warning:** This is largely untested ATM!

```nix {.numberLines}
  nixarr = {
    enable = true;

    vpn = {
      enable = true;
      wgConf = "/data/.secret/wg.conf";
    };

    jellyfin = {
      enable = true;
      vpn.enable = true;

      # Access the Jellyfin web-ui from the internet.
      # Get this port from your VPN provider
      expose.vpn = {
        enable = true;
        port = 12345;
      };
    };

    # Setup SSH service that runs through VPN.
    # Lets you connect through ssh from the internet without having access to
    # port forwarding
    openssh.expose.vpn.enable = true;

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

  # The `openssh.vpn.enable` option does not enable openssh, so we do that here:
  # We disable password authentication as it's generally insecure.
  services.openssh = {
    enable = true;
    settings.PasswordAuthentication = false;
    # Get this port from your VPN provider
    ports = [ 54321 ]
  };
  # Adds your public keys as trusted devices
  users.extraUsers.username.openssh.authorizedKeys.keyFiles = [
    ./path/to/public/key/machine.pub}
  ];
```

In both examples, you don't have access to the "*Arrs" or torrent client
without being on your home network or accessing them through localhost. If
you have SSH setup you can use SSH tunneling. Simply run:

```sh
  ssh -N user@ip \
    -L 6001:localhost:9091 \
    -L 6002:localhost:9696 \
    -L 6003:localhost:8989 \
    -L 6004:localhost:7878 \
    -L 6005:localhost:8686 \
    -L 6006:localhost:8787
```

Replace `user` with your user and `ip` with the public ip, or domain if set
up, of your server. This lets you access the services on `localhost:6000`
through `localhost:6006`.

Another solution is to use [tailscale](https://tailscale.com/) or to setup
your own VPN [manually with wireguard](https://nixos.wiki/wiki/WireGuard).


## VPN Providers

Your VPN-provider should at the very least support wg-quick configurations,
this module does not, and will not, support any other setup. Most VPN-providers
should support this ATM.

Secondly, it's recommended that the VPN you're using has support for _static_
port forwarding as this module has no builtin support for dynamic port
forwarding. I suggest [AirVpn](https://airvpn.org/), since they support
static port forwarding, support wg-quick configurations and accept Monero,
but you can use whatever you want.

## Domain Registrars

If you need a domain registrar I suggest [Njalla](https://njal.la/),
they are privacy-oriented, support DDNS and accept Monero. Note that you
don't technically "own" the domain for privacy reasons, they "lease" it to
you. However, this also means that you don't have to give _any_ personal data.

## Thanks

A big thanks to [Maroka-chan](https://github.com/Maroka-chan) for the heavy
lifting on the [VPN-submodule](https://github.com/Maroka-chan/VPN-Confinement),
that was integral to making this project possible.

I would also like to thank [Lasse](https://github.com/lassebomh) for helping
out with the website.
