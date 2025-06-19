---
title: Setup the applications
---

Here are some guides to help you set up the applications. We assume you left the
default ports; if you changed them, you will need to change the ports in the
URLs. Same if you are using a domain name—change the URLs to match. We assume
you are using the [first example](/wiki/examples/example-1) in your Nix
configuration. Replace {URL} in this document with your server IP or domain.
(You also can remove the port if not needed)

## Jellyfin

- Open your browser and go to `{URL}:8096`.
- Click `Add Server` and put your server address
- Follow the setup wizard:
  - Create your administrator account.
  - Setup two libraries:
    - Movies: Choose "Movies" as content type, then add the
      `/data/media/library/movies` folder.
    - TV Shows: Same with `/data/media/library` as the folder.
    - You can add music, books, etc.
  - Continue the setup.

**Optimisation**:

- Reduce the scan media library interval for small libraries: See
  `Scheduled Tasks`: {URL}:8096/web/index.html#/dashboard/tasks/

## Transmission

- ... ?

## Radarr

- Open your browser and go to `{URL}:7878`.
- You will be asked to set up a new account.
  - Choose `Forms` as the auth method and choose a username & password.
  - You can now log in.
- Go to "Settings" > "Media Management" > "Root Folders" and click
  `Add Root Folder`. Add `/data/media/library/movies/`, then click
  `Save Changes`.
- Go to "Settings" > "Download Clients" and add Transmission.

**Optimisation**:

- Go to {URL}:7878/settings/mediamanagement and set `Unmonitor Deleted Movies`
  to true.

## Sonarr

- Open your browser and go to `{URL}:8989`.
- You will be asked to set up a new account.
  - Choose `Forms` as the auth method and choose a username & password.
  - You can now log in.
- Go to "Settings" > "Media Management" > "Root Folders" and click
  `Add Root Folder`. Add `/data/media/library/shows/`, then click
  `Save Changes`.
- Go to "Settings" > "Download Clients" and add Transmission. Change the
  category to `sonarr`.

**Optimisation**:

- Go to {URL}:8989/settings/mediamanagement and set `Unmonitor Deleted Episodes`
  to true.

## Jellyseerr

- Open your browser and go to `{URL}:5055`.
- Follow the installation wizard:
  - Choose Jellyfin (or Plex).
  - Add your Jellyfin URL, username & password (you can leave the path empty and
    use a dummy email).
  - Click on `Sync Libraries` and toggle `Movies` and `Shows`, click `Next`.
  - Add your Radarr and Sonarr apps.
  - Get the API key by typing `sudo nixarr list-api-keys` in your terminal.

## Bazarr

- Open your browser and go to `{URL}:6767`.
- Go to "Settings" > "Languages":
  - select your preferred languages for subtitles in "Languages Filter", then
    add a languages profile
  - Add a "Default Language Profile" for "Series" and "Movies"
- Go to "Settings" > "Sonarr" and "Settings" > "Radarr" to add your respective
  Sonarr and Radarr instances.
  - Get the API key by typing `sudo nixarr list-api-keys` in your terminal.
  - Click `Test` to ensure the connection works, then `Save`.
- Go to "Settings" > "Providers" and enable the subtitle providers you want.

**Optimisation**:

- Go to {URL}:6767/settings/general and set `Unmonitor Deleted Subtitles` to
  true.

## Prowlarr

**Initial setup**:

- Open your browser and go to `{URL}:9696`.
- You will be asked to set up a new account.
  - Choose `Forms` as the auth method and choose a username & password.
  - You can now log in.
- Go to "Settings" > "Apps" and add your _Arrs_.
  - Get the API key by typing `sudo nixarr list-api-keys` in your terminal.

**Add indexers**:

- Open your browser and go to `{URL}:9696`.
- Click on the `Add Indexer` button.
- You can now add as many indexers as you want. We recommend filtering them by:
  - Protocol
  - Language
  - Privacy:
    - **Public**: Trackers/indexing sites open to anyone without registration.
    - **Semi-Private**: Require registration, but generally accessible.
    - **Private**: Require invitations or strict applications.
