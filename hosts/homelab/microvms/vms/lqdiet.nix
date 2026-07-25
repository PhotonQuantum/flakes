{
  config,
  lib,
  pkgs,
  ...
}:
let
  hostName = "diet.lqhome.me";
  stateRoot = "/mnt/lqdiet";
  dataDir = "${stateRoot}/data";
  environmentFile = "${stateRoot}/runtime.env";
  package = config.services.lqdiet.package;
  migrationsDir = "${package}/share/lqdiet/pb_migrations";
  hooksDir = "${package}/share/lqdiet/pb_hooks";
  pocketbase = "${package}/bin/lqdiet-pocketbase";
in
{
  networking.hostName = lib.mkForce "diet";

  imports = [
    (import ./caddy-proxy.nix { upstream = "http://127.0.0.1:8080"; })
  ];

  services.lqdiet = {
    enable = true;
    inherit dataDir environmentFile hostName;
    baseUrl = "https://${hostName}";
    nginx = {
      enable = true;
      hostName = hostName;
      forceSSL = false;
      enableACME = false;
    };
  };

  services.nginx.virtualHosts.${hostName}.listen = [
    {
      addr = "127.0.0.1";
      port = 8080;
    }
  ];

  systemd.services.lqdiet-secrets = {
    description = "Create persistent lqdiet runtime credentials";
    before = [
      "lqdiet.service"
      "lqdiet-api.service"
    ];
    requiredBy = [
      "lqdiet.service"
      "lqdiet-api.service"
    ];
    after = [ "mnt.mount" ];
    requires = [ "mnt.mount" ];
    serviceConfig = {
      Type = "oneshot";
      RemainAfterExit = true;
    };
    script = ''
      install -d -m 0750 -o lqdiet -g lqdiet ${lib.escapeShellArg stateRoot}
      if [[ ! -s ${lib.escapeShellArg environmentFile} ]]; then
        temporary="$(${pkgs.coreutils}/bin/mktemp ${lib.escapeShellArg "${stateRoot}/.runtime.env.XXXXXX"})"
        trap '${pkgs.coreutils}/bin/rm -f "$temporary"' EXIT
        {
          echo 'LQDIET_SUPERUSER_EMAIL=admin@lqdiet.invalid'
          echo "LQDIET_SUPERUSER_PASSWORD=$(${pkgs.openssl}/bin/openssl rand -hex 32)"
          echo "LQDIET_PAT_PEPPER=$(${pkgs.openssl}/bin/openssl rand -hex 32)"
        } >"$temporary"
        ${pkgs.coreutils}/bin/chown lqdiet:lqdiet "$temporary"
        ${pkgs.coreutils}/bin/chmod 0400 "$temporary"
        ${pkgs.coreutils}/bin/mv "$temporary" ${lib.escapeShellArg environmentFile}
        trap - EXIT
      fi
    '';
  };

  systemd.services.lqdiet = {
    after = [ "lqdiet-secrets.service" ];
    requires = [ "lqdiet-secrets.service" ];

    # The upstream module consumes superuser credentials but does not create
    # the initial PocketBase superuser on an empty data directory.
    preStart = lib.mkAfter ''
      ${pocketbase} superuser upsert \
        "$LQDIET_SUPERUSER_EMAIL" \
        "$LQDIET_SUPERUSER_PASSWORD" \
        --dir=${lib.escapeShellArg dataDir} \
        --migrationsDir=${lib.escapeShellArg migrationsDir} \
        --hooksDir=${lib.escapeShellArg hooksDir} \
        --automigrate=0
    '';
  };

  systemd.services.lqdiet-api = {
    after = [ "lqdiet-secrets.service" ];
    requires = [ "lqdiet-secrets.service" ];
  };
}
