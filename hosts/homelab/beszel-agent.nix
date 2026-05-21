{
  environmentFile,
  installKeysService ? null,
  extraFilesystems ? [ ],
  extraPath ? [ ],
  smartmon ? { },
  uid ? null,
  gid ? null,
}:
{ lib, pkgs, ... }:
{
  services.beszel.agent = {
    enable = true;
    openFirewall = false;
    package = pkgs.beszel-homelab;
    inherit environmentFile;
    inherit extraPath;
    smartmon = smartmon;
    environment = lib.optionalAttrs (extraFilesystems != [ ]) {
      EXTRA_FILESYSTEMS = lib.concatStringsSep "," extraFilesystems;
    };
  };

  users.users.beszel-agent = lib.optionalAttrs (uid != null) {
    uid = uid;
  };
  users.groups.beszel-agent = lib.optionalAttrs (gid != null) {
    gid = gid;
  };

  systemd.services.beszel-agent = {
    after = [
      "network-online.target"
      "tailscaled.service"
    ]
    ++ lib.optionals (installKeysService != null) [ installKeysService ];
    wants = [
      "network-online.target"
      "tailscaled.service"
    ];
    requires = lib.optionals (installKeysService != null) [ installKeysService ];
  };

  systemd.tmpfiles.rules = lib.optionals (smartmon.enable or false) (
    map (device: "z ${device} 0660 root disk - -") (smartmon.deviceAllow or [ ])
  );
}
