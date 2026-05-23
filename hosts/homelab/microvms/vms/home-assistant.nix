{ pkgs, ... }:
let
  dataDir = "/var/lib/home-assistant";
  configDir = "${dataDir}/config";
  initialConfig = pkgs.writeText "home-assistant-configuration.yaml" ''
    default_config:

    http:
      use_x_forwarded_for: true
      trusted_proxies:
        - 127.0.0.1
        - ::1

    automation: !include automations.yml
    script: !include scripts.yml
    scene: !include scenes.yml
  '';
in
{
  imports = [
    (import ./caddy-proxy.nix { upstream = "http://127.0.0.1:8123"; })
  ];

  virtualisation.docker.daemon.settings = {
    data-root = "${dataDir}/docker";
  };

  virtualisation.oci-containers = {
    backend = "docker";
    containers.homeassistant = {
      image = "ghcr.io/home-assistant/home-assistant:stable";
      autoStart = true;
      privileged = true;
      volumes = [
        "${configDir}:/config"
        "/etc/localtime:/etc/localtime:ro"
      ];
      extraOptions = [
        "--network=host"
      ];
    };
  };

  systemd.tmpfiles.rules = [
    "d ${dataDir} 0750 root root - -"
    "d ${configDir} 0750 root root - -"
    "d ${dataDir}/docker 0710 root root - -"
  ];

  systemd.services.home-assistant-config = {
    description = "Install initial Home Assistant configuration";
    before = [ "docker-homeassistant.service" ];
    wantedBy = [ "docker-homeassistant.service" ];
    serviceConfig = {
      Type = "oneshot";
      RemainAfterExit = true;
    };
    script = ''
      set -eu
      install -d -m 0750 ${configDir}
      if [ ! -e ${configDir}/configuration.yaml ]; then
        install -m 0640 ${initialConfig} ${configDir}/configuration.yaml
      fi
      for file in automations.yml scripts.yml scenes.yml; do
        if [ ! -e ${configDir}/$file ]; then
          install -m 0640 /dev/null ${configDir}/$file
        fi
      done
    '';
  };

  networking.firewall = {
    allowedTCPPortRanges = [
      {
        from = 21063;
        to = 21100;
      }
    ];
    allowedUDPPorts = [ 5353 ];
  };
}
