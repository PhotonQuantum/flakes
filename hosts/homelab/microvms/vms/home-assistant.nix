{
  lib,
  pkgs,
  config,
  vmCert,
  ...
}:
let
  homelabSecrets = import ../../../../secrets/homelab.nix;
  threadRadio = homelabSecrets.usbDevices.homeAssistantThreadRadio;
  dataDir = "/var/lib/home-assistant";
  configDir = "${dataDir}/config";
  matterDir = "${dataDir}/matter-server";
  matterUser = "1000";
  matterGroup = "1000";
  threadDir = "${dataDir}/thread";
  homeAssistantImage = pkgs.generated.home_assistant_image;
  matterServerImage = pkgs.generated.matter_server_image;
  mkBoolParam = name: enabled: lib.optionalString enabled "&${name}";
  threadRadioUrl =
    "spinel+hdlc+uart://${threadRadio.byId}?uart-baudrate=${toString threadRadio.baudRate}"
    + mkBoolParam "uart-flow-control" threadRadio.flowControl;
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
  matterHost = "matter.lqhome.me";
in
{
  imports = [
    (import ./caddy-proxy.nix { upstream = "http://127.0.0.1:8123"; })
  ];

  virtualisation.docker = {
    autoPrune = {
      enable = true;
      flags = [ "--all" ];
    };
    daemon.settings = {
      data-root = "${dataDir}/docker";
    };
  };

  virtualisation.oci-containers = {
    backend = "docker";
    containers = {
      matter-server = {
        image = "ghcr.io/matter-js/matterjs-server:${matterServerImage.version}";
        imageFile = matterServerImage.src;
        autoStart = true;
        volumes = [
          "${matterDir}:/data"
        ];
        environment = {
          STORAGE_PATH = "/data";
          OTA_PROVIDER_DIR = "/data/updates";
          PRIMARY_INTERFACE = "wpan0";
          LOG_LEVEL = "info";
          LISTEN_ADDRESS = "127.0.0.1";
          PRODUCTION_MODE = "true";
        };
        extraOptions = [
          "--network=host"
        ];
      };

      homeassistant = {
        image = "ghcr.io/home-assistant/home-assistant:${homeAssistantImage.version}";
        imageFile = homeAssistantImage.src;
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
  };

  services.openthread-border-router = {
    enable = true;
    backboneInterfaces = [ "enp0s6" ];
    logLevel = "notice";
    radio.url = threadRadioUrl;
    rest = {
      listenAddress = "127.0.0.1";
      listenPort = 8081;
    };
  };

  services.caddy.virtualHosts.${matterHost} = {
    hostName = "https://${matterHost}";
    extraConfig = ''
      tls ${vmCert.certPath} ${vmCert.keyPath}
      basic_auth {
        {$MATTER_WEBUI_USERNAME} {$MATTER_WEBUI_PASSWORD_HASH}
      }
      reverse_proxy http://127.0.0.1:5580
    '';
  };

  systemd.tmpfiles.rules = [
    "d ${dataDir} 0750 root root - -"
    "d ${configDir} 0750 root root - -"
    "d ${dataDir}/docker 0710 root root - -"
    "d ${matterDir} 0750 ${matterUser} ${matterGroup} - -"
    "d ${matterDir}/credentials 0750 ${matterUser} ${matterGroup} - -"
    "d ${matterDir}/updates 0750 ${matterUser} ${matterGroup} - -"
    "d ${threadDir} 0700 root root - -"
  ];

  systemd.services = {
    caddy.serviceConfig.EnvironmentFile = "/var/keys/matter-webui-auth.env";

    otbr-agent.serviceConfig.BindPaths = [ "${threadDir}:/var/lib/thread" ];

    otbr-backbone-onlink-routes = {
      description = "Install OTBR backbone on-link IPv6 routes";
      after = [
        "otbr-agent.service"
        "systemd-networkd.service"
      ];
      requires = [ "otbr-agent.service" ];
      wantedBy = [ "multi-user.target" ];
      path = [
        config.services.openthread-border-router.package
        pkgs.coreutils
        pkgs.gnused
        pkgs.iproute2
      ];
      serviceConfig = {
        Type = "oneshot";
        RemainAfterExit = true;
      };
      script = ''
        set -eu

        for _ in $(seq 1 30); do
          output="$(ot-ctl br onlinkprefix 2>/dev/null || true)"
          prefixes="$(
            printf '%s\n' "$output" \
              | sed -n 's/^\(Local\|Favored\): \([^ ]*\).*/\2/p' \
              | sort -u
          )"

          if [ -n "$prefixes" ]; then
            for prefix in $prefixes; do
              ip -6 route replace "$prefix" dev enp0s6 metric 100
            done
            exit 0
          fi

          sleep 1
        done

        echo "failed to discover OTBR backbone on-link prefixes" >&2
        exit 1
      '';
    };

    docker-homeassistant = {
      after = [
        "docker-matter-server.service"
        "otbr-backbone-onlink-routes.service"
        "otbr-agent.service"
      ];
      wants = [
        "docker-matter-server.service"
        "otbr-backbone-onlink-routes.service"
        "otbr-agent.service"
      ];
    };
  };

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
    trustedInterfaces = [ "wpan0" ];
    allowedTCPPorts = [ 8123 ];
    allowedTCPPortRanges = [
      {
        from = 21063;
        to = 21100;
      }
    ];
    allowedUDPPorts = [ 5353 ];
  };
}
