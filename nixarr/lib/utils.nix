{
  config,
  pkgs,
  ...
}: let
  mkArrLocalUrl = service: let
    server = config.services.${service}.settings.server;
  in "http://127.0.0.1:${toString server.port}${server.urlBase}";

  mkArrApiScript = service: version:
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
          "${mkArrLocalUrl service}/api/v${toString version}/$url"
      '';
    };
in {
  inherit mkArrLocalUrl;

  call-lidarr-api = mkArrApiScript "lidarr" 1;
  call-prowlarr-api = mkArrApiScript "prowlarr" 1;
  call-radarr-api = mkArrApiScript "radarr" 3;
  call-sonarr-api = mkArrApiScript "sonarr" 3;
  # These are blocked on https://github.com/rasmus-kirk/nixarr/pull/98
  # call-readarr-api = mkApiScript "readarr" 1;
  # call-readarr-audiobook-api = mkApiScript "readarr-audiobook" 1;
}
