{
  lib,
  pkgs,
  ...
}:
let
  homelabSecrets = import ../../../../secrets/homelab.nix;
  dataDir = "/var/lib/beszel-hub";
  pocketbaseDataDir = "${dataDir}/beszel_data";
  installHubSecrets = pkgs.writeShellScript "beszel-hub-install-secrets" ''
    set -eu
    install -d -m 0750 -o beszel-hub -g beszel-hub ${dataDir}
    install -d -m 0750 -o beszel-hub -g beszel-hub ${pocketbaseDataDir}
    install -D -m 0600 -o beszel-hub -g beszel-hub /var/keys/beszel-hub-id-ed25519 ${pocketbaseDataDir}/id_ed25519
    install -D -m 0640 -o beszel-hub -g beszel-hub /var/keys/beszel-hub-config.yml ${pocketbaseDataDir}/config.yml
  '';
in
{
  imports = [
    (import ./caddy-proxy.nix {
      upstream = "http://127.0.0.1:8090";
    })
  ];

  users.users.beszel-hub = {
    isSystemUser = true;
    group = "beszel-hub";
    uid = 998;
  };
  users.groups.beszel-hub.gid = 998;

  services.beszel.hub = {
    enable = true;
    package = pkgs.beszel-homelab;
    host = "127.0.0.1";
    port = 8090;
    inherit dataDir;
    environment.APP_URL = homelabSecrets.beszel.hubUrl;
    environmentFile = "/var/keys/beszel-hub.env";
  };

  systemd.services.beszel-hub = {
    after = [
      "microvm-install-keys.service"
    ];
    requires = [
      "microvm-install-keys.service"
    ];
    serviceConfig = {
      DynamicUser = lib.mkForce false;
      StateDirectory = lib.mkForce "";
      ExecStartPre = lib.mkBefore [
        "+${installHubSecrets}"
      ];
    };
  };
}
