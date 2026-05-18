{
  config,
  lib,
  vmTailscale,
  ...
}:
let
  tailscale = lib.getExe config.services.tailscale.package;
  services = vmTailscale.services or { };
  serveCommands = lib.mapAttrsToList (
    serviceName: service:
    let
      parts = lib.splitString ":" service.serve;
      protocol = builtins.elemAt parts 0;
      port = builtins.elemAt parts 1;
    in
    assert lib.assertMsg
      (builtins.length parts == 2)
      "tailscale service ${serviceName}.serve must be formatted as `<protocol>:<port>`";
    assert lib.assertMsg
      (builtins.elem protocol [
        "http"
        "https"
      ])
      "tailscale service ${serviceName}.serve must use `http` or `https`; got `${protocol}`";
    ''
      # FIXME: Use services.tailscale.serve again once
      # https://github.com/tailscale/tailscale/issues/18381 is fixed.
      # `tailscale serve set-config` currently restores exported HTTPS
      # service endpoints as HTTP on the same port, so drive the CLI form.
      ${tailscale} serve clear ${lib.escapeShellArg "svc:${serviceName}"} 2>/dev/null || true
      ${tailscale} serve --service=${lib.escapeShellArg "svc:${serviceName}"} --${protocol}=${lib.escapeShellArg port} ${lib.escapeShellArg service.target}
    ''
  ) services;
in
{
  services.tailscale = {
    enable = true;
    authKeyFile = "/var/keys/tailscale-auth-key";
    extraUpFlags = [ "--hostname=vm-${config.networking.hostName}" ];
    openFirewall = true;
  };

  systemd.services.tailscale-serve = lib.mkIf (serveCommands != [ ]) {
    description = "Tailscale Serve Configuration";
    after = [
      "tailscaled.service"
      "tailscaled-autoconnect.service"
      "tailscaled-set.service"
    ];
    wants = [ "tailscaled.service" ];
    wantedBy = [ "multi-user.target" ];
    serviceConfig = {
      Type = "oneshot";
      RemainAfterExit = true;
    };
    script = lib.concatStringsSep "\n" serveCommands;
  };
}
