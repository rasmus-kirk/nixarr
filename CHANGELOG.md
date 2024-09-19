# Changelog

## 2024-09-19

Added:
- Options to control the package of each service
- sub-merge package to systemPkgs

Updated:
- All submodules (notably VPNConfinement)

## 2024-06-11

Updated:
- VPNConfinement submodule

## 2024-03-12

Added:
- `fix-permissions` script, that sets correct permissions for all directories
  and files in the state and media library

Fixed:
- Some permission issues here and there

## 2024-03-12

Added:
- bazarr
- njalla-vpn-ddns (ddns to public vpn ip)

Fixed:
- Cross-seed (wrong torrentdir)
- Opened firewall for services by default if you're not using vpn, this prevented users from connecting to services over local networks

Updated:
- Docs (stateDirs and mediaDir cannot be home!)
- vpn submodule (adds firewall and DNS-leak killswitch)

## 2024-03-14

Added:
- Reexported VPN-submodule, allowing users to run services, not supported by this module, through the VPN
