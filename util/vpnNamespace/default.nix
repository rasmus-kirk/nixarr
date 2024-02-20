{ lib, pkgs, config, ... }: 
# Thanks to Maroka-chan...
# TODO: Make it so you can make multiple namespaces by giving a list of
# objects with settings as attributes. Also add an option to enable whether
# the namespace should use a vpn or not.
with builtins;
with lib;
let
  cfg = config.kirk.vpnnamespace;
in {
  options.kirk.vpnnamespace = {
    enable = mkEnableOption (lib.mdDoc "VPN Namespace") // {
      description = lib.mdDoc ''
        Whether to enable the VPN namespace.

        To access the namespace a veth pair is used to
        connect the vpn namespace and the default namespace
        through a linux bridge. One end of the pair is
        connected to the linux bridge on the default namespace.
        The other end is connected to the vpn namespace.

        Systemd services can be run within the namespace by
        adding these options:

        bindsTo = [ "netns@wg.service" ];
        requires = [ "network-online.target" ];
        after = [ "wg.service" ];
        serviceConfig = {
          NetworkNamespacePath = "/var/run/netns/wg";
        };
      '';
    };

    accessibleFrom = mkOption {
      type = types.listOf types.str;
      default = [ ];
      description = lib.mdDoc ''
        Subnets or specific addresses that the namespace should be accessible to.
      '';
      example = [
        "10.0.2.0/24"
        "192.168.1.27"
      ];
    };

    namespaceAddress = mkOption {
      type = types.str;
      default = "192.168.15.1";
      description = lib.mdDoc ''
        The address of the veth interface connected to the vpn namespace.
        
        This is the address used to reach the vpn namespace from other
        namespaces connected to the linux bridge.
      '';
    };

    bridgeAddress = mkOption {
      type = types.str;
      default = "192.168.15.5";
      description = lib.mdDoc ''
        The address of the linux bridge on the default namespace.

        The linux bridge sits on the default namespace and
        needs an address to make communication between the
        default namespace and other namespaces on the
        bridge possible.
      '';
    };

    wireguardAddressPath = mkOption {
      type = types.path;
      default = "";
      description = lib.mdDoc ''
        The address for the wireguard interface.
        It is a path to a file containing the address.
        This is done so the whole wireguard config can be specified
        in a secret file.
      '';
    };

    wireguardConfigFile = mkOption {
      type = types.path;
      default = "/etc/wireguard/wg0.conf";
      description = lib.mdDoc ''
        Path to the wireguard config to use.
        
        Note that this is not a wg-quick config.
      '';
    };

    portMappings = mkOption {
      type = with types; listOf (attrsOf port);
      default = [];
      description = lib.mdDoc ''
        A list of pairs mapping a port from the host to a port in the namespace.
      '';
      example = [{
        From = 80;
        To = 80;
      }];
    };

    dnsServers = mkOption {
      type = with types; nullOr (listOf str);
      default = loadDns wireguardConfigFile; #[ "1.1.1.2" ];
      description = lib.mdDoc ''
        YOUR VPN WILL LEAK IF THIS IS NOT SET. The dns address of your vpn.
      '';
      example = [ "1.1.1.2" ];
    };

    openTcpPorts = mkOption {
      type = with types; listOf port;
      default = [];
      description = lib.mdDoc ''
        What TCP ports to allow incoming traffic from. You need this if
        you're port forwarding on your VPN provider.
      '';
      example = [ 46382 38473 ];
    };

    openUdpPorts = mkOption {
      type = with types; listOf port;
      default = [];
      description = lib.mdDoc ''
        What UDP ports to allow incoming traffic from. You need this if
        you're port forwarding on your VPN provider.
      '';
      example = [ 46382 38473 ];
    };

    vpnTestService = {
      enable = mkEnableOption "Enable the vpn test service.";

      port = mkOption {
        type = types.port;
        default = [ 12300 ];
        description = lib.mdDoc ''
          The port that the vpn test service listens to.
        '';
        example = [ 58403 ];
      };
    };
  };

  config = 
  let
      headMay = list: if list == [] then null else head list; 
      # Checks if string is ipv4, from SO, hope it works well
      # https://stackoverflow.com/questions/53497/regular-expression-that-matches-valid-ipv6-addresses
      isIpv4 = address:
        let pat = "((25[0-5]|(2[0-4]|1{0,1}[0-9]){0,1}[0-9])\\.){3,3}(25[0-5]|(2[0-4]|1{0,1}[0-9]){0,1}[0-9])?/?[0-9]?[0-9]";
            regex = match pat address;
        in regex != null;
      # Checks if string is ipv6, from SO, hope it works well
      # https://stackoverflow.com/questions/53497/regular-expression-that-matches-valid-ipv6-addresses
      isIpv6 = address:
        let pat = "(([0-9a-fA-F]{1,4}:){7,7}[0-9a-fA-F]{1,4}|([0-9a-fA-F]{1,4}:){1,7}:|([0-9a-fA-F]{1,4}:){1,6}:[0-9a-fA-F]{1,4}|([0-9a-fA-F]{1,4}:){1,5}(:[0-9a-fA-F]{1,4}){1,2}|([0-9a-fA-F]{1,4}:){1,4}(:[0-9a-fA-F]{1,4}){1,3}|([0-9a-fA-F]{1,4}:){1,3}(:[0-9a-fA-F]{1,4}){1,4}|([0-9a-fA-F]{1,4}:){1,2}(:[0-9a-fA-F]{1,4}){1,5}|[0-9a-fA-F]{1,4}:((:[0-9a-fA-F]{1,4}){1,6})|:((:[0-9a-fA-F]{1,4}){1,7}|:)|fe80:(:[0-9a-fA-F]{0,4}){0,4}%[0-9a-zA-Z]{1,}|::(ffff(:0{1,4}){0,1}:){0,1}((25[0-5]|(2[0-4]|1{0,1}[0-9]){0,1}[0-9])\\.){3,3}(25[0-5]|(2[0-4]|1{0,1}[0-9]){0,1}[0-9])|([0-9a-fA-F]{1,4}:){1,4}:((25[0-5]|(2[0-4]|1{0,1}[0-9]){0,1}[0-9])\\.){3,3}(25[0-5]|(2[0-4]|1{0,1}[0-9]){0,1}[0-9]))";
            regex = match pat address;
        in regex != null;
      isIp = ip: (isIpv4 ip || isIpv6 ip);
  in
  mkIf cfg.enable {
    lib.vpn = {
      dnsServers =
        let lines = split "\n" (readFile cfg.wireguardConfigFile); 
            dnsLine = headMay (filter (x: typeOf x == "string" && match ".*DNS.*" x != null) lines); 
        in if dnsLine == null then [] else let
            ipsUnsplit = head (match "DNS ?=(.*)" dnsLine);
        in if ipsUnsplit == null then [] else let
            ips = filter (x: typeOf x == "string") (split "," ipsUnsplit);
            ipsNoSpaces = map (replaceStrings [" "] [""]) ips;
            correctIps = filter isIp ipsNoSpaces;
        in
          assert ( correctIps != [] ) || abort "There must be at least 1 DNS server set.";
          correctIps;
    };
  
    boot.kernel.sysctl."net.ipv4.ip_forward" = 1;

    systemd.services = {
      "netns@" = {
        description = "%I network namespace";
        before = [ "network.target" ];
        serviceConfig = {
          Type = "oneshot";
          RemainAfterExit = true;
          ExecStart = "${pkgs.iproute2}/bin/ip netns add %I";
          ExecStop = "${pkgs.iproute2}/bin/ip netns del %I";
        };
      };

      wg = {
        description = "wg network interface";
        bindsTo = [ "netns@wg.service" ];
        requires = [ "network-online.target" ];
        after = [ "netns@wg.service" ];
        wantedBy = [ "netns@wg.service" ];

        serviceConfig = let 
          lines = split "\n" (readFile cfg.wireguardConfigFile); 
          addrLine = headMay (filter (x: typeOf x == "string" && match ".*Address.*" x != null) lines); 
          in if addrLine == null then [] else let
          ipsUnsplit = head (match "Address ?=(.*)" addrLine);
          in if ipsUnsplit == null then [] else let
          ips = filter (x: typeOf x == "string") (split "," ipsUnsplit);
          ipsNoSpaces = map (replaceStrings [" "] [""]) ips;
          wgIpv4Address = headMay (filter isIpv4 ipsNoSpaces);

          vpn-namespace = pkgs.writeShellApplication {
            name = "vpn-namespace";

            runtimeInputs = with pkgs; [ iproute2 wireguard-tools iptables ];

            text = ''
              # Set up the wireguard interface
              tmpdir=$(mktemp -d) 
              cat ${cfg.wireguardConfigFile} > "$tmpdir/wg.conf"

              # Get dns servers
              grep "DNS =" "$tmpdir/wg.conf" | sed 's/DNS =//g' | sed 's/,/\n/g' | sed 's/ //g' | sed 's/^/nameserver: /g' > "$tmpdir/resolv.conf"
            
              ip link add wg0 type wireguard
              ip link set wg0 netns wg
              ip -n wg address add "${wgIpv4Address}" dev wg0
              ip netns exec wg wg setconf wg0 <(wg-quick strip "$tmpdir/wg.conf")
              ip -n wg link set wg0 up
              ip -n wg route add default dev wg0

              # Start the loopback interface
              ip -n wg link set dev lo up

              # Create a bridge
              ip link add v-net-0 type bridge
              ip addr add ${cfg.bridgeAddress}/24 dev v-net-0
              ip link set dev v-net-0 up

              # Set up veth pair to link namespace with host network
              ip link add veth-vpn-br type veth peer name veth-vpn netns wg
              ip link set veth-vpn-br master v-net-0

              ip -n wg addr add ${cfg.namespaceAddress}/24 dev veth-vpn
              ip -n wg link set dev veth-vpn up

              echo "setting dns"
              # DNS test, see:
              # https://www.man7.org/linux/man-pages/man8/wg-quick.8.html
              # Absolutely no luck...
              #echo "nameserver 1.1.1.1" | ip netns exec wg resolvconf -a wg0 -m 0 -x

              echo "Hello test"
            ''

            # Add routes to make the namespace accessible
            + strings.concatMapStrings (x: 
              "ip -n wg route add ${x} via ${cfg.bridgeAddress}" + "\n"
            ) cfg.accessibleFrom

            # Add prerouting rules
            + strings.concatMapStrings (x: 
              "iptables -t nat -A PREROUTING -p tcp --dport ${builtins.toString x.From} -j DNAT --to-destination ${cfg.namespaceAddress}:${builtins.toString x.To}" +
              "\n"
            ) cfg.portMappings

            # Allow VPN TCP ports
            + strings.concatMapStrings (x: 
              "ip netns exec wg iptables -I INPUT -p tcp --dport ${builtins.toString x} -j ACCEPT" +
              "\n"
            ) cfg.openTcpPorts

            # Allow VPN UDP ports
            + strings.concatMapStrings (x: 
              "ip netns exec wg iptables -I INPUT -p udp --dport ${builtins.toString x} -j ACCEPT" +
              "\n"
            ) cfg.openUdpPorts;
          };
        in assert ( wgIpv4Address != null ) || abort "No address found in config file."; {
          Type = "oneshot";
          RemainAfterExit = true;
          ExecStart = "${vpn-namespace}/bin/vpn-namespace";

          ExecStopPost = with pkgs; writers.writeBash "wg-down" (''
            ${iproute2}/bin/ip -n wg route del default dev wg0
            ${iproute2}/bin/ip -n wg link del wg0
            ${iproute2}/bin/ip -n wg link del veth-vpn
            ${iproute2}/bin/ip link del v-net-0

            # DNS test, see:
            # https://www.man7.org/linux/man-pages/man8/wg-quick.8.html
            #${iproute2}/bin/ip netns exec wg resolvconf -d wg0
          ''

          # Delete prerouting rules
          + strings.concatMapStrings (x: "${iptables}/bin/iptables -t nat -D PREROUTING -p tcp --dport ${builtins.toString x.From} -j DNAT --to-destination ${cfg.namespaceAddress}:${builtins.toString x.To}" + "\n") cfg.portMappings);
        };
      };

      vpn-test-service = {
        enable = cfg.vpnTestService.enable;

        script = let
          vpn-test = pkgs.writeShellApplication {
            name = "vpn-test";

            runtimeInputs = with pkgs; [ util-linux unixtools.ping coreutils curl bash libressl netcat-gnu openresolv dig ];

            text = ''
              cd "$(mktemp -d)"

              # Print resolv.conf
              echo "/etc/resolv.conf contains:"
              cat /etc/resolv.conf

              # Query resolvconf
              echo "resolvconf output:"
              resolvconf -l
              echo ""

              # Get ip
              echo "Getting IP:"
              curl -s ipinfo.io

              cat /etc/test.file

              echo -ne "DNS leak test:"
              curl -s https://raw.githubusercontent.com/macvk/dnsleaktest/b03ab54d574adbe322ca48cbcb0523be720ad38d/dnsleaktest.sh -o dnsleaktest.sh
              chmod +x dnsleaktest.sh
              ./dnsleaktest.sh

              echo "starting netcat on port ${builtins.toString cfg.vpnTestService.port}:"
              nc -vnlp ${builtins.toString cfg.vpnTestService.port}
            '';
          };
        in "${vpn-test}/bin/vpn-test";

        bindsTo = [ "netns@wg.service" ];
        requires = [ "network-online.target" ];
        after = [ "wg.service" ];
        serviceConfig = {
          User="prowlarr";
          NetworkNamespacePath = "/var/run/netns/wg";
          BindReadOnlyPaths=["/etc/netns/wg/resolv.conf:/etc/resolv.conf:norbind" "/data/test.file:/etc/test.file:norbind"];
        };
      };
    };
  };
}
