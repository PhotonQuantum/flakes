_:
{
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
    "d /srv/media 0750 media media - -"
    "d /srv/media/emby 0750 media media - -"
  ];

  services.emby = {
    enable = true;
    user = "media";
    group = "media";
    createUser = false;
    createGroup = false;
    dataDir = "/srv/media/emby";
    mediaDirs = [ "/srv/media/data" ];
    port = 80;
    openFirewall = true;
  };
}
