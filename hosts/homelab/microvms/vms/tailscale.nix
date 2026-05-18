{
  config,
  lib,
  vmTailscale,
  ...
}:
let
  serveServices = lib.mapAttrs (_: service: {
    advertised = true;
    endpoints.${service.serve} = service.target;
  }) (vmTailscale.services or { });
in
{
  services.tailscale = {
    enable = true;
    authKeyFile = "/var/keys/tailscale-auth-key";
    extraUpFlags = [ "--hostname=vm-${config.networking.hostName}" ];
    openFirewall = true;

    serve = lib.mkIf (serveServices != { }) {
      enable = true;
      services = serveServices;
    };
  };
}
