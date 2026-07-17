{
  config,
  lib,
  vmTailscale,
  ...
}:
let
  advertiseTagFlags = lib.optional (
    vmTailscale.tags or [ ] != [ ]
  ) "--advertise-tags=${lib.concatStringsSep "," vmTailscale.tags}";
in
{
  services.tailscale = {
    enable = true;
    authKeyFile = "/var/keys/tailscale-auth-key";
    extraUpFlags = [ "--hostname=${config.networking.hostName}" ] ++ advertiseTagFlags;
    extraSetFlags = [ "--hostname=${config.networking.hostName}" ];
    openFirewall = true;
  };

  # Tailscale CLI only accepts --advertise-tags on `tailscale up`,
  # and the tailscale module only runs `tailscale up` when the node is not authenticated.
  # We reconcile tags separately for existing nodes.
  systemd.services.tailscale-advertise-tags = lib.mkIf (advertiseTagFlags != [ ]) {
    description = "Reconcile Tailscale advertised tags";
    after = [
      "tailscaled-autoconnect.service"
      "tailscaled-set.service"
    ];
    wants = [
      "tailscaled-autoconnect.service"
      "tailscaled-set.service"
    ];
    wantedBy = [ "multi-user.target" ];
    serviceConfig = {
      Type = "oneshot";
      RemainAfterExit = true;
    };
    script = ''
      ${lib.getExe config.services.tailscale.package} up ${
        lib.escapeShellArgs ([ "--hostname=${config.networking.hostName}" ] ++ advertiseTagFlags)
      }
    '';
  };
}
