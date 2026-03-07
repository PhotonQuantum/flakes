_: 
{
  project.name = "ani-rss";
  services = {
    ani-rss.service = {
      container_name = "ani-rss";
      image = "wushuo894/ani-rss:latest";
      network_mode = "host";
      environment = {
        PUID = "955";
        PGID = "955";
        UMASK = "022";
        SERVER_PORT = "7789";
        CONFIG = "/config";
        TZ = "America/Toronto";
      };
      volumes = [
        "/srv/media/ani-rss:/config"
        "/srv/media/data:/Media"
      ];
      restart = "always";
    };
    qbittorrent.service = {
      container_name = "qBittorrent";
      image = "linuxserver/qbittorrent:latest";
      network_mode = "host";
      environment = {
        PUID = "955";
        PGID = "955";
        WEBUI_PORT = "8080";
        TZ = "America/Toronto";
      };
      volumes = [
        "/srv/media/qbittorrent:/config"
        "/srv/media/downloads:/downloads"
        "/srv/media/data:/Media"
      ];
      restart = "always";
    };
  };
}
