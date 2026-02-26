{ pkgs, lib, ... }:
let
  secrets = import ../../../../secrets/homelab.nix;
  runnerName = "forgejo-runner";
  runnerSecret = secrets.forgejo.runnerSecret;

  forgejoStateDir = "/mnt/forgejo";
in
{
  services.cloudflared = {
    enable = true;
    tunnels = {
      "578db42b-141f-463a-983c-8100761b2527" = {
        default = "http_status:404";
        credentialsFile = ../../../../secrets/cf/forgejo.json;
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

      ExecStart = ''
        ${pkgs.forgejo}/bin/forgejo forgejo-cli actions register --name ${runnerName} --secret ${runnerSecret} --keep-labels
      '';
    };
  };

  systemd.tmpfiles.rules = [
    "d /mnt/forgejo 0750 forgejo forgejo - -"
    "d /mnt/postgresql 0700 postgres postgres - -"
  ];
}
