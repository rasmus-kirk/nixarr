---
title: Options Documentation
author: Rasmus Kirk
date: 2023-12-07
---

## kirk.nixosScripts.configDir
Path to the nixos configuration.

*_Type_*:
path


*_Default_*
```
"/etc/nixos"
```




## kirk.nixosScripts.enable
Whether to enable Nixos scripts

Required options:
- `machine`
.

*_Type_*:
boolean


*_Default_*
```
false
```


*_Example_*
```
true
```


## kirk.nixosScripts.machine
REQUIRED! The machine to run on.

*_Type_*:
null or string


*_Default_*
```
null
```




## kirk.servarr.acmeMail
REQUIRED! The ACME mail.

*_Type_*:
null or string


*_Default_*
```
null
```




## kirk.servarr.domainName
REQUIRED! The domain name to host jellyfin on.

*_Type_*:
null or string


*_Default_*
```
null
```




## kirk.servarr.enable
Whether to enable My servarr setup. Hosts Jellyfin on the given domain (remember domain
records/port forwarding) and hosts the following services on localhost
through a mullvad VPN:

- Prowlarr
- Sonarr
- Radarr
- Flood/Rtorrnet

Required options for this module:

- `domainName`
- `acmeMail`
- `mullvadAcc`

Remember to read the options.

NOTE: The docker service to manage this executes the command `docker
container prune -f` on startup for reproducibility, may cause issues
depending on your setup.

NOTE: This nixos module only supports the mullvad VPN, if you need
another VPN, create a PR or fork this repo!
.

*_Type_*:
boolean


*_Default_*
```
false
```


*_Example_*
```
true
```


## kirk.servarr.gluetun.extraConfig
Extra config for the service.

*_Type_*:
attribute set


*_Default_*
```
{}
```




## kirk.servarr.jellyfin.extraConfig
Extra config for the service.

*_Type_*:
attribute set


*_Default_*
```
{}
```




## kirk.servarr.jellyfin.port
Port of Jellyfin.

*_Type_*:
16 bit unsigned integer; between 0 and 65535 (both inclusive)


*_Default_*
```
8096
```




## kirk.servarr.mediaDir
The location of the media directory for the services.

*_Type_*:
path


*_Default_*
```
"~/servarr"
```




## kirk.servarr.mullvadAcc
REQUIRED! The location the file containing your mullvad account key.

*_Type_*:
null or path


*_Default_*
```
null
```




## kirk.servarr.prowlarr.extraConfig
Extra config for the service.

*_Type_*:
attribute set


*_Default_*
```
{}
```




## kirk.servarr.prowlarr.port
Port of prowlarr.

*_Type_*:
16 bit unsigned integer; between 0 and 65535 (both inclusive)


*_Default_*
```
6002
```




## kirk.servarr.radarr.extraConfig
Extra config for the service.

*_Type_*:
attribute set


*_Default_*
```
{}
```




## kirk.servarr.radarr.port
Port of radarr.

*_Type_*:
16 bit unsigned integer; between 0 and 65535 (both inclusive)


*_Default_*
```
6004
```




## kirk.servarr.rflood.extraConfig
Extra config for the service.

*_Type_*:
attribute set


*_Default_*
```
{}
```




## kirk.servarr.rflood.port
Port of rflood.

*_Type_*:
16 bit unsigned integer; between 0 and 65535 (both inclusive)


*_Default_*
```
6001
```




## kirk.servarr.rflood.ulimits.enable
Whether to enable Enable rtorrent ulimits. I had a bug that caused rtorrent to fail
and log `std::bad_alloc`. Setting ulimits for this service fixed
the issue. You probably don't want to set this unless you have
similar issues.See link below for more info:

https://stackoverflow.com/questions/75536471/rtorrent-docker-container-failing-to-start-saying-stdbad-alloc
.

*_Type_*:
boolean


*_Default_*
```
false
```


*_Example_*
```
true
```


## kirk.servarr.rflood.ulimits.hard
The hard limit.

*_Type_*:
unsigned integer, meaning >=0


*_Default_*
```
1024
```




## kirk.servarr.rflood.ulimits.soft
The soft limit.

*_Type_*:
unsigned integer, meaning >=0


*_Default_*
```
1024
```




## kirk.servarr.sonarr.extraConfig
Extra config for the service.

*_Type_*:
attribute set


*_Default_*
```
{}
```




## kirk.servarr.sonarr.port
Port of sonarr.

*_Type_*:
16 bit unsigned integer; between 0 and 65535 (both inclusive)


*_Default_*
```
6003
```




## kirk.servarr.stateDir
The location of the state directory for the services.

*_Type_*:
path


*_Default_*
```
"~/.local/state"
```




## kirk.servarr.timezone
Your timezone, used for logging purposes.

*_Type_*:
string


*_Default_*
```
"Etc/UTC"
```




