{
  config,
  pkgs,
  ...
}: let
  mkArrLocalUrl = service: let
    server = config.services.${service}.settings.server;
  in "http://127.0.0.1:${toString server.port}${server.urlBase}";

  mkArrApiScript = service:
    pkgs.writeShellApplication {
      name = "call-${service}-api";
      runtimeInputs = [pkgs.curl];
      text = ''
        url=$1
        shift
        apiKey=$(<'${config.nixarr.stateDir}/api-keys/${service}.key') || {
          echo "Failed to read API key for ${service}. Has the systemd unit"
          echo "${service}-api-key.service completed? Are you running as root,"
          echo "or as part of the ${service} or ${service}-api groups?"
          exit 1
        }
        exec curl \
          "''${@}" \
          --fail \
          --location \
          --insecure \
          --silent \
          --header "X-Api-Key: $apiKey" \
          "${mkArrLocalUrl service}/api/v1/$url"
      '';
    };
in {
  inherit mkArrLocalUrl;

  call-lidarr-api = mkArrApiScript "lidarr";
  call-prowlarr-api = mkArrApiScript "prowlarr";
  call-radarr-api = mkArrApiScript "radarr";
  call-sonarr-api = mkArrApiScript "sonarr";
  # These are blocked on https://github.com/rasmus-kirk/nixarr/pull/98
  # call-readarr-api = mkApiScript "readarr";
  # call-readarr-audiobook-api = mkApiScript "readarr-audiobook
}
