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
    "d /srv/media 0750 media media - -"
    "d /srv/media/ani-rss 0750 media media - -"
    "d /srv/media/data 0750 media media - -"
    "d /srv/media/downloads 0750 media media - -"
    "d /srv/media/qbittorrent 0750 media media - -"
  ];

  virtualisation.arion = {
    backend = "docker";
    projects.ani-rss = {
      serviceName = "ani-rss";
      settings = {
        # Specify you project here, or import it from a file.
        imports = [ ./ani-rss.nix ];
      };
    };
  };

  networking.firewall.allowedTCPPorts = [ 7789 8080 ];
}
