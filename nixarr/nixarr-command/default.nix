{
  inputs,
  config,
  pkgs,
  lib,
  ...
}:
with lib; let
  nixarr = config.nixarr;
  globals = config.util-nixarr.globals;
  nixarr-command = pkgs.writeShellApplication {
    name = "nixarr";
    runtimeInputs = with pkgs; [util-linux];
    text = ''
      command="''${1:-}"

      # Check if a parameter is provided
      if [ -z "$command" ]; then
        echo "Usage: nixarr <command>"
        echo ""
        echo "Commands:"
        echo "  fix-permissions     Sets correct permissions for any directory managed by Nixarr."
        echo "  list-unlinked       Lists unlinked directories and files, in the given directory."
        echo "                      Use on the media directory to diagnose harddrive space issues."
        exit 1
      fi

      fix-permissions() {
        if [ "$EUID" -ne 0 ]; then
          echo "Please run as root"
          exit
        fi

        find "${nixarr.mediaDir}" \( -type d -exec chmod 0775 {} + -true \) -o \( -exec chmod 0664 {} + \)
        ${strings.optionalString nixarr.jellyfin.enable ''
          chown -R ${globals.libraryOwner.user}:${globals.libraryOwner.group} "${nixarr.mediaDir}/library"
          chown -R ${globals.jellyfin.user}:root "${nixarr.jellyfin.stateDir}"
          find "${nixarr.jellyfin.stateDir}" \( -type d -exec chmod 0700 {} + -true \) -o \( -exec chmod 0600 {} + \)
        ''}
        ${strings.optionalString nixarr.plex.enable ''
          chown -R ${globals.libraryOwner.user}:${globals.libraryOwner.group} "${nixarr.mediaDir}/library"
          chown -R ${globals.plex.user}:root "${nixarr.plex.stateDir}"
          find "${nixarr.plex.stateDir}" \( -type d -exec chmod 0700 {} + -true \) -o \( -exec chmod 0600 {} + \)
        ''}
        ${strings.optionalString nixarr.audiobookshelf.enable ''
          chown -R ${globals.libraryOwner.user}:${globals.libraryOwner.group} "${nixarr.mediaDir}/library"
          chown -R ${globals.audiobookshelf.user}:root "${nixarr.audiobookshelf.stateDir}"
          find "${nixarr.audiobookshelf.stateDir}" \( -type d -exec chmod 0700 {} + -true \) -o \( -exec chmod 0600 {} + \)
        ''}
        ${strings.optionalString nixarr.transmission.enable ''
          chown -R ${globals.transmission.user}:${globals.transmission.group} "${nixarr.mediaDir}/torrents"
          chown -R ${globals.transmission.user}:${globals.cross-seed.group} "${nixarr.transmission.stateDir}"
          find "${nixarr.transmission.stateDir}" \( -type d -exec chmod 0750 {} + -true \) -o \( -exec chmod 0640 {} + \)
        ''}
        ${strings.optionalString nixarr.sabnzbd.enable ''
          chown -R ${globals.sabnzbd.user}:${globals.sabnzbd.group} "${nixarr.mediaDir}/usenet"
          chown -R ${globals.sabnzbd.user}:root "${nixarr.sabnzbd.stateDir}"
          find "${nixarr.sabnzbd.stateDir}" \( -type d -exec chmod 0700 {} + -true \) -o \( -exec chmod 0600 {} + \)
        ''}
        ${strings.optionalString nixarr.transmission.privateTrackers.cross-seed.enable ''
          chown -R ${globals.cross-seed.user}:root "${nixarr.transmission.privateTrackers.cross-seed.stateDir}"
          find "${nixarr.transmission.privateTrackers.cross-seed.stateDir}" \( -type d -exec chmod 0700 {} + -true \) -o \( -exec chmod 0600 {} + \)
        ''}
        ${strings.optionalString nixarr.prowlarr.enable ''
          chown -R ${globals.prowlarr.user}:root "${nixarr.prowlarr.stateDir}"
          find "${nixarr.prowlarr.stateDir}" \( -type d -exec chmod 0700 {} + -true \) -o \( -exec chmod 0600 {} + \)
        ''}
        ${strings.optionalString nixarr.sonarr.enable ''
          chown -R ${globals.sonarr.user}:root "${nixarr.sonarr.stateDir}"
          find "${nixarr.sonarr.stateDir}" \( -type d -exec chmod 0700 {} + -true \) -o \( -exec chmod 0600 {} + \)
        ''}
        ${strings.optionalString nixarr.radarr.enable ''
          chown -R ${globals.radarr.user}:root "${nixarr.radarr.stateDir}"
          find "${nixarr.radarr.stateDir}" \( -type d -exec chmod 0700 {} + -true \) -o \( -exec chmod 0600 {} + \)
        ''}
        ${strings.optionalString nixarr.lidarr.enable ''
          chown -R ${globals.lidarr.user}:root "${nixarr.lidarr.stateDir}"
          find "${nixarr.lidarr.stateDir}" \( -type d -exec chmod 0700 {} + -true \) -o \( -exec chmod 0600 {} + \)
        ''}
        ${strings.optionalString nixarr.bazarr.enable ''
          chown -R ${globals.bazarr.user}:root "${nixarr.bazarr.stateDir}"
          find "${nixarr.bazarr.stateDir}" \( -type d -exec chmod 0700 {} + -true \) -o \( -exec chmod 0600 {} + \)
        ''}
        ${strings.optionalString nixarr.readarr.enable ''
          chown -R ${globals.readarr.user}:root "${nixarr.readarr.stateDir}"
          find "${nixarr.readarr.stateDir}" \( -type d -exec chmod 0700 {} + -true \) -o \( -exec chmod 0600 {} + \)
        ''}
        ${strings.optionalString nixarr.readarr-audiobook.enable ''
          chown -R ${globals.readarr.user}:root "${nixarr.readarr-audiobook.stateDir}"
          find "${nixarr.readarr-audiobook.stateDir}" \( -type d -exec chmod 0700 {} + -true \) -o \( -exec chmod 0600 {} + \)
        ''}
        ${strings.optionalString nixarr.jellyseerr.enable ''
          chown -R ${globals.jellyseerr.user}:root "${nixarr.jellyseerr.stateDir}"
          find "${nixarr.jellyseerr.stateDir}" \( -type d -exec chmod 0700 {} + -true \) -o \( -exec chmod 0600 {} + \)
        ''}
        ${strings.optionalString nixarr.autobrr.enable ''
          chown -R ${globals.autobrr.user}:root "${nixarr.autobrr.stateDir}"
          find "${nixarr.autobrr.stateDir}" \( -type d -exec chmod 0700 {} + -true \) -o \( -exec chmod 0600 {} + \)
        ''}
        ${strings.optionalString nixarr.recyclarr.enable ''
          chown -R ${globals.recyclarr.user}:root "${nixarr.recyclarr.stateDir}"
          find "${nixarr.recyclarr.stateDir}" \( -type d -exec chmod 0700 {} + -true \) -o \( -exec chmod 0600 {} + \)
        ''}
      }

      list-unlinked() {
        if [ "$#" -ne 1 ]; then
            echo "Illegal number of parameters. Must be one file path"
        fi

        find "$1" -type f -links 1 -exec du -h {} + | sort -h
      }

      # Handle the command
      case "$1" in
        fix-permissions)
          fix-permissions
          ;;
        list-unlinked)
          if [ "$#" -ne 1 ]; then
              echo "Illegal number of parameters. Must be one file path"
          fi

          find "$1" -type f -links 1 -exec du -h {} + | sort -h
          ;;
      esac
    '';
  };
in {
  config.environment.systemPackages = [ nixarr-command ];
}
