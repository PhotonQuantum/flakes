{ lib, pkgs, ... }:
let
  qbittorrentPasswordFile = "/var/keys/qbittorrent-password";
  configFile = "/config/config.v2.json";
  patchQbittorrentPassword = pkgs.writeShellScript "ani-rss-patch-qbittorrent-password" ''
    set -euo pipefail

    ${pkgs.jq}/bin/jq --arg password "$(${pkgs.coreutils}/bin/cat ${lib.escapeShellArg qbittorrentPasswordFile})" \
      '.downloadToolPassword = $password' \
      ${lib.escapeShellArg configFile} | ${pkgs.moreutils}/bin/sponge ${lib.escapeShellArg configFile}
  '';
in
{
  imports = [
    (import ./caddy-proxy.nix { upstream = "http://127.0.0.1:7789"; })
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
    "d /Media 0750 media media - -"
  ];

  services.ani-rss = {
    enable = true;
    user = "media";
    group = "media";
    createUser = false;
    createGroup = false;
    configDir = "/config";
    serverAddress = "127.0.0.1";
    port = 7789;
    openFirewall = false;
    extraEnvironment = {
      JAVA_TOOL_OPTIONS = "-Djava.net.preferIPv4Stack=true";
      TZ = "America/Toronto";
    };
    settings = {
      delete = true;
      downloadToolHost = "http://qbittorrent.local:8080";
      downloadToolType = "qBittorrent";
      downloadToolUsername = "admin";
      tmdbId = true;
    };
  };

  systemd.services.ani-rss.serviceConfig.ExecStartPre = lib.mkAfter [ "${patchQbittorrentPassword}" ];
}
