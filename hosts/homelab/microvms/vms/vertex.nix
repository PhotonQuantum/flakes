{
  lib,
  pkgs,
  ...
}:
let
  stateRoot = "/mnt/vertex";
  dataDir = "${stateRoot}/data";
  dockerDir = "${stateRoot}/docker";
  image = pkgs.generated.vertex_image;
in
{
  imports = [
    (import ./caddy-proxy.nix { upstream = "http://127.0.0.1:3000"; })
  ];

  virtualisation.docker = {
    autoPrune = {
      enable = true;
      flags = [ "--all" ];
    };
    daemon.settings.data-root = dockerDir;
  };

  virtualisation.oci-containers = {
    backend = "docker";
    containers.vertex = {
      image = "lswl/vertex:${image.version}";
      imageFile = image.src;
      pull = "never";
      autoStart = true;
      environment = {
        TZ = "America/Toronto";
        PORT = "3000";
        PUID = "1000";
        PGID = "1000";
      };
      volumes = [ "${dataDir}:/vertex" ];
      ports = [ "127.0.0.1:3000:3000" ];
      extraOptions = [ "--stop-timeout=30" ];
    };
  };

  systemd.services.vertex-bootstrap = {
    description = "Create persistent Vertex runtime state";
    before = [ "docker-vertex.service" ];
    requiredBy = [ "docker-vertex.service" ];
    after = [ "mnt.mount" ];
    requires = [ "mnt.mount" ];
    unitConfig.RequiresMountsFor = stateRoot;
    serviceConfig = {
      Type = "oneshot";
      RemainAfterExit = true;
    };
    script = ''
      set -eu

      install -d -m 0755 -o root -g root ${lib.escapeShellArg stateRoot}
      install -d -m 0750 -o 1000 -g 1000 ${lib.escapeShellArg dataDir}
      install -d -m 0710 -o root -g root ${lib.escapeShellArg dockerDir}
    '';
  };

  systemd.services.docker-vertex = {
    after = [ "vertex-bootstrap.service" ];
    requires = [ "vertex-bootstrap.service" ];
    unitConfig.RequiresMountsFor = stateRoot;
  };
}
