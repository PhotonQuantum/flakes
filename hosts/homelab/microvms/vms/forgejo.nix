{ pkgs, lib, ... }:
let
  runnerName = "forgejo-runner";
  forgejoStateDir = "/mnt/forgejo";
  runnerSecretFile = "/var/keys/forgejo-runner-secret";
  cloudflaredCredentialsFile = "/var/keys/forgejo-cloudflared-credentials.json";
  tunnelId = "578db42b-141f-463a-983c-8100761b2527";
in
{
  services.cloudflared = {
    enable = true;
    tunnels = {
      "${tunnelId}" = {
        default = "http_status:404";
        credentialsFile = cloudflaredCredentialsFile;
      };
    };
  };

  services.forgejo = {
    enable = true;
    package = pkgs.forgejo;
    stateDir = forgejoStateDir;

    database = {
      type = "postgres";
      name = "forgejo";
      user = "forgejo";
      createDatabase = true;
      socket = "/run/postgresql";
    };

    settings.server = {
      DOMAIN = "git.lightquantum.me";
      ROOT_URL = "https://git.lightquantum.me/";
      HTTP_ADDR = "127.0.0.1";
      HTTP_PORT = 3000;
      DISABLE_SSH = true;
      LANDING_PAGE = "explore";
    };
    settings = {
      service.DISABLE_REGISTRATION = true;
      actions.DEFAULT_ACTIONS_URL = "https://github.com";
      cache = {
        ADAPTER = "twoqueue";
        HOST = ''{"size":100, "recent_ratio":0.25, "ghost_ratio":0.5}'';
      };
      security.LOGIN_REMEMBER_DAYS = 365;
      DEFAULT.APP_NAME = "git.lightquantum.me";
    };
  };

  services.postgresql = {
    enable = true;
    dataDir = "/mnt/postgresql";
    enableTCPIP = false;
    authentication = lib.mkBefore ''
      local forgejo forgejo peer
    '';
  };

  systemd.services.forgejo-register-runner = {
    enable = true;

    wantedBy = [ "multi-user.target" ];
    wants = [ "forgejo.service" ];
    after = [ "forgejo.service" ];

    environment = {
      USER = "forgejo";
      HOME = forgejoStateDir;
      FORGEJO_WORK_DIR = forgejoStateDir;
      FORGEJO_CUSTOM = "${forgejoStateDir}/custom";
    };

    serviceConfig = {
      Type = "oneshot";
      User = "forgejo";
      Group = "forgejo";
      ExecStart = [
        ""
        "${pkgs.bash}/bin/bash"
        "-euc"
        ''
          runner_secret="$(< ${lib.escapeShellArg runnerSecretFile})"
          exec ${pkgs.forgejo}/bin/forgejo forgejo-cli actions register --name ${lib.escapeShellArg runnerName} --secret "$runner_secret" --keep-labels
        ''
      ];
    };
  };

  systemd.tmpfiles.rules = [
    "d /mnt/forgejo 0750 forgejo forgejo - -"
    "d /mnt/postgresql 0700 postgres postgres - -"
  ];
}
