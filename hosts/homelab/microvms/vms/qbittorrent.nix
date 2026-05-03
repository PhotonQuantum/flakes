{ lib, pkgs, ... }:
let
  passwordPlaceholder = "__QBITTORRENT_PASSWORD_PBKDF2__";
  passwordFile = "/var/keys/qbittorrent-password-pbkdf2";
  configFile = "/config/qBittorrent/config/qBittorrent.conf";
  serverConfig = {
    AutoRun = {
      enabled = false;
      program = "";
    };

    BitTorrent.Session.QueueingSystemEnabled = false;

    LegalNotice.Accepted = true;

    Network.PortForwardingEnabled = true;

    Preferences = {
      Connection = {
        PortRangeMin = 6881;
      };
      Downloads = {
        SavePath = "/downloads/";
        TempPath = "/downloads/incomplete/";
      };
      General.Locale = "en";
      WebUI = {
        Address = "*";
        Password_PBKDF2 = "@ByteArray(${passwordPlaceholder})";
        ServerDomains = "*";
      };
    };
  };
  patchPassword = pkgs.writeShellScript "qbittorrent-patch-password" ''
    ${pkgs.replace-secret}/bin/replace-secret ${lib.escapeShellArg passwordPlaceholder} ${lib.escapeShellArg passwordFile} ${lib.escapeShellArg configFile}
  '';
in
{
  imports = [
    (import ./caddy-proxy.nix { upstream = "http://127.0.0.1:8080"; })
  ];

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
    inherit serverConfig;
  };

  systemd.services.qbittorrent.serviceConfig.ExecStartPre = lib.mkAfter [ "${patchPassword}" ];

  networking.firewall.allowedUDPPorts = [ 6881 ];
}
