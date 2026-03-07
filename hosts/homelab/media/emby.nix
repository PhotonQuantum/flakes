
_: 
{
  project.name = "emby";
  services = {
    emby.service = {
      container_name = "emby";
      image = "emby/embyserver:latest";
      network_mode = "host";
      environment = {
        UID = "955";
        GID = "955";
      };
      volumes = [
        "/srv/media/emby:/config"
        "/srv/media/data:/mnt/share"
      ];
      ports = [ "8096:8096" ];
      restart = "on-failure";
    };
  };
}
