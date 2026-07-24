_: {
  imports = [
    (import ./caddy-proxy.nix { upstream = "http://127.0.0.1:8080"; })
  ];

  services.sparkyfitness = {
    enable = true;
    stateDir = "/mnt/sparkyfitness";
    frontendUrl = "https://sparkyfitness.lqhome.me";
    environmentFile = "/var/keys/sparkyfitness.env";
    nginx.virtualHost = "sparkyfitness-internal";
  };

  services.nginx.virtualHosts."sparkyfitness-internal".listen = [
    {
      addr = "127.0.0.1";
      port = 8080;
    }
  ];

  services.postgresql.dataDir = "/mnt/postgresql";

  systemd.tmpfiles.rules = [
    "d /mnt/sparkyfitness 0750 sparkyfitness sparkyfitness - -"
    "d /mnt/postgresql 0700 postgres postgres - -"
  ];
}
