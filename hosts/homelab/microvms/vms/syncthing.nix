_:
{
  imports = [
    (import ./caddy-proxy.nix { upstream = "http://127.0.0.1:8384"; })
  ];

  services.syncthing = {
    enable = true;
    openDefaultPorts = true;
    dataDir = "/mnt/syncthing";
    overrideFolders = false;
    guiAddress = "127.0.0.1:8384";
    settings.gui.insecureSkipHostcheck = true;
  };

  systemd.tmpfiles.rules = [
    "d /mnt/syncthing 0750 syncthing syncthing - -"
  ];
}