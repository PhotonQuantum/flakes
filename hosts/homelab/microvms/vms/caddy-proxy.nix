{ upstream }:
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
          reverse_proxy ${upstream}
        '';
      };
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
