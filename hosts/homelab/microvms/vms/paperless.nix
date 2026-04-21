
{ ... }: {
  services.paperless = {
    enable = true;
    dataDir = "/mnt/paperless";
    database.createLocally = true;
    address = "127.0.0.1";
    port = 28981;
    settings = {
      PAPERLESS_ADMIN_USER = "lightquantum";
      PAPERLESS_URL = "http://paperless.home.arpa";
    };
  };

  services.nginx = {
    enable = true;
    virtualHosts."paperless.home.arpa" = {
      locations."/" = {
        proxyPass = "http://127.0.0.1:28981";
        proxyWebsockets = true;
      };
    };
  };

  services.postgresql = {
    enable = true;
    dataDir = "/mnt/postgresql";
    enableTCPIP = false;
  };

  networking.firewall = {
    allowedTCPPorts = [ 80 ];
  };

  systemd.tmpfiles.rules = [
    "d /mnt/paperless 0750 paperless paperless - -"
    "d /mnt/postgresql 0700 postgres postgres - -"
  ];
}
