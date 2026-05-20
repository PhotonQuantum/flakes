{
  environmentFile,
  installKeysService ? null,
  extraFilesystems ? [ ],
  extraPath ? [ ],
  smartmon ? { },
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
