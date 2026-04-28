_: {
  users = {
    users.media = {
      description = "media user";
      uid = 955;
      isSystemUser = true;
      group = "media";
      useDefaultShell = true;
    };
    groups.media = {
      name = "media";
      gid = 955;
      members = [ "media" ];
    };
  };

  systemd.tmpfiles.rules = [
    "d /config 0750 media media - -"
    "d /downloads 0750 media media - -"
    "d /downloads/incomplete 0750 media media - -"
    "d /Media 0750 media media - -"
  ];

  services.qbittorrent = {
    enable = true;
    user = "media";
    group = "media";
    profileDir = "/config";
    webuiPort = 8080;
    torrentingPort = 6881;
    openFirewall = true;
    extraArgs = [ "--confirm-legal-notice" ];
  };

  networking.firewall.allowedUDPPorts = [ 6881 ];
}
