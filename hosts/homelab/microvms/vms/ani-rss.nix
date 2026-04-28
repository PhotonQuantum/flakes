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
    "d /Media 0750 media media - -"
  ];

  services.ani-rss = {
    enable = true;
    user = "media";
    group = "media";
    createUser = false;
    createGroup = false;
    configDir = "/config";
    port = 7789;
    openFirewall = true;
    extraEnvironment = {
      JAVA_TOOL_OPTIONS = "-Djava.net.preferIPv4Stack=true";
      TZ = "America/Toronto";
    };
    settings = {
      downloadToolHost = "http://qbittorrent.local:8080";
    };
  };
}
