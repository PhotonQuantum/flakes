_:
{
  imports = [
    (import ./caddy-proxy.nix { upstream = "http://127.0.0.1:28981"; })
  ];

  services.paperless = {
    enable = true;
    dataDir = "/mnt/paperless";
    database.createLocally = true;
    address = "127.0.0.1";
    port = 28981;
    settings = {
      PAPERLESS_ADMIN_USER = "lightquantum";
      PAPERLESS_URL = "https://paperless.lqhome.me";
    };
  };

  services.postgresql = {
    enable = true;
    dataDir = "/mnt/postgresql";
    enableTCPIP = false;
  };

  systemd.tmpfiles.rules = [
    "d /mnt/paperless 0750 paperless paperless - -"
    "d /mnt/postgresql 0700 postgres postgres - -"
  ];
}
