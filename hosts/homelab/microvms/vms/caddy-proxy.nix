{
  upstream,
  accessLog ? false,
  rewriteToUpstream ? false,
}:
{
  lib,
  pkgs,
  config,
  vmSelf,
  vmCert,
  ...
}:
let
  httpsHost = "${vmSelf.name}.lqhome.me";
in
{
  assertions = [
    {
      assertion = vmCert.enabled;
      message = "Caddy proxy for ${vmSelf.name} requires cert.enable = true";
    }
  ];

  users.users.${config.services.caddy.user}.extraGroups = [ vmCert.group ];

  services.caddy = {
    enable = true;
    enableReload = true;
    openFirewall = true;
    virtualHosts = {
      "${httpsHost}" = {
        hostName = "https://${httpsHost}";
        extraConfig = ''
          tls ${vmCert.certPath} ${vmCert.keyPath}
          ${lib.optionalString accessLog ''
            log {
              output stdout
              format filter {
                wrap console
                fields {
                  request>headers>Authorization delete
                  request>headers>Cookie delete
                  request>headers>Set-Cookie delete
                }
              }
            }
          ''}
          ${
            if rewriteToUpstream then
              ''
                reverse_proxy ${upstream} {
                  header_up Host {upstream_hostport}
                  header_up Origin ${upstream}
                }
              ''
            else
              "reverse_proxy ${upstream}"
          }
        '';
      };
    };
  };

  systemd.services.caddy = {
    after = [ "run-homelab\\x2dcerts.mount" ];
    requires = [ "run-homelab\\x2dcerts.mount" ];
  };

  systemd.services.caddy-cert-ready = {
    description = "Start Caddy after the host-provisioned certificate is ready";
    after = [ "run-homelab\\x2dcerts.mount" ];
    serviceConfig.Type = "oneshot";
    script = ''
      if [[ -r ${vmCert.certPath} && -r ${vmCert.keyPath} ]]; then
        ${pkgs.systemd}/bin/systemctl stop caddy-cert-ready.timer
        ${pkgs.systemd}/bin/systemctl reset-failed caddy.service
        ${pkgs.systemd}/bin/systemctl start caddy.service
      fi
    '';
  };

  systemd.timers.caddy-cert-ready = {
    description = "Poll for the host-provisioned Caddy certificate";
    wantedBy = [ "timers.target" ];
    timerConfig = {
      OnBootSec = "5s";
      OnUnitActiveSec = "5s";
      AccuracySec = "1s";
    };
  };

  systemd.services.caddy-daily-reload = {
    description = "Daily forced Caddy reload";
    after = [ "caddy.service" ];
    serviceConfig = {
      Type = "oneshot";
      ExecStart = "${pkgs.systemd}/bin/systemctl reload caddy.service";
    };
  };

  systemd.timers.caddy-daily-reload = {
    description = "Reload Caddy daily";
    wantedBy = [ "timers.target" ];
    timerConfig = {
      OnCalendar = "daily";
      Persistent = true;
      Unit = "caddy-daily-reload.service";
    };
  };
}
