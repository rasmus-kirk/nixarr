# TODO: Dir creation and file permissions in nix
{
  pkgs,
  config,
  lib,
  ...
}:
with lib; let
  globals = config.util-nixarr.globals;
in {
  options.util-nixarr.globals = mkOption {
    type = types.attrs;
    description = "Global values to be used by Nixarr, change at your own risk.";
    default = {};
  };

  config.util-nixarr.globals = {
    libraryOwner.user = "root";
    libraryOwner.group = "media";

    uids = {
      plex = 193;
      jellyfin = 146;
      audiobookshelf = 156;
      autobrr = 188;
      bazarr = 232;
      lidarr = 306;
      prowlarr = 293;
      jellyseerr = 262;
      komga = 145;
      sonarr = 274;
      radarr = 275;
      readarr = 250;
      readarr-audiobook = 211;
      recyclarr = 269;
      sabnzbd = 38;
      transmission = 70;
      cross-seed = 183;
      whisparr = 272;
    };
    gids = {
      autobrr = 188;
      cross-seed = 183;
      jellyseerr = 250;
      media = 169;
      prowlarr = 287;
      recyclarr = 269;
    };

    audiobookshelf = {
      user = "audiobookshelf";
      group = globals.libraryOwner.group;
    };
    autobrr = {
      user = "autobrr";
      group = "autobrr";
    };
    bazarr = {
      user = "bazarr";
      group = globals.libraryOwner.group;
    };
    jellyfin = {
      user = "jellyfin";
      group = globals.libraryOwner.group;
    };
    jellyseerr = {
      user = "jellyseerr";
      group = "jellyseerr";
    };
    komga = {
      user = "komga";
      group = globals.libraryOwner.group;
    };
    lidarr = {
      user = "lidarr";
      group = globals.libraryOwner.group;
    };
    plex = {
      user = "plex";
      group = globals.libraryOwner.group;
    };
    prowlarr = {
      user = "prowlarr";
      group = "prowlarr";
    };
    radarr = {
      user = "radarr";
      group = globals.libraryOwner.group;
    };
    readarr = {
      user = "readarr";
      group = globals.libraryOwner.group;
    };
    readarr-audiobook = {
      user = "readarr-audiobook";
      group = globals.libraryOwner.group;
    };
    recyclarr = {
      user = "recyclarr";
      group = "recyclarr";
    };
    sabnzbd = {
      user = "sabnzbd";
      group = globals.libraryOwner.group;
    };
    sonarr = {
      user = "sonarr";
      group = globals.libraryOwner.group;
    };
    transmission = {
      user = "transmission";
      group = globals.libraryOwner.group;
    };
    cross-seed = {
      user = "cross-seed";
      group = "cross-seed";
    };
    whisparr = {
      user = "whisparr";
      group = globals.libraryOwner.group;
    };
  };
}
