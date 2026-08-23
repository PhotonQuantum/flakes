{
  lib,
  pkgs,
  ...
}:
let
  hostName = "trek.lqhome.me";
  stateRoot = "/mnt/trek";
  dataDir = "${stateRoot}/data";
  uploadsDir = "${stateRoot}/uploads";
  dockerDir = "${stateRoot}/docker";
  environmentFile = "${stateRoot}/runtime.env";
  image = pkgs.generated.trek_image;
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
    containers.trek = {
      image = "mauriceboe/trek:${image.version}";
      imageFile = image.src;
      pull = "never";
      autoStart = true;
      environment = {
        NODE_ENV = "production";
        PORT = "3000";
        TZ = "America/Toronto";
        LOG_LEVEL = "info";
        APP_URL = "https://${hostName}";
        ALLOWED_ORIGINS = "https://${hostName}";
        FORCE_HTTPS = "true";
        TRUST_PROXY = "1";
        HSTS_INCLUDE_SUBDOMAINS = "false";
      };
      environmentFiles = [ environmentFile ];
      volumes = [
        "${dataDir}:/app/data"
        "${uploadsDir}:/app/uploads"
      ];
      ports = [ "127.0.0.1:3000:3000" ];
      extraOptions = [
        "--read-only"
        "--security-opt=no-new-privileges:true"
        "--cap-drop=ALL"
        "--cap-add=CHOWN"
        "--cap-add=SETUID"
        "--cap-add=SETGID"
        "--tmpfs=/tmp:rw,noexec,nosuid,size=128m"
      ];
    };
  };

  systemd.services.trek-bootstrap = {
    description = "Create persistent TREK runtime state";
    before = [ "docker-trek.service" ];
    requiredBy = [ "docker-trek.service" ];
    after = [ "mnt.mount" ];
    requires = [ "mnt.mount" ];
    unitConfig.RequiresMountsFor = stateRoot;
    serviceConfig = {
      Type = "oneshot";
      RemainAfterExit = true;
      UMask = "0077";
    };
    script = ''
      set -eu

      install -d -m 0750 -o 1000 -g 1000 \
        ${lib.escapeShellArgs [
          stateRoot
          dataDir
          uploadsDir
        ]}
      install -d -m 0710 -o root -g root ${lib.escapeShellArg dockerDir}

      if [[ ! -s ${lib.escapeShellArg environmentFile} ]]; then
        temporary="$(${pkgs.coreutils}/bin/mktemp ${lib.escapeShellArg "${stateRoot}/.runtime.env.XXXXXX"})"
        trap '${pkgs.coreutils}/bin/rm -f "$temporary"' EXIT
        printf 'ENCRYPTION_KEY=%s\n' "$(${pkgs.openssl}/bin/openssl rand -hex 32)" >"$temporary"
        ${pkgs.coreutils}/bin/chown root:root "$temporary"
        ${pkgs.coreutils}/bin/chmod 0400 "$temporary"
        ${pkgs.coreutils}/bin/mv "$temporary" ${lib.escapeShellArg environmentFile}
        trap - EXIT
      fi
    '';
  };

  systemd.services.docker-trek = {
    after = [ "trek-bootstrap.service" ];
    requires = [ "trek-bootstrap.service" ];
    unitConfig.RequiresMountsFor = stateRoot;
  };
}
