{ ... }:
let
  bridgeName = "microvm";
  bridgeAddress = "10.200.0.1/24";
  vmName = "static-http";
  vmTapName = "vm-${vmName}";
  vmMac = "02:00:00:00:20:02";
  vmAddress = "10.200.0.2/24";
  vmGateway = "10.200.0.1";
in
{
  networking.nat = {
    enable = true;
    externalInterface = "enp3s0";
    internalInterfaces = [ bridgeName ];
  };

  systemd.network = {
    netdevs."10-${bridgeName}" = {
      netdevConfig = {
        Name = bridgeName;
        Kind = "bridge";
      };
    };

    networks."10-${bridgeName}" = {
      matchConfig.Name = bridgeName;
      address = [ bridgeAddress ];
      networkConfig = {
        ConfigureWithoutCarrier = true;
      };
    };

    # This must match before the generic host ethernet rule in system.nix.
    networks."09-microvm-taps" = {
      matchConfig.Name = "vm-*";
      networkConfig = {
        Bridge = bridgeName;
      };
    };
  };

  microvm = {
    autostart = [ vmName ];
    vms.${vmName} = {
      config =
        { ... }:
        {
          networking.hostName = vmName;
          networking.useDHCP = false;
          networking.useNetworkd = true;
          networking.nameservers = [
            "1.1.1.1"
            "8.8.8.8"
          ];

          systemd.network.enable = true;
          systemd.network.networks."10-uplink" = {
            matchConfig.MACAddress = vmMac;
            address = [ vmAddress ];
            routes = [
              {
                Gateway = vmGateway;
              }
            ];
            networkConfig = {
              DNS = [
                "1.1.1.1"
                "8.8.8.8"
              ];
            };
          };

          services.nginx = {
            enable = true;
            recommendedProxySettings = true;
            virtualHosts."static-http.local" = {
              default = true;
              locations."/" = {
                root = "/etc/nginx/static";
                index = "index.html";
              };
              locations."/internet/" = {
                proxyPass = "http://example.com/";
              };
            };
          };

          environment.etc."nginx/static/index.html".text = ''
            <!doctype html>
            <html>
              <head><title>homelab microvm</title></head>
              <body>hello from homelab microvm</body>
            </html>
          '';

          networking.firewall.allowedTCPPorts = [ 80 ];
          system.stateVersion = "25.11";

          microvm = {
            hypervisor = "cloud-hypervisor";
            interfaces = [
              {
                type = "tap";
                id = vmTapName;
                mac = vmMac;
              }
            ];
            vsock.cid = 21002;
            vcpu = 1;
            mem = 256;
          };
        };
    };
  };
}
