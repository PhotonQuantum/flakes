{ vmSelf, ...}: {
  services.syncthing = {
    enable = true;
    openDefaultPorts = true;
    dataDir = "/mnt/syncthing";
    overrideFolders = false;
    guiAddress = "${vmSelf.ip}:8384";
  };

  networking.firewall = {
    allowedTCPPorts = [ 8384 ];
  };

  systemd.tmpfiles.rules = [
    "d /mnt/syncthing 0750 syncthing syncthing - -"
  ];
}