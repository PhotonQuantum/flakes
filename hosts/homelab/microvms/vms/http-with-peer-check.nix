{
  title,
  body,
  serverName,
  peerIp,
  peerName,
}:
{
  pkgs,
  ...
}:
{
  services.nginx = {
    enable = true;
    recommendedProxySettings = true;
    virtualHosts.${serverName} = {
      default = true;
      locations."/" = {
        root = "/etc/nginx/static";
        index = "index.html";
      };
      locations."/status/" = {
        alias = "/var/lib/microvm-status/";
      };
      locations."/internet/" = {
        extraConfig = ''
          resolver 1.1.1.1 8.8.8.8 ipv6=off;
          set $internet_upstream "http://example.com";
          proxy_set_header Host example.com;
          proxy_pass $internet_upstream;
        '';
      };
    };
  };

  environment.etc."nginx/static/index.html".text = ''
    <!doctype html>
    <html>
      <head><title>${title}</title></head>
      <body>${body}</body>
    </html>
  '';

  systemd.tmpfiles.rules = [
    "d /var/lib/microvm-status 0755 root root - -"
  ];

  systemd.services.microvm-peer-check = {
    description = "MicroVM peer connectivity self-check";
    wantedBy = [ "multi-user.target" ];
    after = [ "network-online.target" ];
    wants = [ "network-online.target" ];
    serviceConfig = {
      Type = "oneshot";
    };
    script = ''
      set -eu

      status_file="/var/lib/microvm-status/peer-check.txt"
      if ${pkgs.curl}/bin/curl -fsS --max-time 3 "http://${peerIp}/" >/dev/null; then
        printf 'ok: reached %s (%s)\n' '${peerName}' '${peerIp}' > "$status_file"
      else
        printf 'fail: could not reach %s (%s)\n' '${peerName}' '${peerIp}' > "$status_file"
      fi
    '';
  };

  systemd.timers.microvm-peer-check = {
    description = "Periodically refresh MicroVM peer connectivity self-check";
    wantedBy = [ "timers.target" ];
    partOf = [ "microvm-peer-check.service" ];
    timerConfig = {
      OnBootSec = "20s";
      OnUnitActiveSec = "30s";
      Unit = "microvm-peer-check.service";
    };
  };
}
