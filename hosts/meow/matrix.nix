{ pkgs, ... }:
{
  deployment.keys = {
    "homeserver.yaml" = {
      keyFile = ../../secrets/homeserver.yaml;
      destDir = "/var/keys";
      user = "matrix-synapse";
      group = "matrix-synapse";
    };
    "homeserver.signing.key" = {
      keyFile = ../../secrets/lightquantum.me.signing.key;
      destDir = "/var/lib/matrix-synapse";
      user = "matrix-synapse";
      group = "matrix-synapse";
    };
  };

  services.postgresql = {
    enable = true;
    package = pkgs.postgresql_14;
    initialScript = pkgs.writeText "synapse-init.sql" ''
      CREATE USER "matrix-synapse";
      CREATE DATABASE "synapse" WITH OWNER "matrix-synapse"
        TEMPLATE template0
        LC_COLLATE = "C"
        LC_CTYPE = "C";
    '';
    ensureUsers = [
      {
        name = "root";
        ensurePermissions = {
          "ALL TABLES IN SCHEMA public" = "ALL PRIVILEGES";
        };
      }
    ];
  };

  services.postgresqlBackup = {
    enable = true;
    startAt = "*-*-* 00:15:00";
    databases = [ "synapse" ];
  };

  services.matrix-synapse = {
    enable = true;
    withJemalloc = true;
    settings = {
      server_name = "lightquantum.me";
      public_baseurl = "https://chat.lightquantum.me";
      listeners = [
        {
          port = 8080;
          bind_addresses = [ "0.0.0.0" ];
          type = "http";
          tls = false;
          x_forwarded = true;
          resources = [
            {
              names = [
                "client"
                "federation"
              ];
              compress = false;
            }
          ];
        }
      ];
      database = {
        name = "psycopg2";
        txn_limit = 10000;
        args = {
          user = "matrix-synapse";
          database = "synapse";
          host = "/var/run/postgresql/";
          port = 5432;
          cp_min = 5;
          cp_max = 10;
        };
      };
      url_preview_enabled = true;
      url_preview_ip_range_blacklist = [
        "127.0.0.0/8"
        "10.0.0.0/8"
        "172.16.0.0/12"
        "192.168.0.0/16"
        "100.64.0.0/10"
        "192.0.0.0/24"
        "169.254.0.0/16"
        "192.88.99.0/24"
        "198.18.0.0/15"
        "192.0.2.0/24"
        "198.51.100.0/24"
        "203.0.113.0/24"
        "224.0.0.0/4"
        "::1/128"
        "fe80::/10"
        "fc00::/7"
        "2001:db8::/32"
        "ff00::/8"
        "fec0::/10"
      ];
      max_spider_size = "10M";
      enable_registration = true;
      registrations_require_3pid = [ "email" ];
      registration_requires_token = true;
    };
    extraConfigFiles = [ "/var/keys/homeserver.yaml" ];
  };

  # Open ports in the firewall.
  networking.firewall.allowedTCPPorts = [ 8080 ];
  networking.firewall.allowedUDPPorts = [ 20423 ];
}
