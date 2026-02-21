{ pkgs, lib, ... }:
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
    stateDir = "/mnt/forgejo";

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

  systemd.tmpfiles.rules = [
    "d /mnt/forgejo 0750 forgejo forgejo - -"
    "d /mnt/postgresql 0700 postgres postgres - -"
  ];
}
